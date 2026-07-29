import type { AppConfig } from "../config.ts";
import { envelope, errorEnvelope, jsonResponse, readJson } from "../http.ts";
import {
  authenticateRequest,
  organizationIdFromClaims,
  requirePermission,
  requireSchoolOperationalScope,
  schoolIdFromClaims,
} from "../permission_middleware.ts";
import { TenantDbNotConfiguredError, withTenantContext } from "../tenant_db.ts";
import { tenantDbNotConfiguredResponse } from "../tenant_handlers.ts";
import { emitMutationAudit, financeAudit } from "../audit/mutation_audit_catalog.ts";
import { recordMutationAudit } from "../audit/audit_repository.ts";
import {
  CancellationReasonRequiredError,
  CollectionAmountError,
  CollectionConflictError,
  CollectionNotFoundError,
  DayLockedError,
  DuplicateReceiptError,
  InvoiceNotCollectibleError,
  InvalidCollectionTransitionError,
  ReceiptNotFoundError,
  cancelCollection,
  createCollection,
  getCollection,
  getDailySummary,
  getReceipt,
  getReceiptSmsRecipient,
  getStudentAccountById,
  listAllCollectionsForAccount,
  listCancelledCollections,
  listCollections,
  listReceiptsForAccount,
} from "./finance_collections_repository.ts";
import { getInvoice } from "./finance_invoices_repository.ts";
import { isSmsConfigured, sendTransactionalSms, type SmsConfig } from "../sms_provider.ts";
import { enforceSmsQuota } from "../entitlements/entitlement_limits.ts";
import {
  cancelledCollectionToApi,
  collectionCreateToApi,
  collectionDetailToApi,
  collectionPaymentToApi,
  collectionRowToApi,
  dailySummaryToApi,
  listEnvelope,
  receiptToApi,
} from "./finance_mapper.ts";

function parsePagination(url: URL): { page: number; pageSize: number } {
  const page = Math.max(1, parseInt(url.searchParams.get("page") ?? "1", 10) || 1);
  const pageSize = Math.min(
    100,
    Math.max(1, parseInt(url.searchParams.get("pageSize") ?? "20", 10) || 20),
  );
  return { page, pageSize };
}

async function runTenant<T>(
  config: AppConfig,
  claims: Parameters<typeof withTenantContext>[1],
  operation: Parameters<typeof withTenantContext<T>>[2],
): Promise<T> {
  return await withTenantContext(config, claims, operation);
}

function requireFinanceRead(claims: Parameters<typeof requirePermission>[0]): Response | null {
  return requirePermission(claims, "viewFinance") ??
    requireSchoolOperationalScope(claims);
}

/**
 * Best-effort transactional SMS to the student's guardian after a fee payment.
 * Gated by `transactionalSmsEnabled` + a configured SMS provider; any failure is
 * logged and swallowed so it can never affect the collection response.
 */
async function notifyParentOfReceipt(
  config: AppConfig,
  claims: Parameters<typeof withTenantContext>[1],
  invoiceId: string,
  amount: number,
): Promise<void> {
  if (!config.transactionalSmsEnabled) return;
  const smsConfig: SmsConfig = {
    provider: config.smsProvider,
    apiKey: config.smsApiKey,
    fast2smsRoute: config.smsFast2smsRoute,
    fast2smsSenderId: config.smsFast2smsSenderId,
    fast2smsMessageId: config.smsFast2smsMessageId,
  };
  if (!isSmsConfigured(smsConfig)) return;
  // W4 (owner decision #1): per-plan monthly SMS quota — pre-send check. Deploy-
  // dark behind ENTITLEMENT_ENFORCEMENT and fail-open (returns null unless the
  // org is genuinely at its plan cap), so this is a no-op today. When on and the
  // month's SMS is used up, the discretionary receipt SMS is skipped rather than
  // pushing the org past its plan's SMS budget; the collection response itself is
  // never affected (this hook is best-effort).
  if (await enforceSmsQuota(config, claims)) return;
  try {
    const target = await runTenant(config, claims, (db) =>
      getReceiptSmsRecipient(db, invoiceId)
    );
    if (!target?.phone) return;
    const msg =
      `NIKSHA: Payment of Rs ${amount} received for ${target.name}. Receipt available in the app.`;
    const result = await sendTransactionalSms(smsConfig, target.phone, msg);
    if (!result.ok) {
      console.error(`receipt SMS not sent (${result.code}): ${result.detail}`);
    }
  } catch (error) {
    console.error("receipt SMS error:", error instanceof Error ? error.message : error);
  }
}

