// WEB-001 (ERP-WT-001) — GET /dashboard/overview handler.

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
import { buildDashboardOverview } from "./dashboard_service.ts";

/**
 * GET /dashboard/overview — the school-admin landing KPIs (students, attendance
 * today, fees today + MTD + outstanding, pending admissions, recent enrolments).
 * Gated by the general admin-hub slug + school operational scope, matching the
 * per-module dashboards it composes.
 */
export async function handleDashboardOverview(
  req: Request,
  config: AppConfig,
): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;
  const denied = requirePermission(auth.claims, "viewAdminHub") ??
    requireSchoolOperationalScope(auth.claims);
  if (denied) return denied;

  const schoolId = schoolIdFromClaims(auth.claims);
  if (!schoolId) {
    return errorEnvelope("VALIDATION_ERROR", "School scope required", 422);
  }

  try {
    const overview = await withTenantContext(config, auth.claims, (db) =>
      buildDashboardOverview(db, organizationIdFromClaims(auth.claims), schoolId));
    return jsonResponse(envelope(overview));
  } catch (error) {
    if (error instanceof TenantDbNotConfiguredError) {
      return tenantDbNotConfiguredResponse(error);
    }
    return errorEnvelope("INTERNAL_ERROR", "Failed to load dashboard overview", 500);
  }
}
