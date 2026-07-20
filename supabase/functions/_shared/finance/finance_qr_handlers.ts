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
import {
  confirmQrSession,
  createQrSession,
  getQrSession,
  qrSessionToApi,
  QrSessionNotConfirmableError,
  QrSessionNotFoundError,
} from "./finance_qr_repository.ts";

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

/** Build a standards-compliant UPI deep-link payload (BHIM/GPay/PhonePe). */
function buildUpiPayload(
  payeeVpa: string,
  payeeName: string,
  amount: number,
  note: string,
): string {
  const params = new URLSearchParams({
    pa: payeeVpa,
    pn: payeeName,
    am: amount.toFixed(2),
    cu: "INR",
    tn: note,
  });
  return `upi://pay?${params.toString()}`;
}

export async function handleCreateQrPaymentSession(
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
  const amount = parseAmount(body.amount);
  if (!Number.isFinite(amount) || amount <= 0) {
    return errorEnvelope("VALIDATION_ERROR", "amount must be a positive number", 422);
  }

  const orgId = organizationIdFromClaims(auth.claims);
  const schoolId = schoolIdFromClaims(auth.claims);

  // Deterministic, payment-provider-agnostic UPI intent. The payee VPA is
  // derived per school; a real PSP integration can replace this payload without
  // changing the route contract.
  const payeeVpa = `school.${schoolId.slice(0, 8)}@akshara`;
  const note = invoiceId ? `Fee ${invoiceId.slice(0, 8)}` : "School fee";
  const upiPayload = buildUpiPayload(payeeVpa, "Akshara School", amount, note);

  try {
    const created = await withTenantContext(config, auth.claims, async (db) => {
      const row = await createQrSession(db, orgId, schoolId, {
        invoiceId,
        amount,
        upiPayload,
        createdBy: auth.claims.sub,
      });
      await emitMutationAudit(
        db,
        auth.claims,
        financeAudit.qrSessionCreated(row.id),
        req,
      );
      return row;
    });
    return jsonResponse(envelope(qrSessionToApi(created)), { status: 201 });
  } catch (error) {
    if (error instanceof TenantDbNotConfiguredError) {
      return tenantDbNotConfiguredResponse();
    }
    throw error;
  }
}

export async function handleGetQrPaymentSession(
  req: Request,
  config: AppConfig,
  sessionId: string,
): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;

  const denied = requireFinanceRead(auth.claims);
  if (denied) return denied;

  const orgId = organizationIdFromClaims(auth.claims);
  const schoolId = schoolIdFromClaims(auth.claims);

  try {
    const row = await withTenantContext(config, auth.claims, (db) =>
      getQrSession(db, orgId, schoolId, sessionId));
    if (!row) {
      return errorEnvelope("NOT_FOUND", `QR payment session not found: ${sessionId}`, 404);
    }
    return jsonResponse(envelope(qrSessionToApi(row)));
  } catch (error) {
    if (error instanceof TenantDbNotConfiguredError) {
      return tenantDbNotConfiguredResponse();
    }
    throw error;
  }
}

export async function handleConfirmQrPaymentSession(
  req: Request,
  config: AppConfig,
  sessionId: string,
): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;

  const denied = requireFinanceWrite(auth.claims);
  if (denied) return denied;

  const body = (await readJson<Record<string, unknown>>(req)) ?? {};
  const receiptNumber = optionalStr(body, "receipt_number", "receiptNumber");

  const orgId = organizationIdFromClaims(auth.claims);
  const schoolId = schoolIdFromClaims(auth.claims);

  try {
    const updated = await withTenantContext(config, auth.claims, async (db) => {
      const row = await confirmQrSession(db, orgId, schoolId, sessionId, receiptNumber);
      await emitMutationAudit(
        db,
        auth.claims,
        financeAudit.qrSessionConfirmed(row.id),
        req,
      );
      return row;
    });
    return jsonResponse(envelope(qrSessionToApi(updated)));
  } catch (error) {
    if (error instanceof TenantDbNotConfiguredError) {
      return tenantDbNotConfiguredResponse();
    }
    if (error instanceof QrSessionNotFoundError) {
      return errorEnvelope("NOT_FOUND", error.message, 404);
    }
    // P5 (red-team Round 2): a concurrent/repeat confirm that lost the status-guard
    // race → 409 CONFLICT, never a second success the client could double-act on.
    if (error instanceof QrSessionNotConfirmableError) {
      return errorEnvelope("CONFLICT", error.message, 409);
    }
    throw error;
  }
}
