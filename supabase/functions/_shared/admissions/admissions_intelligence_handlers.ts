// B4 AI Admissions Assistant — read endpoint.
//
// GET /admissions/intelligence → compact funnel summary + ranked
// next-best-actions, so the app can render the assistant card without a chat
// round-trip. Same RBAC as the dashboard (viewAdmissions + school scope).

import type { AppConfig } from "../config.ts";
import { recordServerAuditEvent } from "../audit/audit_repository.ts";
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
import { loadAdmissionsIntelligence } from "./admissions_intelligence_repository.ts";

function requireAdmissionsRead(claims: Parameters<typeof requirePermission>[0]): Response | null {
  return requirePermission(claims, "viewAdmissions") ??
    requireSchoolOperationalScope(claims);
}

export async function handleAdmissionsIntelligence(
  req: Request,
  config: AppConfig,
): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;

  const denied = requireAdmissionsRead(auth.claims);
  if (denied) return denied;

  const orgId = organizationIdFromClaims(auth.claims);
  const schoolId = schoolIdFromClaims(auth.claims);
  if (!schoolId) {
    return errorEnvelope("VALIDATION_ERROR", "school scope required", 422);
  }

  try {
    const intelligence = await withTenantContext(config, auth.claims, async (db) => {
      const result = await loadAdmissionsIntelligence(db, orgId, schoolId);
      await recordServerAuditEvent(db, auth.claims, {
        eventType: "aiAdmissionsAssistantViewed",
        category: "workflow",
        entityType: "admissions_intelligence",
        entityId: schoolId,
        metadata: {
          totalLeads: String(result.funnel.totalLeads),
          actionCount: String(result.nextBestActions.length),
        },
      }, req);
      return result;
    });
    return jsonResponse(envelope(intelligence));
  } catch (error) {
    if (error instanceof TenantDbNotConfiguredError) {
      return tenantDbNotConfiguredResponse(error);
    }
    console.error("handleAdmissionsIntelligence error:", error);
    return errorEnvelope("INTERNAL_ERROR", "Failed to load admissions intelligence", 500);
  }
}
