import type { AppConfig } from "../config.ts";
import { envelope, errorEnvelope, jsonResponse } from "../http.ts";
import {
  authenticateRequest,
  organizationIdFromClaims,
  requireAnyPermission,
  requirePermission,
  requireSchoolOperationalScope,
  schoolIdFromClaims,
} from "../permission_middleware.ts";
import { TenantDbNotConfiguredError, withTenantContext } from "../tenant_db.ts";
import { tenantDbNotConfiguredResponse } from "../tenant_handlers.ts";
import { emitMutationAudit, financeAudit } from "../audit/mutation_audit_catalog.ts";
import {
  computeFinanceCopilot,
  computeFinanceExecutive,
} from "./finance_intelligence_service.ts";
import { insertIntelligenceSnapshot } from "./finance_intelligence_repository.ts";

function requireFinanceIntelligence(claims: Parameters<typeof requirePermission>[0]): Response | null {
  return requirePermission(claims, "viewFinanceIntelligence") ??
    requireSchoolOperationalScope(claims);
}

function requireFinanceExecutive(claims: Parameters<typeof requirePermission>[0]): Response | null {
  return requireAnyPermission(claims, ["viewFinanceExecutiveDashboard", "viewFinanceIntelligence"]) ??
    requireSchoolOperationalScope(claims);
}

export async function handleFinanceCopilot(
  req: Request,
  config: AppConfig,
): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;

  const denied = requireFinanceIntelligence(auth.claims);
  if (denied) return denied;

  const orgId = organizationIdFromClaims(auth.claims);
  const schoolId = schoolIdFromClaims(auth.claims);

  try {
    const snapshot = await withTenantContext(config, auth.claims, async (db) => {
      const data = await computeFinanceCopilot(db, orgId, schoolId);
      await insertIntelligenceSnapshot(
        db,
        orgId,
        schoolId,
        "copilot",
        data,
        auth.claims.sub ?? null,
      );
      await emitMutationAudit(db, auth.claims, financeAudit.intelligenceComputed(), req);
      return data;
    });
    return jsonResponse(envelope(snapshot));
  } catch (error) {
    if (error instanceof TenantDbNotConfiguredError) {
      return tenantDbNotConfiguredResponse();
    }
    console.error("handleFinanceCopilot error:", error);
    return errorEnvelope("INTERNAL_ERROR", "Failed to compute finance copilot", 500);
  }
}

export async function handleFinanceExecutiveDashboard(
  req: Request,
  config: AppConfig,
): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;

  const denied = requireFinanceExecutive(auth.claims);
  if (denied) return denied;

  const orgId = organizationIdFromClaims(auth.claims);
  const schoolId = schoolIdFromClaims(auth.claims);

  try {
    const snapshot = await withTenantContext(config, auth.claims, async (db) => {
      const data = await computeFinanceExecutive(db, orgId, schoolId);
      await insertIntelligenceSnapshot(
        db,
        orgId,
        schoolId,
        "executive",
        data,
        auth.claims.sub ?? null,
      );
      await emitMutationAudit(
        db,
        auth.claims,
        financeAudit.executiveViewed(data.collectionHealthScore),
        req,
      );
      return data;
    });
    return jsonResponse(envelope(snapshot));
  } catch (error) {
    if (error instanceof TenantDbNotConfiguredError) {
      return tenantDbNotConfiguredResponse();
    }
    console.error("handleFinanceExecutiveDashboard error:", error);
    return errorEnvelope("INTERNAL_ERROR", "Failed to load executive dashboard", 500);
  }
}
