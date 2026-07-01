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
  accrueLateFees,
  LateFeeNotFoundError,
  NoLateFeeError,
  waiveLateFee,
} from "./finance_late_fee_repository.ts";
import { invoiceToApi } from "./finance_mapper.ts";

// FIN-D5 — late-fee accrual + waive HTTP handlers. Both gate on manageFinance
// (they move money onto the outstanding balance). Additive to the payment path.

function requireFinanceWrite(claims: Parameters<typeof requirePermission>[0]): Response | null {
  return requirePermission(claims, "manageFinance") ??
    requireSchoolOperationalScope(claims);
}

// POST /finance/late-fees/accrue
export async function handleAccrueLateFees(
  req: Request,
  config: AppConfig,
): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;

  const denied = requireFinanceWrite(auth.claims);
  if (denied) return denied;

  const orgId = organizationIdFromClaims(auth.claims);
  const schoolId = schoolIdFromClaims(auth.claims);

  try {
    const result = await withTenantContext(config, auth.claims, async (db) => {
      const summary = await accrueLateFees(db, orgId, schoolId);
      // Only audit when something actually accrued — a zero pass is a read.
      if (summary.accruedCount > 0) {
        await emitMutationAudit(
          db,
          auth.claims,
          financeAudit.lateFeesAccrued(
            schoolId ?? "",
            summary.accruedCount,
            summary.totalLateFee,
            `${Date.now()}`,
          ),
          req,
        );
      }
      return summary;
    });
    return jsonResponse(envelope({
      accruedCount: result.accruedCount,
      totalLateFee: result.totalLateFee.toFixed(2),
    }));
  } catch (error) {
    if (error instanceof TenantDbNotConfiguredError) {
      return tenantDbNotConfiguredResponse();
    }
    throw error;
  }
}

// POST /finance/invoices/{id}/waive-late-fee
export async function handleWaiveLateFee(
  req: Request,
  config: AppConfig,
  invoiceId: string,
): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;

  const denied = requireFinanceWrite(auth.claims);
  if (denied) return denied;

  const body = await readJson<Record<string, unknown>>(req) ?? {};
  const reason = String(body.reason ?? "").trim();
  if (reason === "") {
    return errorEnvelope("VALIDATION_ERROR", "A waive reason is required", 422);
  }

  const orgId = organizationIdFromClaims(auth.claims);
  const schoolId = schoolIdFromClaims(auth.claims);

  try {
    const invoice = await withTenantContext(config, auth.claims, async (db) => {
      const result = await waiveLateFee(db, orgId, schoolId, invoiceId);
      await emitMutationAudit(
        db,
        auth.claims,
        financeAudit.lateFeeWaived(invoiceId, reason),
        req,
      );
      return result.invoice;
    });
    return jsonResponse(envelope(invoiceToApi(invoice)));
  } catch (error) {
    if (error instanceof TenantDbNotConfiguredError) {
      return tenantDbNotConfiguredResponse();
    }
    if (error instanceof LateFeeNotFoundError) {
      return errorEnvelope("NOT_FOUND", error.message, 404);
    }
    if (error instanceof NoLateFeeError) {
      return errorEnvelope("VALIDATION_ERROR", error.message, 422);
    }
    throw error;
  }
}