function requireFinanceWrite(claims: Parameters<typeof requirePermission>[0]): Response | null {
  return requirePermission(claims, "manageFinance") ??
    requireSchoolOperationalScope(claims);
}

function optionalStr(
  body: Record<string, unknown>,
  snakeKey: string,
  camelKey: string,
): string | undefined {
  if (snakeKey in body && body[snakeKey] != null) return String(body[snakeKey]);
  if (camelKey in body && body[camelKey] != null) return String(body[camelKey]);
  return undefined;
}

function parseAmount(body: Record<string, unknown>): number | null {
  const raw = body.amountCollected ?? body.amount_collected ?? body.amount;
  if (raw == null) return null;
  const num = parseFloat(String(raw));
  return Number.isFinite(num) ? num : null;
}

/** ENG-1: reads the optional optimistic-lock version from a request body. */
function parseExpectedVersion(body: Record<string, unknown>): number | null {
  const raw = body.expectedVersion ?? body.expected_version ??
    body.rowVersion ?? body.row_version;
  if (raw == null) return null;
  const n = Number(raw);
  return Number.isFinite(n) ? n : null;
}

function mapCollectionError(error: unknown): Response | null {
  if (error instanceof CollectionNotFoundError || error instanceof ReceiptNotFoundError) {
    return errorEnvelope("NOT_FOUND", error.message, 404);
  }
  if (error instanceof InvoiceNotCollectibleError || error instanceof CollectionAmountError) {
    return errorEnvelope("VALIDATION_ERROR", error.message, 422);
  }
  if (error instanceof InvalidCollectionTransitionError) {
    return errorEnvelope("VALIDATION_ERROR", error.message, 422);
  }
  // FIN-D1: back-dated entry into a closed day. FIN-D3: missing cancel reason.
  if (
    error instanceof DayLockedError ||
    error instanceof CancellationReasonRequiredError
  ) {
    return errorEnvelope("VALIDATION_ERROR", error.message, 422);
  }
  if (error instanceof DuplicateReceiptError) {
    return errorEnvelope("CONFLICT", error.message, 409);
  }
  if (error instanceof CollectionConflictError) {
    // ENG-1: 409 CONFLICT carrying the current server row (incl. rowVersion) in
    // `data` so the Data Reliability Platform can resolve and re-submit.
    return jsonResponse(
      {
        data: collectionRowToApi(error.currentRow),
        error: { code: "CONFLICT", message: error.message },
      },
      { status: 409 },
    );
  }
  return null;
}

export async function handleListCollections(
  req: Request,
  config: AppConfig,
): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;

  const denied = requireFinanceRead(auth.claims);
  if (denied) return denied;

  const orgId = organizationIdFromClaims(auth.claims);
  const schoolId = schoolIdFromClaims(auth.claims);
  const { page, pageSize } = parsePagination(new URL(req.url));

  try {
    const result = await runTenant(config, auth.claims, async (db) =>
      await listCollections(db, orgId, schoolId, { page, pageSize })
    );
    return jsonResponse(
      envelope(listEnvelope(result.items.map(collectionPaymentToApi), result)),
    );
  } catch (error) {
    if (error instanceof TenantDbNotConfiguredError) {
      return tenantDbNotConfiguredResponse();
    }
    throw error;
  }
}

