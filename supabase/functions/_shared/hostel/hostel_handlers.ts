import type { AppConfig } from "../config.ts";
import { envelope, errorEnvelope, jsonResponse } from "../http.ts";
import {
  authenticateRequest,
  organizationIdFromClaims,
  schoolIdFromClaims,
} from "../permission_middleware.ts";
import { TenantDbNotConfiguredError, withTenantContext } from "../tenant_db.ts";
import { tenantDbNotConfiguredResponse } from "../tenant_handlers.ts";
import { createModuleReadHandlers } from "../entity_read/module_read_handlers.ts";
import { hostelStore, recomputeMess, recomputeVisitors } from "./hostel_read_repository.ts";

const { handleSnapshot, handleList, requireRead } = createModuleReadHandlers(
  "viewHostel",
  hostelStore,
);

export async function handleDashboard(req: Request, config: AppConfig): Promise<Response> {
  return await handleSnapshot(req, config, "snapshot_dashboard", "Failed to load hostel dashboard");
}

export async function handleStudents(req: Request, config: AppConfig): Promise<Response> {
  return await handleList(req, config, "student", "Failed to load hostel students");
}

export async function handleRooms(req: Request, config: AppConfig): Promise<Response> {
  return await handleList(req, config, "room", "Failed to load hostel rooms");
}

export async function handleAttendance(req: Request, config: AppConfig): Promise<Response> {
  return await handleList(req, config, "attendance", "Failed to load hostel attendance");
}

export async function handleLeave(req: Request, config: AppConfig): Promise<Response> {
  return await handleList(req, config, "leave_request", "Failed to load hostel leave requests");
}

/**
 * GET /hostel/mess — recomputes the Mess screen payload from the live
 * `mess_record` entities (HOSTE-3) so a just-recorded menu/cost actually
 * appears, falling back to the seeded `snapshot_mess` when no record exists.
 * Same RBAC as the other hostel reads (`viewHostel` permission OR school
 * operational scope) and same tenant context/RLS.
 */
export async function handleMess(req: Request, config: AppConfig): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;

  const denied = requireRead(auth.claims);
  if (denied) return denied;

  const orgId = organizationIdFromClaims(auth.claims);
  const schoolId = schoolIdFromClaims(auth.claims);

  try {
    const payload = await withTenantContext(
      config,
      auth.claims,
      async (db) => await recomputeMess(db, orgId, schoolId),
    );
    return jsonResponse(envelope(payload));
  } catch (error) {
    if (error instanceof TenantDbNotConfiguredError) {
      return tenantDbNotConfiguredResponse(error);
    }
    console.error("handleMess error:", error);
    return errorEnvelope("INTERNAL_ERROR", "Failed to load hostel mess data", 500);
  }
}

/**
 * GET /hostel/visitors — recomputes the Visitors screen payload from the live
 * `visitor` list entities (MJ-M1) so a just-logged visitor actually appears,
 * rather than returning a frozen seeded snapshot. Same RBAC as the other hostel
 * reads (`viewHostel` permission OR school operational scope) and same tenant
 * context/RLS.
 */
export async function handleVisitors(req: Request, config: AppConfig): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;

  const denied = requireRead(auth.claims);
  if (denied) return denied;

  const orgId = organizationIdFromClaims(auth.claims);
  const schoolId = schoolIdFromClaims(auth.claims);

  try {
    const payload = await withTenantContext(
      config,
      auth.claims,
      async (db) => await recomputeVisitors(db, orgId, schoolId),
    );
    return jsonResponse(envelope(payload));
  } catch (error) {
    if (error instanceof TenantDbNotConfiguredError) {
      return tenantDbNotConfiguredResponse(error);
    }
    console.error("handleVisitors error:", error);
    return errorEnvelope("INTERNAL_ERROR", "Failed to load hostel visitors", 500);
  }
}

export async function handleReports(req: Request, config: AppConfig): Promise<Response> {
  return await handleSnapshot(req, config, "snapshot_reports", "Failed to load hostel reports");
}

export async function handleOccupancyMetrics(req: Request, config: AppConfig): Promise<Response> {
  return await handleSnapshot(req, config, "snapshot_occupancy", "Failed to load hostel occupancy");
}
