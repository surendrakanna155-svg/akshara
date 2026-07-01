import type { AppConfig } from "../config.ts";
import { envelope, errorEnvelope, jsonResponse } from "../http.ts";
import {
  authenticateRequest,
  organizationIdFromClaims,
  requirePermission,
  requireSchoolOperationalScope,
  schoolIdFromClaims,
} from "../permission_middleware.ts";
import { TenantDbNotConfiguredError, withTenantContext } from "../tenant_db.ts";
import { tenantDbNotConfiguredResponse } from "../tenant_handlers.ts";
import { getStudentLedger } from "./finance_ledger_repository.ts";
import { studentLedgerToApi } from "./finance_mapper.ts";

// FIN-2 — GET /finance/student-accounts/{id}/ledger (viewFinance). Read-only
// printable fee statement: invoices + payments + running balance + summary.

function requireFinanceRead(claims: Parameters<typeof requirePermission>[0]): Response | null {
  return requirePermission(claims, "viewFinance") ??
    requireSchoolOperationalScope(claims);
}

export async function handleStudentLedger(
  req: Request,
  config: AppConfig,
  studentAccountId: string,
): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;

  const denied = requireFinanceRead(auth.claims);
  if (denied) return denied;

  const orgId = organizationIdFromClaims(auth.claims);
  const schoolId = schoolIdFromClaims(auth.claims);

  try {
    const ledger = await withTenantContext(config, auth.claims, (db) =>
      getStudentLedger(db, orgId, schoolId, studentAccountId)
    );
    if (!ledger) {
      return errorEnvelope(
        "NOT_FOUND",
        `Student account not found: ${studentAccountId}`,
        404,
      );
    }
    return jsonResponse(envelope(studentLedgerToApi(ledger)));
  } catch (error) {
    if (error instanceof TenantDbNotConfiguredError) {
      return tenantDbNotConfiguredResponse();
    }
    throw error;
  }
}