export async function handleGetCollection(
  req: Request,
  config: AppConfig,
  collectionId: string,
): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;

  const denied = requireFinanceRead(auth.claims);
  if (denied) return denied;

  const orgId = organizationIdFromClaims(auth.claims);
  const schoolId = schoolIdFromClaims(auth.claims);

  try {
    const detail = await runTenant(config, auth.claims, async (db) => {
      const collection = await getCollection(db, orgId, schoolId, collectionId);
      if (!collection) return null;
      const invoice = await getInvoice(db, orgId, schoolId, collection.invoice_id);
      if (!invoice) return null;
      const account = await getStudentAccountById(
        db,
        orgId,
        schoolId,
        collection.student_account_id,
      );
      if (!account) return null;
      const accountCollections = await listAllCollectionsForAccount(
        db,
        orgId,
        schoolId,
        collection.student_account_id,
      );
      const accountReceipts = await listReceiptsForAccount(
        db,
        orgId,
        schoolId,
        collection.student_account_id,
      );
      return collectionDetailToApi(
        collection,
        invoice,
        account,
        accountCollections,
        accountReceipts,
      );
    });
    if (!detail) {
      return errorEnvelope("NOT_FOUND", `Collection not found: ${collectionId}`, 404);
    }
    return jsonResponse(envelope(detail));
  } catch (error) {
    if (error instanceof TenantDbNotConfiguredError) {
      return tenantDbNotConfiguredResponse();
    }
    throw error;
  }
}

export async function handleCreateCollection(
  req: Request,
  config: AppConfig,
): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;

  const denied = requireFinanceWrite(auth.claims);
  if (denied) return denied;

  const body = await readJson<Record<string, unknown>>(req);
  if (!body) {
    return errorEnvelope("VALIDATION_ERROR", "Request body is required", 422);
  }
  const invoiceId = optionalStr(body, "invoice_id", "invoiceId");
  const amount = parseAmount(body);
  const paymentMethod = optionalStr(body, "payment_method", "paymentMethod") ??
    optionalStr(body, "mode", "mode");

  if (!invoiceId) {
    return errorEnvelope("VALIDATION_ERROR", "invoiceId is required", 422);
  }
  if (amount == null || amount <= 0) {
    return errorEnvelope("VALIDATION_ERROR", "amountCollected must be greater than zero", 422);
  }
  if (!paymentMethod) {
    return errorEnvelope("VALIDATION_ERROR", "paymentMethod is required", 422);
  }

  const orgId = organizationIdFromClaims(auth.claims);
  const schoolId = schoolIdFromClaims(auth.claims);

  try {
    const result = await runTenant(config, auth.claims, async (db) => {
      const created = await createCollection(db, orgId, schoolId, {
        invoiceId,
        amountCollected: amount,
        paymentMethod,
        referenceNumber: optionalStr(body, "reference_number", "referenceNumber"),
        notes: optionalStr(body, "notes", "notes"),
        collectionDate: optionalStr(body, "collection_date", "collectionDate"),
        collectedBy: auth.claims.sub,
        // RT-01: honour the Idempotency-Key header (already CORS-advertised) so a
        // double-submitted payment replays the original collection.
        idempotencyKey: req.headers.get("Idempotency-Key") ??
          req.headers.get("idempotency-key") ?? undefined,
      });
      await recordMutationAudit(
        db,
        auth.claims,
        {
          eventType: "collectionCreated",
          category: "workflow",
          entityType: "finance_collection",
          entityId: created.collection.id,
          metadata: { invoiceId, amount, paymentMethod },
        },
        {
          eventType: "finance.collection.created",
          payload: { collectionId: created.collection.id, invoiceId, amount },
          sourceModule: "finance",
          idempotencyKey: `finance.collection:${created.collection.id}`,
        },
        req,
      );
      return created;
    });
    await notifyParentOfReceipt(config, auth.claims, invoiceId, amount);
    return jsonResponse(envelope(collectionCreateToApi(result)), { status: 201 });
  } catch (error) {
    if (error instanceof TenantDbNotConfiguredError) {
      return tenantDbNotConfiguredResponse();
    }
    const mapped = mapCollectionError(error);
    if (mapped) return mapped;
    throw error;
  }
}

