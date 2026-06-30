// Staff Face ID attendance — write handler.
// POST /staff-attendance/check : a staff member records their OWN check-in/out.
// RBAC: markStaffAttendance + school operational scope. The acting employee is
// the JWT subject (server-derived), never client-supplied — buddy-punching
// prevention. Emits a server mutation audit on success.

import type { AppConfig } from "../config.ts";
import { envelope, errorEnvelope, jsonResponse, readJson } from "../http.ts";
import {
  authenticateRequest,
  organizationIdFromClaims,
  requirePermission,
  requireSchoolOperationalScope,
  schoolIdFromClaims,
} from "../permission_middleware.ts";
import { TenantDbNotConfiguredError, withTenantContext } from "../tenant_db.ts";
import { tenantDbNotConfiguredResponse } from "../tenant_handlers.ts";
import { recordMutationAudit } from "../audit/audit_repository.ts";
import { staffAttendanceAudit } from "../audit/mutation_audit_catalog.ts";
import {
  parseStaffCheckBody,
  recordStaffCheckIn,
  StaffAttendanceValidationError,
  staffCheckInToApi,
} from "./staff_check_in_repository.ts";

type AuthedClaims = Parameters<typeof requirePermission>[0];

function requireStaffCheckIn(claims: AuthedClaims): Response | null {
  return requirePermission(claims, "markStaffAttendance") ??
    requireSchoolOperationalScope(claims);
}

export async function handleRecordStaffCheckIn(
  req: Request,
  config: AppConfig,
): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;

  const denied = requireStaffCheckIn(auth.claims);
  if (denied) return denied;

  try {
    const body = await readJson<Record<string, unknown>>(req);
    const parsed = parseStaffCheckBody(body);
    const claims = auth.claims;
    const organizationId = organizationIdFromClaims(claims);
    const schoolId = schoolIdFromClaims(claims);

    const row = await withTenantContext(config, claims, async (db) => {
      const inserted = await recordStaffCheckIn(db, organizationId, schoolId, {
        // Identity is the JWT subject — NOT a client-supplied employee id.
        userId: String((claims as { sub?: string }).sub ?? ""),
        staffName: parsed.staffName,
        staffRole: String((claims as { primary_role?: string; role?: string }).primary_role ??
          (claims as { role?: string }).role ?? ""),
        employeeRef: parsed.employeeRef,
        eventType: parsed.eventType,
        method: parsed.method,
        biometricVerified: parsed.biometricVerified,
      });

      const spec = parsed.eventType === "check_in"
        ? staffAttendanceAudit.checkInRecorded(inserted.id, inserted.user_id, inserted.method)
        : staffAttendanceAudit.checkOutRecorded(inserted.id, inserted.user_id, inserted.method);
      await recordMutationAudit(db, claims, spec.audit, spec.domain, req);

      return inserted;
    });

    return jsonResponse(envelope(staffCheckInToApi(row)));
  } catch (error) {
    if (error instanceof TenantDbNotConfiguredError) {
      return tenantDbNotConfiguredResponse();
    }
    if (error instanceof StaffAttendanceValidationError) {
      return errorEnvelope("STAFF_ATTENDANCE_VALIDATION", error.message, 422);
    }
    throw error;
  }
}
