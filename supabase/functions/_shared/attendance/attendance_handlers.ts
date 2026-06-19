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
import {
  AttendanceCorrectionNotFoundError,
  AttendanceValidationError,
  correctionToApi,
  createAttendanceCorrection,
  getAttendanceCorrection,
  listAttendanceCorrections,
  updateAttendanceCorrectionStatus,
  type AttendanceCorrectionStatus,
} from "./attendance_correction_repository.ts";
import {
  attendanceSessionToApi,
  AttendanceSessionNotFoundError,
  getAttendanceSession,
  listAttendanceSessions,
} from "./attendance_sessions_repository.ts";

type AuthedClaims = Parameters<typeof requirePermission>[0];

function requireAttendanceRead(
  claims: Parameters<typeof requirePermission>[0],
): Response | null {
  return requirePermission(claims, "viewSis") ??
    requireSchoolOperationalScope(claims);
}

function requireAttendanceWrite(
  claims: Parameters<typeof requirePermission>[0],
): Response | null {
  return requirePermission(claims, "manageSis") ??
    requireSchoolOperationalScope(claims);
}

/** Deciding a correction's status is an approval action — not plain manageSis. */
function requireAttendanceApprove(
  claims: Parameters<typeof requirePermission>[0],
): Response | null {
  return requirePermission(claims, "approveAttendanceCorrection") ??
    requireSchoolOperationalScope(claims);
}

function mapAttendanceError(error: unknown): Response {
  if (error instanceof AttendanceCorrectionNotFoundError) {
    return errorEnvelope("ATTENDANCE_CORRECTION_NOT_FOUND", error.message, 404);
  }
  if (error instanceof AttendanceSessionNotFoundError) {
    return errorEnvelope("ATTENDANCE_SESSION_NOT_FOUND", error.message, 404);
  }
  if (error instanceof AttendanceValidationError) {
    return errorEnvelope("ATTENDANCE_VALIDATION", error.message, 422);
  }
  throw error;
}

async function withAuth<T>(
  req: Request,
  config: AppConfig,
  readOnly: boolean,
  handler: (claims: AuthedClaims) => Promise<T>,
): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;

  const denied = readOnly
    ? requireAttendanceRead(auth.claims)
    : requireAttendanceWrite(auth.claims);
  if (denied) return denied;

  try {
    const result = await handler(auth.claims);
    return jsonResponse(envelope(result));
  } catch (error) {
    if (error instanceof TenantDbNotConfiguredError) {
      return tenantDbNotConfiguredResponse();
    }
    return mapAttendanceError(error);
  }
}

function tenantIds(claims: AuthedClaims) {
  return {
    organizationId: organizationIdFromClaims(claims),
    schoolId: schoolIdFromClaims(claims),
  };
}

export async function handleListAttendanceSessions(
  req: Request,
  config: AppConfig,
): Promise<Response> {
  return await withAuth(req, config, true, async (claims) => {
    const { organizationId, schoolId } = tenantIds(claims);
    const rows = await withTenantContext(config, claims, (db) =>
      listAttendanceSessions(db, organizationId, schoolId)
    );
    return rows.map(attendanceSessionToApi);
  });
}

export async function handleGetAttendanceSession(
  req: Request,
  config: AppConfig,
  sessionId: string,
): Promise<Response> {
  return await withAuth(req, config, true, async (claims) => {
    const { organizationId, schoolId } = tenantIds(claims);
    const row = await withTenantContext(config, claims, (db) =>
      getAttendanceSession(db, organizationId, schoolId, sessionId)
    );
    if (!row) throw new AttendanceSessionNotFoundError(sessionId);
    return attendanceSessionToApi(row);
  });
}

export async function handleListAttendanceCorrections(
  req: Request,
  config: AppConfig,
): Promise<Response> {
  return await withAuth(req, config, true, async (claims) => {
    const url = new URL(req.url);
    const status = url.searchParams.get("status") as AttendanceCorrectionStatus | null;
    const { organizationId, schoolId } = tenantIds(claims);
    const rows = await withTenantContext(config, claims, (db) =>
      listAttendanceCorrections(
        db,
        organizationId,
        schoolId,
        status ?? undefined,
      )
    );
    return rows.map(correctionToApi);
  });
}

export async function handleGetAttendanceCorrection(
  req: Request,
  config: AppConfig,
  correctionId: string,
): Promise<Response> {
  return await withAuth(req, config, true, async (claims) => {
    const { organizationId, schoolId } = tenantIds(claims);
    const row = await withTenantContext(config, claims, (db) =>
      getAttendanceCorrection(db, organizationId, schoolId, correctionId)
    );
    if (!row) {
      throw new AttendanceCorrectionNotFoundError(correctionId);
    }
    return correctionToApi(row);
  });
}

export async function handleCreateAttendanceCorrection(
  req: Request,
  config: AppConfig,
): Promise<Response> {
  return await withAuth(req, config, false, async (claims) => {
    const body = await readJson<Record<string, unknown>>(req);
    if (!body) throw new AttendanceValidationError("JSON body required");

    const sisStudentId = String(body.sisStudentId ?? body.sis_student_id ?? "").trim();
    if (!sisStudentId) {
      throw new AttendanceValidationError("sisStudentId is required");
    }

    const { organizationId, schoolId } = tenantIds(claims);
    const row = await withTenantContext(config, claims, (db) =>
      createAttendanceCorrection(db, organizationId, schoolId, {
        sisStudentId,
        studentName: String(body.studentName ?? body.student_name ?? ""),
        classLabel: String(body.classLabel ?? body.class_label ?? ""),
        section: String(body.section ?? body.section_name ?? ""),
        dateLabel: String(body.dateLabel ?? body.date_label ?? ""),
        fromMark: String(body.fromMark ?? body.from_mark ?? ""),
        toMark: String(body.toMark ?? body.to_mark ?? ""),
        reason: String(body.reason ?? ""),
        requesterId: String(body.requesterId ?? body.requester_id ?? claims.sub),
        requesterName: String(body.requesterName ?? body.requester_name ?? "Requester"),
        requesterRole: String(body.requesterRole ?? body.requester_role ?? "teacher"),
        presentDelta: Number(body.presentDelta ?? body.present_delta ?? 1) || 1,
      })
    );
    return correctionToApi(row);
  });
}

export async function handleUpdateAttendanceCorrectionStatus(
  req: Request,
  config: AppConfig,
  correctionId: string,
): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;
  // Approving/rejecting a correction is a governance decision — gate on the
  // approve permission, not plain manageSis (closes an approval-bypass).
  const denied = requireAttendanceApprove(auth.claims);
  if (denied) return denied;

  const body = await readJson<Record<string, unknown>>(req);
  if (!body) {
    return errorEnvelope("VALIDATION_ERROR", "Request body required", 400);
  }
  const status = String(body.status ?? "").trim() as AttendanceCorrectionStatus;
  if (!status) {
    return errorEnvelope("ATTENDANCE_VALIDATION", "status is required", 422);
  }

  const { organizationId, schoolId } = tenantIds(auth.claims);
  try {
    const row = await withTenantContext(config, auth.claims, (db) =>
      updateAttendanceCorrectionStatus(
        db,
        organizationId,
        schoolId,
        correctionId,
        status,
      )
    );
    return jsonResponse(envelope(correctionToApi(row)));
  } catch (error) {
    if (error instanceof TenantDbNotConfiguredError) {
      return tenantDbNotConfiguredResponse();
    }
    return mapAttendanceError(error);
  }
}
