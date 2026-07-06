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
import { listEnvelope } from "./finance_mapper.ts";
import {
  bounceOfflinePayment,
  createOfflinePayment,
  isOfflinePaymentMethod,
  listOfflinePayments,
  type OfflinePaymentMethod,
  OfflinePaymentBouncedError,
  offlinePaymentToApi,
  OfflinePaymentNotFoundError,
  OfflinePaymentReconciledError,
  reconcileOfflinePayment,
} from "./finance_offline_payments_repository.ts";

function requireFinanceWrite(claims: Parameters<typeof requirePermission>[0]): Response | null {
  return requirePermission(claims, "manageFinance") ??
    requireSchoolOperationalScope(claims);
}

function requireFinanceRead(claims: Parameters<typeof requirePermission>[0]): Response | null {
  return requirePermission(claims, "viewFinance") ??
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

function parseAmount(value: unknown): number {
  if (typeof value === "number") return value;
  if (typeof value === "string") {
    const cleaned = value.replace(/[₹,\s]/g, "");
    const num = parseFloat(cleaned);
    return Number.isFinite(num) ? num : NaN;
  }
  return NaN;
}

function parsePagination(url: URL): { page: number; pageSize: number } {
  const page = Math.max(1, parseInt(url.searchParams.get("page") ?? "1", 10) || 1);
  const pageSize = Math.min(
    100,
    Math.max(1, parseInt(url.searchParams.get("pageSize") ?? "20", 10) || 20),
  );
  return { page, pageSize };
}

export async function handleRecordOfflinePayment(
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

  const studentName = optionalStr(body, "student_name", "studentName") ?? "";
  const rawMethod = optionalStr(body, "payment_method", "paymentMethod") ?? "cash";
  const referenceNumber = optionalStr(body, "reference_number", "referenceNumber") ?? "";
  const instrumentDate = optionalStr(body, "instrument_date", "instrumentDate");
  const bankName = optionalStr(body, "bank_name", "bankName");
  const recordedAt = optionalStr(body, "recorded_at", "recordedAt");
  const invoiceId = optionalStr(body, "invoice_id", "invoiceId");
  const amount = parseAmount(body.amount);

  if (!Number.isFinite(amount) || amount <= 0) {
    return errorEnvelope("VALIDATION_ERROR", "amount must be a positive number", 422);
  }
  if (!isOfflinePaymentMethod(rawMethod)) {
    return errorEnvelope("VALIDATION_ERROR", `Invalid payment_method: ${rawMethod}`, 422);
  }

  const orgId = organizationIdFromClaims(auth.claims);
  const schoolId = schoolIdFromClaims(auth.claims);

  try {
    const created = await withTenantContext(config, auth.claims, async (db) => {
      const row = await createOfflinePayment(db, orgId, schoolId, {
        invoiceId,
        studentName,
        amount,
        method: rawMethod as OfflinePaymentMethod,
        referenceNumber,
        instrumentDate,
        bankName,
        recordedAt,
        recordedBy: auth.claims.sub,
      });
      await emitMutationAudit(
        db,
        auth.claims,
        financeAudit.offlinePaymentRecorded(row.id),
        req,
      );
      return row;
    });
    return jsonResponse(envelope(offlinePaymentToApi(created)), { status: 201 });
  } catch (error) {
    if (error instanceof TenantDbNotConfiguredError) {
      return tenantDbNotConfiguredResponse();
    }
    throw error;
  }
}

export async function handleListOfflinePayments(
  req: Request,
  config: AppConfig,
): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;

  const denied = requireFinanceRead(auth.claims);
  if (denied) return denied;

  const url = new URL(req.url);
  const pagination = parsePagination(url);
  const orgId = organizationIdFromClaims(auth.claims);
  const schoolId = schoolIdFromClaims(auth.claims);

  try {
    const result = await withTenantContext(config, auth.claims, (db) =>
      listOfflinePayments(db, orgId, schoolId, pagination));
    return jsonResponse(
      envelope(
        listEnvelope(result.items.map(offlinePaymentToApi), {
          page: result.page,
          pageSize: result.pageSize,
          total: result.total,
          hasMore: result.hasMore,
        }),
      ),
    );
  } catch (error) {
    if (error instanceof TenantDbNotConfiguredError) {
      return tenantDbNotConfiguredResponse();
    }
    throw error;
  }
}

export async function handleReconcileOfflinePayment(
  req: Request,
  config: AppConfig,
  offlinePaymentId: string,
): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;

  const denied = requireFinanceWrite(auth.claims);
  if (denied) return denied;

  const body = (await readJson<Record<string, unknown>>(req)) ?? {};
  const reconciledAt = optionalStr(body, "reconciled_at", "reconciledAt");
  const notes = optionalStr(body, "notes", "notes");

  const orgId = organizationIdFromClaims(auth.claims);
  const schoolId = schoolIdFromClaims(auth.claims);

  try {
    const updated = await withTenantContext(config, auth.claims, async (db) => {
      const row = await reconcileOfflinePayment(db, orgId, schoolId, offlinePaymentId, {
        reconciledAt,
        notes,
        reconciledBy: auth.claims.sub,
      });
      await emitMutationAudit(
        db,
        auth.claims,
        financeAudit.offlinePaymentReconciled(row.id),
        req,
      );
      return row;
    });
    return jsonResponse(envelope(offlinePaymentToApi(updated)));
  } catch (error) {
    if (error instanceof TenantDbNotConfiguredError) {
      return tenantDbNotConfiguredResponse();
    }
    if (error instanceof OfflinePaymentNotFoundError) {
      return errorEnvelope("NOT_FOUND", error.message, 404);
    }
    if (error instanceof OfflinePaymentBouncedError) {
      return errorEnvelope("CONFLICT", error.message, 409);
    }
    throw error;
  }
}

/**
 * FIN-R7: mark a pending instrument (cheque / DD / PDC) as bounced/dishonoured.
 * Tracking-only — posts/reverses no money (Finance = sole payment engine).
 */
export async function handleBounceOfflinePayment(
  req: Request,
  config: AppConfig,
  offlinePaymentId: string,
): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;

  const denied = requireFinanceWrite(auth.claims);
  if (denied) return denied;

  const body = (await readJson<Record<string, unknown>>(req)) ?? {};
  const bouncedAt = optionalStr(body, "bounced_at", "bouncedAt");
  const reason = optionalStr(body, "reason", "reason");

  const orgId = organizationIdFromClaims(auth.claims);
  const schoolId = schoolIdFromClaims(auth.claims);

  try {
    const updated = await withTenantContext(config, auth.claims, async (db) => {
      const row = await bounceOfflinePayment(db, orgId, schoolId, offlinePaymentId, {
        bouncedAt,
        reason,
        bouncedBy: auth.claims.sub,
      });
      await emitMutationAudit(
        db,
        auth.claims,
        financeAudit.offlinePaymentBounced(row.id),
        req,
      );
      return row;
    });
    return jsonResponse(envelope(offlinePaymentToApi(updated)));
  } catch (error) {
    if (error instanceof TenantDbNotConfiguredError) {
      return tenantDbNotConfiguredResponse();
    }
    if (error instanceof OfflinePaymentNotFoundError) {
      return errorEnvelope("NOT_FOUND", error.message, 404);
    }
    if (error instanceof OfflinePaymentReconciledError) {
      return errorEnvelope("CONFLICT", error.message, 409);
    }
    throw error;
  }
}
