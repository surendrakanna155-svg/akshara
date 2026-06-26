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
import { listEnvelope } from "../finance/finance_mapper.ts";
import {
  type EmployeeDetailContext,
  employeeDetailToApi,
  getEmployee,
  getSnapshot,
  HrEmployeeNotFoundError,
  HrSnapshotNotFoundError,
  listEntities,
} from "./hr_read_repository.ts";

/**
 * Loads a snapshot's payload, returning an empty object when the snapshot does
 * not exist for this school (so the employee detail degrades gracefully instead
 * of failing the whole request).
 */
async function getSnapshotOrEmpty(
  db: Parameters<typeof getSnapshot>[0],
  orgId: string,
  schoolId: string,
  entityType: string,
): Promise<Record<string, unknown>> {
  try {
    return await getSnapshot(db, orgId, schoolId, entityType);
  } catch (error) {
    if (error instanceof HrSnapshotNotFoundError) return {};
    throw error;
  }
}

function parsePagination(url: URL): { page: number; pageSize: number } {
  const page = Math.max(1, parseInt(url.searchParams.get("page") ?? "1", 10) || 1);
  const pageSize = Math.min(
    100,
    Math.max(1, parseInt(url.searchParams.get("pageSize") ?? "20", 10) || 20),
  );
  return { page, pageSize };
}

async function runTenant<T>(
  config: AppConfig,
  claims: Parameters<typeof withTenantContext>[1],
  operation: Parameters<typeof withTenantContext<T>>[2],
): Promise<T> {
  return await withTenantContext(config, claims, operation);
}

function requireHrRead(claims: Parameters<typeof requirePermission>[0]): Response | null {
  return requirePermission(claims, "viewHr") ??
    requireSchoolOperationalScope(claims);
}

async function handleSnapshot(
  req: Request,
  config: AppConfig,
  entityType: string,
  notFoundMessage: string,
): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;

  const denied = requireHrRead(auth.claims);
  if (denied) return denied;

  const orgId = organizationIdFromClaims(auth.claims);
  const schoolId = schoolIdFromClaims(auth.claims);

  try {
    const snapshot = await runTenant(config, auth.claims, async (db) =>
      await getSnapshot(db, orgId, schoolId, entityType)
    );
    return jsonResponse(envelope(snapshot));
  } catch (error) {
    if (error instanceof TenantDbNotConfiguredError) {
      return tenantDbNotConfiguredResponse(error);
    }
    if (error instanceof HrSnapshotNotFoundError) {
      return errorEnvelope("NOT_FOUND", notFoundMessage, 404);
    }
    console.error(`handleSnapshot(${entityType}) error:`, error);
    return errorEnvelope("INTERNAL_ERROR", notFoundMessage, 500);
  }
}

export async function handleDashboard(req: Request, config: AppConfig): Promise<Response> {
  return await handleSnapshot(req, config, "snapshot_dashboard", "Failed to load HR dashboard");
}

export async function handleEmployees(req: Request, config: AppConfig): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;

  const denied = requireHrRead(auth.claims);
  if (denied) return denied;

  const url = new URL(req.url);
  const pagination = parsePagination(url);
  const orgId = organizationIdFromClaims(auth.claims);
  const schoolId = schoolIdFromClaims(auth.claims);

  try {
    const result = await runTenant(config, auth.claims, async (db) =>
      await listEntities(db, orgId, schoolId, "employee", pagination)
    );
    return jsonResponse(
      envelope(
        listEnvelope(result.items, {
          page: result.page,
          pageSize: result.pageSize,
          total: result.total,
          hasMore: result.hasMore,
        }),
      ),
    );
  } catch (error) {
    if (error instanceof TenantDbNotConfiguredError) {
      return tenantDbNotConfiguredResponse(error);
    }
    console.error("handleEmployees error:", error);
    return errorEnvelope("INTERNAL_ERROR", "Failed to load employees", 500);
  }
}

export async function handleEmployeeDetail(
  req: Request,
  config: AppConfig,
  employeeId: string,
): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;

  const denied = requireHrRead(auth.claims);
  if (denied) return denied;

  const orgId = organizationIdFromClaims(auth.claims);
  const schoolId = schoolIdFromClaims(auth.claims);

  try {
    const { employee, context } = await runTenant(config, auth.claims, async (db) => {
      const employee = await getEmployee(db, orgId, schoolId, employeeId);
      const [attendance, leave, settings] = await Promise.all([
        getSnapshotOrEmpty(db, orgId, schoolId, "snapshot_attendance"),
        getSnapshotOrEmpty(db, orgId, schoolId, "snapshot_leave"),
        getSnapshotOrEmpty(db, orgId, schoolId, "snapshot_settings"),
      ]);
      const context: EmployeeDetailContext = {
        attendanceRecords: Array.isArray(attendance.records)
          ? attendance.records as Array<Record<string, unknown>>
          : [],
        leaveRequests: Array.isArray(leave.requests)
          ? leave.requests as Array<Record<string, unknown>>
          : [],
        leavePolicy: Array.isArray(settings.leavePolicy)
          ? settings.leavePolicy as Array<{ leaveType: string; entitlement: number }>
          : undefined,
      };
      return { employee, context };
    });
    return jsonResponse(envelope(employeeDetailToApi(employee, context)));
  } catch (error) {
    if (error instanceof TenantDbNotConfiguredError) {
      return tenantDbNotConfiguredResponse(error);
    }
    if (error instanceof HrEmployeeNotFoundError) {
      return errorEnvelope("NOT_FOUND", `Employee not found: ${employeeId}`, 404);
    }
    console.error("handleEmployeeDetail error:", error);
    return errorEnvelope("INTERNAL_ERROR", "Failed to load employee detail", 500);
  }
}

export async function handleAttendance(req: Request, config: AppConfig): Promise<Response> {
  return await handleSnapshot(req, config, "snapshot_attendance", "Failed to load HR attendance");
}

export async function handleLeave(req: Request, config: AppConfig): Promise<Response> {
  return await handleSnapshot(req, config, "snapshot_leave", "Failed to load HR leave");
}

export async function handlePayroll(req: Request, config: AppConfig): Promise<Response> {
  return await handleSnapshot(req, config, "snapshot_payroll", "Failed to load HR payroll");
}

export async function handleRecruitment(req: Request, config: AppConfig): Promise<Response> {
  return await handleSnapshot(req, config, "snapshot_recruitment", "Failed to load HR recruitment");
}

export async function handlePerformance(req: Request, config: AppConfig): Promise<Response> {
  return await handleSnapshot(req, config, "snapshot_performance", "Failed to load HR performance");
}

export async function handleSettings(req: Request, config: AppConfig): Promise<Response> {
  return await handleSnapshot(req, config, "snapshot_settings", "Failed to load HR settings");
}
