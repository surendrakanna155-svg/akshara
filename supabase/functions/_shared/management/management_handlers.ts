import type { AppConfig } from "../config.ts";
import { envelope, errorEnvelope, jsonResponse } from "../http.ts";
import {
  authenticateRequest,
  organizationIdFromClaims,
  requirePermission,
  schoolIdFromClaims,
} from "../permission_middleware.ts";
import { TenantDbNotConfiguredError, withTenantContext } from "../tenant_db.ts";
import { tenantDbNotConfiguredResponse } from "../tenant_handlers.ts";
import { createManagementReadHandlers } from "../entity_read/management_read_handlers.ts";
import { managementStore } from "./management_read_repository.ts";
import {
  getManagementAggregate,
  type ManagementAggregate,
} from "./management_aggregate_repository.ts";
import {
  buildAcademicHealthPayload,
  buildAdmissionsFunnelPayload,
  buildAnalyticsPayload,
  buildDashboardPayload,
  buildFinancialHealthPayload,
  buildSchoolPerformancePayload,
} from "./management_payload_builders.ts";

const { handleSnapshot } = createManagementReadHandlers("viewManagement", managementStore);

// MJ-C8 (PRINC-1): the six executive read endpoints below now COMPUTE their
// payloads from the real live tables (finance_*, admissions_*, students,
// attendance_*, exam_*) inside the caller's tenant RLS context, replacing the
// never-refreshed `management_entities` seed snapshot. `tasks` and `settings`
// remain on the snapshot store (out of scope for this item).

function requireManagementRead(claims: Parameters<typeof requirePermission>[0]): Response | null {
  const permissionDenied = requirePermission(claims, "viewManagement");
  if (permissionDenied) return permissionDenied;
  if (claims.scope !== "school" || !claims.school_id) {
    return errorEnvelope("FORBIDDEN", "Management data requires school scope", 403);
  }
  return null;
}

async function handleComputed(
  req: Request,
  config: AppConfig,
  build: (agg: ManagementAggregate) => Record<string, unknown>,
  failureMessage: string,
): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;

  const denied = requireManagementRead(auth.claims);
  if (denied) return denied;

  const orgId = organizationIdFromClaims(auth.claims);
  const schoolId = schoolIdFromClaims(auth.claims);

  try {
    const payload = await withTenantContext(config, auth.claims, async (db) => {
      const aggregate = await getManagementAggregate(db, orgId, schoolId);
      return build(aggregate);
    });
    return jsonResponse(envelope(payload));
  } catch (error) {
    if (error instanceof TenantDbNotConfiguredError) {
      return tenantDbNotConfiguredResponse(error);
    }
    console.error(`${failureMessage}:`, error);
    return errorEnvelope("INTERNAL_ERROR", failureMessage, 500);
  }
}

export async function handleDashboard(req: Request, config: AppConfig): Promise<Response> {
  return await handleComputed(req, config, buildDashboardPayload, "Failed to load management dashboard");
}

export async function handleAnalytics(req: Request, config: AppConfig): Promise<Response> {
  return await handleComputed(req, config, buildAnalyticsPayload, "Failed to load management analytics");
}

export async function handleAdmissionsFunnel(req: Request, config: AppConfig): Promise<Response> {
  return await handleComputed(
    req,
    config,
    buildAdmissionsFunnelPayload,
    "Failed to load admissions funnel",
  );
}

export async function handleFinancialHealth(req: Request, config: AppConfig): Promise<Response> {
  return await handleComputed(
    req,
    config,
    buildFinancialHealthPayload,
    "Failed to load financial health",
  );
}

export async function handleAcademicHealth(req: Request, config: AppConfig): Promise<Response> {
  return await handleComputed(
    req,
    config,
    buildAcademicHealthPayload,
    "Failed to load academic health",
  );
}

export async function handleSchoolPerformance(req: Request, config: AppConfig): Promise<Response> {
  return await handleComputed(
    req,
    config,
    buildSchoolPerformancePayload,
    "Failed to load school performance",
  );
}

export async function handleTasks(req: Request, config: AppConfig): Promise<Response> {
  return await handleSnapshot(req, config, "snapshot_tasks", "Failed to load tasks and approvals");
}

export async function handleSettings(req: Request, config: AppConfig): Promise<Response> {
  return await handleSnapshot(req, config, "snapshot_settings", "Failed to load management settings");
}
