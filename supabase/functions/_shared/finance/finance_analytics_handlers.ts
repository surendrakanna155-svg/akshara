// FIN-9 — GET /finance/analytics/head-wise-dues (read → viewFinance).
//
// Per fee_head, SUM(head_total - head_paid) across OPEN invoices for the school
// (derived from the FIN-D2 head-allocation ledger). Also returns a monthly
// collected-vs-invoiced recovery trend, REUSING the existing 6-month trend
// pattern (finance_intelligence_service.computeFinanceCopilot.collectionTrend)
// so we do not duplicate the dashboard math.

import type { AppConfig } from "../config.ts";
import { envelope, jsonResponse } from "../http.ts";
import {
  authenticateRequest,
  organizationIdFromClaims,
  requirePermission,
  requireSchoolOperationalScope,
  schoolIdFromClaims,
} from "../permission_middleware.ts";
import { TenantDbNotConfiguredError, withTenantContext } from "../tenant_db.ts";
import { tenantDbNotConfiguredResponse } from "../tenant_handlers.ts";
import { headWiseDues } from "./finance_head_allocations_repository.ts";
import { computeFinanceCopilot } from "./finance_intelligence_service.ts";
import { headWiseDueToApi } from "./finance_mapper.ts";

function requireFinanceRead(claims: Parameters<typeof requirePermission>[0]): Response | null {
  return requirePermission(claims, "viewFinance") ??
    requireSchoolOperationalScope(claims);
}

export async function handleHeadWiseDues(
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
    const data = await withTenantContext(config, auth.claims, async (db) => {
      const dues = await headWiseDues(db, orgId, schoolId);
      // Reuse the existing recovery-rate / collection trend (monthly
      // collected-vs-expected) rather than duplicating it.
      const copilot = await computeFinanceCopilot(db, orgId, schoolId);
      return { dues, trend: copilot.collectionTrend };
    });
    return jsonResponse(envelope({
      items: data.dues.map(headWiseDueToApi),
      collectionTrend: data.trend.map((p) => ({
        month: p.month,
        collected: p.collected,
        expected: p.expected,
      })),
    }));
  } catch (error) {
    if (error instanceof TenantDbNotConfiguredError) {
      return tenantDbNotConfiguredResponse();
    }
    throw error;
  }
}