export async function handleDailySummary(
  req: Request,
  config: AppConfig,
): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;

  const denied = requireFinanceRead(auth.claims);
  if (denied) return denied;

  const orgId = organizationIdFromClaims(auth.claims);
  const schoolId = schoolIdFromClaims(auth.claims);

  try {
    const summary = await runTenant(config, auth.claims, async (db) =>
      await getDailySummary(db, orgId, schoolId)
    );
    return jsonResponse(envelope(dailySummaryToApi(summary)));
  } catch (error) {
    if (error instanceof TenantDbNotConfiguredError) {
      return tenantDbNotConfiguredResponse();
    }
    throw error;
  }
}

export async function handleCancelCollection(
  req: Request,
  config: AppConfig,
  collectionId: string,
): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;

  const denied = requireFinanceWrite(auth.claims);
  if (denied) return denied;

  // FIN-D3: a cancellation reason is mandatory. Validated (422) before the DB.
  const body = await readJson<Record<string, unknown>>(req) ?? {};
  const reason = optionalStr(body, "reason", "reason")?.trim() ?? "";
  if (reason === "") {
    return errorEnvelope("VALIDATION_ERROR", "A cancellation reason is required", 422);
  }
  // ENG-1: optional optimistic-lock version (camelCase or snake_case).
  const expectedVersion = parseExpectedVersion(body);

  const orgId = organizationIdFromClaims(auth.claims);
  const schoolId = schoolIdFromClaims(auth.claims);

  try {
    const result = await runTenant(config, auth.claims, async (db) => {
      const cancelled = await cancelCollection(db, orgId, schoolId, collectionId, {
        reason,
        cancelledBy: auth.claims.sub,
        expectedVersion,
      });
      await emitMutationAudit(
        db,
        auth.claims,
        financeAudit.collectionCancelled(collectionId, reason),
        req,
      );
      return cancelled;
    });
    return jsonResponse(envelope(collectionCreateToApi(result)));
  } catch (error) {
    if (error instanceof TenantDbNotConfiguredError) {
      return tenantDbNotConfiguredResponse();
    }
    const mapped = mapCollectionError(error);
    if (mapped) return mapped;
    throw error;
  }
}

// FIN-D3 — GET /finance/collections/cancelled (cancelled register).
export async function handleListCancelledCollections(
  req: Request,
  config: AppConfig,
): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;

  const denied = requireFinanceRead(auth.claims);
  if (denied) return denied;

  const orgId = organizationIdFromClaims(auth.claims);
  const schoolId = schoolIdFromClaims(auth.claims);

  try {
    const rows = await runTenant(config, auth.claims, async (db) =>
      await listCancelledCollections(db, orgId, schoolId)
    );
    return jsonResponse(envelope({ items: rows.map(cancelledCollectionToApi) }));
  } catch (error) {
    if (error instanceof TenantDbNotConfiguredError) {
      return tenantDbNotConfiguredResponse();
    }
    throw error;
  }
}

export async function handleGetReceipt(
  req: Request,
  config: AppConfig,
  receiptId: string,
): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;

  const denied = requireFinanceRead(auth.claims);
  if (denied) return denied;

  const orgId = organizationIdFromClaims(auth.claims);
  const schoolId = schoolIdFromClaims(auth.claims);

  try {
    const result = await runTenant(config, auth.claims, async (db) =>
      await getReceipt(db, orgId, schoolId, receiptId)
    );
    if (!result) {
      return errorEnvelope("NOT_FOUND", `Receipt not found: ${receiptId}`, 404);
    }
    return jsonResponse(envelope({
      receipt: receiptToApi(result.receipt),
      collectionId: result.collection.id,
      invoiceId: result.collection.invoice_id,
      studentAccountId: result.collection.student_account_id,
    }));
  } catch (error) {
    if (error instanceof TenantDbNotConfiguredError) {
      return tenantDbNotConfiguredResponse();
    }
    throw error;
  }
}
