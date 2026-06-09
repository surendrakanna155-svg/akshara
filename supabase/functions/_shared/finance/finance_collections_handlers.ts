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
import {
  CollectionAmountError,
  CollectionNotFoundError,
  DuplicateReceiptError,
  InvoiceNotCollectibleError,
  InvalidCollectionTransitionError,
  ReceiptNotFoundError,
  cancelCollection,
  createCollection,
  getCollection,
  getReceipt,
  listCollections,
  listCollectionsForAccount,
  listReceiptsForAccount,
} from "./finance_collections_repository.ts";
import { getInvoice } from "./finance_invoices_repository.ts";
import {
  collectionCreateToApi,
  collectionDetailToApi,
  collectionPaymentToApi,
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
  if (error instanceof DuplicateReceiptError) {
    return errorEnvelope("CONFLICT", error.message, 409);
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
      const accountCollections = await listCollectionsForAccount(
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
      return collectionDetailToApi(collection, invoice, accountCollections, accountReceipts);
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

  const body = await readJson(req);
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
    const result = await runTenant(config, auth.claims, async (db) =>
      await createCollection(db, orgId, schoolId, {
        invoiceId,
        amountCollected: amount,
        paymentMethod,
        referenceNumber: optionalStr(body, "reference_number", "referenceNumber"),
        notes: optionalStr(body, "notes", "notes"),
        collectionDate: optionalStr(body, "collection_date", "collectionDate"),
        collectedBy: auth.claims.sub,
      })
    );
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

export async function handleCancelCollection(
  req: Request,
  config: AppConfig,
  collectionId: string,
): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;

  const denied = requireFinanceWrite(auth.claims);
  if (denied) return denied;

  const orgId = organizationIdFromClaims(auth.claims);
  const schoolId = schoolIdFromClaims(auth.claims);

  try {
    const result = await runTenant(config, auth.claims, async (db) =>
      await cancelCollection(db, orgId, schoolId, collectionId)
    );
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
