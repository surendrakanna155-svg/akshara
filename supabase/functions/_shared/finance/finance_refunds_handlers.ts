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
  InvalidRefundTransitionError,
  RefundAmountError,
  RefundNotCollectibleError,
  RefundNotFoundError,
  approveRefund,
  createRefund,
  getRefund,
  listRefunds,
  rejectRefund,
} from "./finance_refunds_repository.ts";
import { listEnvelope, refundRequestToApi } from "./finance_mapper.ts";

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

function requireRefundApproval(claims: Parameters<typeof requirePermission>[0]): Response | null {
  return requirePermission(claims, "approveRefunds") ??
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

function parseRefundAmount(body: Record<string, unknown>): number | null {
  const raw = body.refundAmount ?? body.refund_amount ?? body.amount;
  if (raw == null) return null;
  const num = parseFloat(String(raw));
  return Number.isFinite(num) ? num : null;
}

function mapRefundError(error: unknown): Response | null {
  if (error instanceof RefundNotFoundError) {
    return errorEnvelope("NOT_FOUND", error.message, 404);
  }
  if (
    error instanceof RefundAmountError ||
    error instanceof RefundNotCollectibleError ||
    error instanceof InvalidRefundTransitionError
  ) {
    return errorEnvelope("VALIDATION_ERROR", error.message, 422);
  }
  return null;
}

export async function handleListRefunds(
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
      await listRefunds(db, orgId, schoolId, { page, pageSize })
    );
    return jsonResponse(
      envelope(listEnvelope(result.items.map(refundRequestToApi), result)),
    );
  } catch (error) {
    if (error instanceof TenantDbNotConfiguredError) {
      return tenantDbNotConfiguredResponse();
    }
    throw error;
  }
}

export async function handleGetRefund(
  req: Request,
  config: AppConfig,
  refundId: string,
): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;

  const denied = requireFinanceRead(auth.claims);
  if (denied) return denied;

  const orgId = organizationIdFromClaims(auth.claims);
  const schoolId = schoolIdFromClaims(auth.claims);

  try {
    const refund = await runTenant(config, auth.claims, async (db) =>
      await getRefund(db, orgId, schoolId, refundId)
    );
    if (!refund) {
      return errorEnvelope("NOT_FOUND", `Refund not found: ${refundId}`, 404);
    }
    return jsonResponse(envelope(refundRequestToApi(refund)));
  } catch (error) {
    if (error instanceof TenantDbNotConfiguredError) {
      return tenantDbNotConfiguredResponse();
    }
    throw error;
  }
}

export async function handleCreateRefund(
  req: Request,
  config: AppConfig,
): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;

  const denied = requireFinanceWrite(auth.claims);
  if (denied) return denied;

  const body = await readJson(req);
  const amount = parseRefundAmount(body);
  const reason = optionalStr(body, "refund_reason", "reason") ??
    optionalStr(body, "refundReason", "refundReason");

  if (amount == null || amount <= 0) {
    return errorEnvelope("VALIDATION_ERROR", "Refund amount must be greater than zero", 422);
  }
  if (!reason?.trim()) {
    return errorEnvelope("VALIDATION_ERROR", "Refund reason is required", 422);
  }

  const orgId = organizationIdFromClaims(auth.claims);
  const schoolId = schoolIdFromClaims(auth.claims);

  try {
    const refund = await runTenant(config, auth.claims, async (db) => {
      const created = await createRefund(db, orgId, schoolId, {
        collectionId: optionalStr(body, "collection_id", "collectionId"),
        studentAccountId: optionalStr(body, "student_account_id", "feeAccountId") ??
          optionalStr(body, "fee_account_id", "feeAccountId"),
        originalReceipt: optionalStr(body, "original_receipt", "originalReceipt"),
        refundAmount: amount,
        refundReason: reason,
        requestedBy: auth.claims.sub,
      });
      const { recordMutationAudit } = await import("../audit/audit_repository.ts");
      await recordMutationAudit(
        db,
        auth.claims,
        {
          eventType: "refundRequested",
          category: "workflow",
          entityType: "finance_refund",
          entityId: created.id,
          metadata: { refundAmount: amount, reason },
        },
        {
          eventType: "finance.refund.requested",
          payload: { refundId: created.id, amount },
          sourceModule: "finance",
          idempotencyKey: `finance.refund:${created.id}`,
        },
        req,
      );
      return created;
    });
    return jsonResponse(envelope(refundRequestToApi(refund)), { status: 201 });
  } catch (error) {
    if (error instanceof TenantDbNotConfiguredError) {
      return tenantDbNotConfiguredResponse();
    }
    const mapped = mapRefundError(error);
    if (mapped) return mapped;
    throw error;
  }
}

export async function handleApproveRefund(
  req: Request,
  config: AppConfig,
  refundId: string,
): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;

  const denied = requireRefundApproval(auth.claims);
  if (denied) return denied;

  const orgId = organizationIdFromClaims(auth.claims);
  const schoolId = schoolIdFromClaims(auth.claims);

  try {
    const refund = await runTenant(config, auth.claims, async (db) => {
      const approved = await approveRefund(db, orgId, schoolId, refundId, auth.claims.sub);
      await emitMutationAudit(db, auth.claims, financeAudit.refundApproved(refundId), req);
      return approved;
    });
    return jsonResponse(envelope(refundRequestToApi(refund)));
  } catch (error) {
    if (error instanceof TenantDbNotConfiguredError) {
      return tenantDbNotConfiguredResponse();
    }
    const mapped = mapRefundError(error);
    if (mapped) return mapped;
    throw error;
  }
}

export async function handleRejectRefund(
  req: Request,
  config: AppConfig,
  refundId: string,
): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;

  const denied = requireRefundApproval(auth.claims);
  if (denied) return denied;

  const orgId = organizationIdFromClaims(auth.claims);
  const schoolId = schoolIdFromClaims(auth.claims);

  try {
    const refund = await runTenant(config, auth.claims, async (db) => {
      const rejected = await rejectRefund(db, orgId, schoolId, refundId);
      await emitMutationAudit(db, auth.claims, financeAudit.refundRejected(refundId), req);
      return rejected;
    });
    return jsonResponse(envelope(refundRequestToApi(refund)));
  } catch (error) {
    if (error instanceof TenantDbNotConfiguredError) {
      return tenantDbNotConfiguredResponse();
    }
    const mapped = mapRefundError(error);
    if (mapped) return mapped;
    throw error;
  }
}
