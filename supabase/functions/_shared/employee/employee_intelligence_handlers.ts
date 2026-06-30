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
import {
  buildEmployee360,
  buildEmployeeIntelligenceDashboard,
} from "./employee_intelligence_service.ts";

function requireIntelRead(claims: Parameters<typeof requirePermission>[0]): Response | null {
  return requireAnyPermission(claims, ["viewEmployeeIntelligence", "viewEmployees"]) ??
    requireSchoolOperationalScope(claims);
}

export async function handleEmployee360(
  req: Request,
  config: AppConfig,
  employeeId: string,
): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;
  const denied = requireIntelRead(auth.claims);
  if (denied) return denied;

  try {
    const profile = await withTenantContext(config, auth.claims, (db) =>
      buildEmployee360(
        db,
        organizationIdFromClaims(auth.claims),
        schoolIdFromClaims(auth.claims),
        employeeId,
      )
    );
    return jsonResponse(envelope(profile));
  } catch (error) {
    if (error instanceof TenantDbNotConfiguredError) return tenantDbNotConfiguredResponse(error);
    const message = error instanceof Error ? error.message : "Employee 360 failed";
    return errorEnvelope("EMPLOYEE_360_ERROR", message, 500);
  }
}

export async function handleEmployeeIntelligenceDashboard(
  req: Request,
  config: AppConfig,
): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;
  const denied = requireIntelRead(auth.claims);
  if (denied) return denied;

  try {
    const dashboard = await withTenantContext(config, auth.claims, (db) =>
      buildEmployeeIntelligenceDashboard(
        db,
        organizationIdFromClaims(auth.claims),
        schoolIdFromClaims(auth.claims),
      )
    );
    return jsonResponse(envelope(dashboard));
  } catch (error) {
    if (error instanceof TenantDbNotConfiguredError) return tenantDbNotConfiguredResponse(error);
    return errorEnvelope("EMPLOYEE_INTEL_ERROR", "Employee intelligence dashboard failed", 500);
  }
}
