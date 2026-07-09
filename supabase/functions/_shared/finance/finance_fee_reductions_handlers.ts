// STEP-5 — HTTP handlers for the fee-reduction maker-checker (scholarships +
// discounts that actually reduce a student's payable).
//
// SoD + identity discipline (mirrors finance_refunds_handlers):
//   * propose (MAKER)   → manageFinance; created_by = claims.sub (server-set).
//   * approve/reject/reverse (CHECKER) → approveFeeConcession (the SAME approval
//     permission the Approval Center uses for the sibling fee-concession type);
//     approver = claims.sub. The proposer can never approve their own reduction
//     — enforced inside approveFeeReduction, before any money moves.

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
import { emitMutationAudit, moduleEntityAudit } from "../audit/mutation_audit_catalog.ts";
import {
  approveFeeReduction,
  type FeeReductionKind,
  FeeReductionInvalidStateError,
  FeeReductionNotFoundError,
  FeeReductionSelfApprovalError,
  FeeReductionValidationError,
  feeReductionToApi,
  listFeeReductions,
  type FeeReductionSourceKind,
  type FeeReductionStatus,
  proposeFeeReduction,
  rejectFeeReduction,
  reverseFeeReduction,
} from "./finance_fee_reductions_repository.ts";

function requireFinanceWrite(claims: Parameters<typeof requirePermission>[0]): Response | null {
  return requirePermission(claims, "manageFinance") ??
    requireSchoolOperationalScope(claims);
}

function requireFinanceRead(claims: Parameters<typeof requirePermission>[0]): Response | null {
  return requirePermission(claims, "viewFinance") ??
    requireSchoolOperationalScope(claims);
}

function requireReductionApproval(claims: Parameters<typeof requirePermission>[0]): Response | null {
  return requirePermission(claims, "approveFeeConcession") ??
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

function optionalNum(
  body: Record<string, unknown>,
  snakeKey: string,
  camelKey: string,
): number | undefined {
  const raw = optionalStr(body, snakeKey, camelKey);
  if (raw == null) return undefined;
  const n = parseFloat(raw);
  return Number.isFinite(n) ? n : undefined;
}

async function runTenant<T>(
  config: AppConfig,
  claims: Parameters<typeof withTenantContext>[1],
  operation: Parameters<typeof withTenantContext<T>>[2],
): Promise<T> {
  return await withTenantContext(config, claims, operation);
}

function mapReductionError(error: unknown): Response | null {
  if (error instanceof FeeReductionNotFoundError) {
    return errorEnvelope("NOT_FOUND", error.message, 404);
  }
  if (error instanceof FeeReductionSelfApprovalError) {
    return errorEnvelope("FORBIDDEN", error.message, 403);
  }
  if (
    error instanceof FeeReductionValidationError ||
    error instanceof FeeReductionInvalidStateError
  ) {
    return errorEnvelope("VALIDATION_ERROR", error.message, 422);
  }
  return null;
}

/** Shared body parse for the two propose endpoints (scholarship / discount). */
function parseReductionKind(
  body: Record<string, unknown>,
): { reductionKind: FeeReductionKind; percent?: number; fixedAmount?: number } | Response {
  const rawKind = optionalStr(body, "reduction_kind", "reductionKind");
  const percent = optionalNum(body, "percent", "percent");
  const fixedAmount = optionalNum(body, "fixed_amount", "fixedAmount") ??
    optionalNum(body, "amount", "amount");

  // Infer the kind when unspecified: a percent value → percent, else fixed.
  const reductionKind: FeeReductionKind = rawKind === "percent" || rawKind === "fixed"
    ? rawKind
    : (percent != null ? "percent" : "fixed");

  if (reductionKind === "percent") {
    if (percent == null) {
      return errorEnvelope("VALIDATION_ERROR", "percent is required for a percent reduction", 422);
    }
    return { reductionKind, percent };
  }
  if (fixedAmount == null) {
    return errorEnvelope("VALIDATION_ERROR", "amount is required for a fixed reduction", 422);
  }
  return { reductionKind, fixedAmount };
}

async function handlePropose(
  req: Request,
  config: AppConfig,
  sourceKind: FeeReductionSourceKind,
): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;

  const denied = requireFinanceWrite(auth.claims);
  if (denied) return denied;

  const body = await readJson<Record<string, unknown>>(req);
  if (!body) {
    return errorEnvelope("VALIDATION_ERROR", "Request body is required", 422);
  }

  const sourceId = sourceKind === "scholarship"
    ? optionalStr(body, "scholarship_id", "scholarshipId")
    : optionalStr(body, "discount_rule_id", "discountRuleId");
  const invoiceId = optionalStr(body, "invoice_id", "invoiceId");
  const reason = optionalStr(body, "reason", "reason") ?? "";

  if (!sourceId) {
    return errorEnvelope(
      "VALIDATION_ERROR",
      sourceKind === "scholarship" ? "scholarshipId is required" : "discountRuleId is required",
      422,
    );
  }
  if (!invoiceId) {
    return errorEnvelope("VALIDATION_ERROR", "invoiceId is required", 422);
  }

  const kind = parseReductionKind(body);
  if (kind instanceof Response) return kind;

  const orgId = organizationIdFromClaims(auth.claims);
  const schoolId = schoolIdFromClaims(auth.claims);

  try {
    const row = await runTenant(config, auth.claims, async (db) => {
      const created = await proposeFeeReduction(db, orgId, schoolId, {
        sourceKind,
        sourceId,
        invoiceId,
        reductionKind: kind.reductionKind,
        percent: kind.percent,
        fixedAmount: kind.fixedAmount,
        reason,
        createdBy: auth.claims.sub,
      });
      await emitMutationAudit(
        db,
        auth.claims,
        moduleEntityAudit(
          "finance.feeReduction.proposed",
          "finance_fee_reduction",
          created.id,
          {
            sourceKind,
            sourceId,
            invoiceId,
            reductionKind: kind.reductionKind,
          },
        ),
        req,
      );
      return created;
    });
    return jsonResponse(envelope(feeReductionToApi(row)), { status: 201 });
  } catch (error) {
    if (error instanceof TenantDbNotConfiguredError) {
      return tenantDbNotConfiguredResponse();
    }
    const mapped = mapReductionError(error);
    if (mapped) return mapped;
    throw error;
  }
}

