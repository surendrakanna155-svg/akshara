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
import { executePrincipalQuery } from "../intelligence/principal_query_service.ts";
import { buildPrincipalCommandCenter } from "./principal_command_service.ts";

export async function handlePrincipalCommandCenter(req: Request, config: AppConfig): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;
  const denied = requireAnyPermission(auth.claims, ["viewPrincipalCommand", "viewAnalytics"]) ??
    requireSchoolOperationalScope(auth.claims);
  if (denied) return denied;

  const orgId = organizationIdFromClaims(auth.claims);
  const schoolId = schoolIdFromClaims(auth.claims);

  try {
    const center = await withTenantContext(config, auth.claims, (db) =>
      buildPrincipalCommandCenter(db, orgId, schoolId)
    );
    return jsonResponse(envelope(center));
  } catch (error) {
    if (error instanceof TenantDbNotConfiguredError) return tenantDbNotConfiguredResponse(error);
    return errorEnvelope("PRINCIPAL_COMMAND_ERROR", String(error), 500);
  }
}

export async function handlePrincipalCommandQuery(req: Request, config: AppConfig): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;
  const denied = requireAnyPermission(auth.claims, ["viewPrincipalCommand", "viewAnalytics"]) ??
    requireSchoolOperationalScope(auth.claims);
  if (denied) return denied;

  const url = new URL(req.url);
  const q = url.searchParams.get("q")?.trim() ?? "";
  if (!q) return errorEnvelope("VALIDATION_ERROR", "q is required", 422);

  try {
    const result = await withTenantContext(config, auth.claims, (db) => executePrincipalQuery(db, q));
    return jsonResponse(envelope(result));
  } catch (error) {
    if (error instanceof TenantDbNotConfiguredError) return tenantDbNotConfiguredResponse(error);
    return errorEnvelope("PRINCIPAL_COMMAND_ERROR", String(error), 500);
  }
}
