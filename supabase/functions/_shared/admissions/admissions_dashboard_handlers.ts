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
import { dashboardToApi } from "./admissions_dashboard_mapper.ts";
import { getDashboard } from "./admissions_dashboard_repository.ts";

async function runTenant<T>(
  config: AppConfig,
  claims: Parameters<typeof withTenantContext>[1],
  operation: Parameters<typeof withTenantContext<T>>[2],
): Promise<T> {
  return await withTenantContext(config, claims, operation);
}

function requireAdmissionsRead(claims: Parameters<typeof requirePermission>[0]): Response | null {
  return requirePermission(claims, "viewAdmissions") ??
    requireSchoolOperationalScope(claims);
}

export async function handleDashboard(
  req: Request,
  config: AppConfig,
): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;

  const denied = requireAdmissionsRead(auth.claims);
  if (denied) return denied;

  const orgId = organizationIdFromClaims(auth.claims);
  const schoolId = schoolIdFromClaims(auth.claims);

  try {
    const dashboard = await runTenant(config, auth.claims, async (db) =>
      await getDashboard(db, orgId, schoolId)
    );
    return jsonResponse(envelope(dashboardToApi(dashboard)));
  } catch (error) {
    if (error instanceof TenantDbNotConfiguredError) {
      return tenantDbNotConfiguredResponse(error);
    }
    console.error("handleAdmissionsDashboard error:", error);
    return errorEnvelope("INTERNAL_ERROR", "Failed to load admissions dashboard", 500);
  }
}