export function handleProposeScholarshipAward(req: Request, config: AppConfig): Promise<Response> {
  return handlePropose(req, config, "scholarship");
}

export function handleProposeDiscountApplication(req: Request, config: AppConfig): Promise<Response> {
  return handlePropose(req, config, "discount");
}

export async function handleApproveFeeReduction(
  req: Request,
  config: AppConfig,
  reductionId: string,
): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;

  const denied = requireReductionApproval(auth.claims);
  if (denied) return denied;

  const orgId = organizationIdFromClaims(auth.claims);
  const schoolId = schoolIdFromClaims(auth.claims);

  try {
    const row = await runTenant(config, auth.claims, async (db) => {
      // SoD: the approver (server-set claims.sub) must not be the proposer —
      // enforced inside approveFeeReduction before any money mutation.
      const approved = await approveFeeReduction(db, orgId, schoolId, reductionId, auth.claims.sub);
      await emitMutationAudit(
        db,
        auth.claims,
        moduleEntityAudit("finance.feeReduction.approved", "finance_fee_reduction", reductionId, {
          appliedAmount: String(approved.applied_amount),
        }),
        req,
      );
      // Distinct "applied" money event (the reduction actually hit the payable).
      await emitMutationAudit(
        db,
        auth.claims,
        moduleEntityAudit("finance.feeReduction.applied", "finance_fee_reduction", reductionId, {
          invoiceId: approved.invoice_id,
          appliedAmount: String(approved.applied_amount),
        }),
        req,
      );
      return approved;
    });
    return jsonResponse(envelope(feeReductionToApi(row)));
  } catch (error) {
    if (error instanceof TenantDbNotConfiguredError) {
      return tenantDbNotConfiguredResponse();
    }
    const mapped = mapReductionError(error);
    if (mapped) return mapped;
    throw error;
  }
}

export async function handleRejectFeeReduction(
  req: Request,
  config: AppConfig,
  reductionId: string,
): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;

  const denied = requireReductionApproval(auth.claims);
  if (denied) return denied;

  const orgId = organizationIdFromClaims(auth.claims);
  const schoolId = schoolIdFromClaims(auth.claims);

  try {
    const row = await runTenant(config, auth.claims, async (db) => {
      const rejected = await rejectFeeReduction(db, orgId, schoolId, reductionId, auth.claims.sub);
      await emitMutationAudit(
        db,
        auth.claims,
        moduleEntityAudit("finance.feeReduction.rejected", "finance_fee_reduction", reductionId),
        req,
      );
      return rejected;
    });
    return jsonResponse(envelope(feeReductionToApi(row)));
  } catch (error) {
    if (error instanceof TenantDbNotConfiguredError) {
      return tenantDbNotConfiguredResponse();
    }
    const mapped = mapReductionError(error);
    if (mapped) return mapped;
    throw error;
  }
}

export async function handleReverseFeeReduction(
  req: Request,
  config: AppConfig,
  reductionId: string,
): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;

  const denied = requireReductionApproval(auth.claims);
  if (denied) return denied;

  const orgId = organizationIdFromClaims(auth.claims);
  const schoolId = schoolIdFromClaims(auth.claims);

  try {
    const row = await runTenant(config, auth.claims, async (db) => {
      const reversed = await reverseFeeReduction(db, orgId, schoolId, reductionId, auth.claims.sub);
      await emitMutationAudit(
        db,
        auth.claims,
        moduleEntityAudit("finance.feeReduction.reversed", "finance_fee_reduction", reductionId, {
          restoredAmount: String(reversed.applied_amount),
        }),
        req,
      );
      return reversed;
    });
    return jsonResponse(envelope(feeReductionToApi(row)));
  } catch (error) {
    if (error instanceof TenantDbNotConfiguredError) {
      return tenantDbNotConfiguredResponse();
    }
    const mapped = mapReductionError(error);
    if (mapped) return mapped;
    throw error;
  }
}

export async function handleListFeeReductions(
  req: Request,
  config: AppConfig,
): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;

  const denied = requireFinanceRead(auth.claims);
  if (denied) return denied;

  const orgId = organizationIdFromClaims(auth.claims);
  const schoolId = schoolIdFromClaims(auth.claims);
  const url = new URL(req.url);

  try {
    const rows = await runTenant(config, auth.claims, (db) =>
      listFeeReductions(db, orgId, schoolId, {
        status: (url.searchParams.get("status") ?? undefined) as FeeReductionStatus | undefined,
        invoiceId: url.searchParams.get("invoiceId") ??
          url.searchParams.get("invoice_id") ?? undefined,
        studentId: url.searchParams.get("studentId") ??
          url.searchParams.get("student_id") ?? undefined,
        sourceKind: (url.searchParams.get("sourceKind") ??
          url.searchParams.get("source_kind") ?? undefined) as
            FeeReductionSourceKind | undefined,
      })
    );
    return jsonResponse(envelope({ items: rows.map(feeReductionToApi) }));
  } catch (error) {
    if (error instanceof TenantDbNotConfiguredError) {
      return tenantDbNotConfiguredResponse();
    }
    throw error;
  }
}
