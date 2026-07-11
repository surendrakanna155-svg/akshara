// B4 — staff attendance (RE-IMPLEMENTED) write handlers.
// Attendance auth per docs/ATTENDANCE_AUTH_DESIGN_DECISION.md (FINAL):
//   GPS geofence -> anti-mock/high-accuracy/anti-stale -> live camera face
//   (server-authoritative CV match vs enrolled reference). NO device biometric.
// The acting employee is always the JWT subject (anti-buddy-punching). Every
// mutation emits a server audit.

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
  createAttendanceRequest,
  decideAttendanceRequest,
  getGeofenceConfig,
  recordStaffCheckIn,
  StaffAttendanceValidationError,
  staffCheckInToApi,
  upsertGeofenceConfig,
} from "./staff_check_in_repository.ts";
import {
  enrollFace,
  FaceEnrollmentValidationError,
  getActiveEnrollment,
} from "../attendance_auth/face_enrollment_repository.ts";
import {
  parseStaffCheckBody,
  validateLocation,
  verifyFace,
  type GeofenceConfig,
  type StaffCheckEventType,
} from "./staff_attendance_validation.ts";
import {
  buildMyAttendanceHistory,
  loadMyApprovedOverrideDates,
  loadMyCheckInEvents,
} from "./staff_attendance_my_history.ts";
import { DEFAULT_LATE_AFTER, loadHolidayDays } from "../hr/hr_reports_repository.ts";

type AuthedClaims = Parameters<typeof requirePermission>[0];

function requireMark(claims: AuthedClaims): Response | null {
  return requirePermission(claims, "markStaffAttendance") ??
    requireSchoolOperationalScope(claims);
}

function requireApprove(claims: AuthedClaims): Response | null {
  return requirePermission(claims, "approveStaffAttendance") ??
    requireSchoolOperationalScope(claims);
}

function requireGeofenceAdmin(claims: AuthedClaims): Response | null {
  return requirePermission(claims, "manageSchoolGeofence") ??
    requireSchoolOperationalScope(claims);
}

function subjectOf(claims: unknown): string {
  return String((claims as { sub?: string }).sub ?? "");
}

function roleOf(claims: unknown): string {
  return String(
    (claims as { primary_role?: string; role?: string }).primary_role ??
      (claims as { role?: string }).role ?? "",
  );
}

function validationResponse(e: StaffAttendanceValidationError): Response {
  return errorEnvelope(`STAFF_ATTENDANCE_${e.code}`, e.message, 422);
}

// ── POST /staff-attendance/check ─────────────────────────────────────────────
export async function handleRecordStaffCheckIn(
  req: Request,
  config: AppConfig,
): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;
  const denied = requireMark(auth.claims);
  if (denied) return denied;

  try {
    const parsed = parseStaffCheckBody(await readJson<Record<string, unknown>>(req));
    const claims = auth.claims;
    const organizationId = organizationIdFromClaims(claims);
    const schoolId = schoolIdFromClaims(claims);
    const userId = subjectOf(claims);
    const nowMs = Date.now();

    const row = await withTenantContext(config, claims, async (db) => {
      // 1. Geofence must be configured by the school before any check-in.
      const cfg = await getGeofenceConfig(db);
      if (!cfg) {
        throw new StaffAttendanceValidationError(
          "GEOFENCE_NOT_CONFIGURED",
          "The school attendance geofence is not configured yet — ask an admin to set it",
        );
      }
      // 2. Location: anti-mock -> accuracy -> freshness -> inside-geofence.
      const loc = validateLocation(parsed.location, cfg, nowMs);
      // 3. Face: liveness + server-side CV match vs the enrolled reference.
      const reference = await getActiveEnrollment(
        db,
        { organizationId, schoolId },
        userId,
      );
      if (!reference) {
        throw new StaffAttendanceValidationError(
          "FACE_NOT_ENROLLED",
          "No enrolled reference face — enrol your face before recording attendance",
        );
      }
      const face = verifyFace(parsed.face, reference);

      const inserted = await recordStaffCheckIn(db, organizationId, schoolId, {
        userId,
        staffName: parsed.staffName,
        staffRole: roleOf(claims),
        employeeRef: parsed.employeeRef,
        eventType: parsed.eventType,
        method: "face_match",
        geoLatitude: parsed.location.latitude,
        geoLongitude: parsed.location.longitude,
        geoAccuracyM: parsed.location.accuracyM,
        distanceM: loc.distanceM,
        mockDetected: false,
        locationVerified: true,
        livenessPassed: true,
        faceMatchScore: face.score,
        faceMatched: true,
        captureRef: parsed.face.captureRef,
      });

      const spec = parsed.eventType === "check_in"
        ? staffAttendanceAudit.checkInRecorded(inserted.id, inserted.user_id, "face_match")
        : staffAttendanceAudit.checkOutRecorded(inserted.id, inserted.user_id, "face_match");
      await recordMutationAudit(db, claims, spec.audit, spec.domain, req);
      return inserted;
    });

    return jsonResponse(envelope(staffCheckInToApi(row)));
  } catch (error) {
    if (error instanceof TenantDbNotConfiguredError) return tenantDbNotConfiguredResponse();
    if (error instanceof StaffAttendanceValidationError) return validationResponse(error);
    throw error;
  }
}

// ── POST /staff-attendance/enroll-face ───────────────────────────────────────
// Self-service twin of POST /attendance-auth/face/enroll: same governed write
// path (attendance_auth repository — one validation bound, one revoke-then-
// insert), kept at this route for the staff self-enrolment client flow.
export async function handleEnrollFace(req: Request, config: AppConfig): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;
  const denied = requireMark(auth.claims);
  if (denied) return denied;

  try {
    const body = await readJson<Record<string, unknown>>(req);
    const claims = auth.claims;
    const organizationId = organizationIdFromClaims(claims);
    const schoolId = schoolIdFromClaims(claims);
    const userId = subjectOf(claims);

    const result = await withTenantContext(config, claims, async (db) => {
      const enr = await enrollFace(db, { organizationId, schoolId }, {
        userId,
        embedding: body?.embedding,
        modelTag: String(body?.modelTag ?? body?.model_tag ?? "").trim(),
        enrolledBy: userId,
      });
      const spec = staffAttendanceAudit.faceEnrolled(enr.id, userId);
      await recordMutationAudit(db, claims, spec.audit, spec.domain, req);
      return enr;
    });
    return jsonResponse(envelope({
      id: result.id,
      embeddingDim: result.embeddingDims,
      modelTag: result.modelTag,
      enrolledAt: result.createdAt,
    }));
  } catch (error) {
    if (error instanceof TenantDbNotConfiguredError) return tenantDbNotConfiguredResponse();
    if (error instanceof StaffAttendanceValidationError) return validationResponse(error);
    if (error instanceof FaceEnrollmentValidationError) {
      return errorEnvelope(`STAFF_ATTENDANCE_${error.code}`, error.message, 422);
    }
    throw error;
  }
}

// ── GET /staff-attendance/geofence ───────────────────────────────────────────
export async function handleGetGeofence(req: Request, config: AppConfig): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;
  const denied = requireMark(auth.claims);
  if (denied) return denied;
  try {
    const cfg = await withTenantContext(config, auth.claims, (db) => getGeofenceConfig(db));
    if (!cfg) return errorEnvelope("STAFF_ATTENDANCE_GEOFENCE_NOT_CONFIGURED", "Not configured", 404);
    return jsonResponse(envelope(cfg));
  } catch (error) {
    if (error instanceof TenantDbNotConfiguredError) return tenantDbNotConfiguredResponse();
    throw error;
  }
}

// ── PUT /staff-attendance/geofence ───────────────────────────────────────────
function parseGeofenceBody(body: Record<string, unknown> | null): GeofenceConfig {
  if (!body) throw new StaffAttendanceValidationError("GEOFENCE_INVALID", "JSON body required");
  const lat = Number(body.centerLatitude ?? body.center_latitude);
  const lng = Number(body.centerLongitude ?? body.center_longitude);
  const radius = Math.round(Number(body.radiusM ?? body.radius_m ?? 100));
  const acc = Math.round(Number(body.maxAccuracyM ?? body.max_accuracy_m ?? 50));
  const age = Math.round(Number(body.maxLocationAgeS ?? body.max_location_age_s ?? 60));
  if (!Number.isFinite(lat) || lat < -90 || lat > 90 ||
      !Number.isFinite(lng) || lng < -180 || lng > 180) {
    throw new StaffAttendanceValidationError("GEOFENCE_INVALID", "Valid centre lat/lng required");
  }
  if (!(radius >= 25 && radius <= 1000)) {
    throw new StaffAttendanceValidationError("GEOFENCE_INVALID", "radiusM must be 25..1000");
  }
  if (!(acc >= 5 && acc <= 200)) {
    throw new StaffAttendanceValidationError("GEOFENCE_INVALID", "maxAccuracyM must be 5..200");
  }
  return {
    centerLatitude: lat,
    centerLongitude: lng,
    radiusM: radius,
    maxAccuracyM: acc,
    maxLocationAgeS: age >= 10 && age <= 600 ? age : 60,
  };
}

export async function handleSetGeofence(req: Request, config: AppConfig): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;
  const denied = requireGeofenceAdmin(auth.claims);
  if (denied) return denied;
  try {
    const cfg = parseGeofenceBody(await readJson<Record<string, unknown>>(req));
    const claims = auth.claims;
    const organizationId = organizationIdFromClaims(claims);
    const schoolId = schoolIdFromClaims(claims);
    const saved = await withTenantContext(config, claims, async (db) => {
      const out = await upsertGeofenceConfig(db, organizationId, schoolId, subjectOf(claims), cfg);
      const spec = staffAttendanceAudit.geofenceConfigured(schoolId, cfg.radiusM);
      await recordMutationAudit(db, claims, spec.audit, spec.domain, req);
      return out;
    });
    return jsonResponse(envelope(saved));
  } catch (error) {
    if (error instanceof TenantDbNotConfiguredError) return tenantDbNotConfiguredResponse();
    if (error instanceof StaffAttendanceValidationError) return validationResponse(error);
    throw error;
  }
}

// ── GET /staff-attendance/my-history ─────────────────────────────────────────
// TCH-9 "My Attendance" (P1): READ-ONLY staff SELF-SERVICE history —
// Today / Yesterday / This-Month check-in/out times, working minutes, late
// days and manual overrides. Gated exactly like the self-service check route
// (markStaffAttendance is universal for staff; parents/students never carry
// it). SELF-SCOPING IS DOUBLE-ENFORCED: the user id is ALWAYS the JWT subject
// (claims.sub — never a request parameter), and RLS policy
// staff_check_ins_self_read (migration 20260841000000) pins visibility to
// app_current_user_id(). No write path, no state change, no audit mutation.

const MY_HISTORY_MONTH_RE = /^\d{4}-(0[1-9]|1[0-2])$/;

export async function handleMyAttendanceHistory(
  req: Request,
  config: AppConfig,
): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;
  // Same universal self-service gate as POST /staff-attendance/check.
  const denied = requireMark(auth.claims);
  if (denied) return denied;

  const url = new URL(req.url);
  const nowIso = new Date().toISOString();
  const month = url.searchParams.get("month")?.trim() || nowIso.slice(0, 7);
  if (!MY_HISTORY_MONTH_RE.test(month)) {
    return errorEnvelope("BAD_REQUEST", "month query parameter must be YYYY-MM", 400);
  }
  // Late cutoff: the shared HR default (09:15); ?lateAfter=HH:MM override
  // mirrors GET /hr/attendance/muster so the two views agree.
  const lateAfter = url.searchParams.get("lateAfter")?.trim() || DEFAULT_LATE_AFTER;

  const claims = auth.claims;
  const organizationId = organizationIdFromClaims(claims);
  const schoolId = schoolIdFromClaims(claims);
  // The subject comes from the verified JWT — NEVER from the request.
  const userId = subjectOf(claims);

  try {
    const history = await withTenantContext(config, claims, async (db) => {
      const [events, holidayDays, overrideDates] = await Promise.all([
        loadMyCheckInEvents(db, organizationId, schoolId, userId, month),
        loadHolidayDays(db, organizationId, schoolId, month),
        loadMyApprovedOverrideDates(db, organizationId, schoolId, userId, month),
      ]);
      return buildMyAttendanceHistory(month, events, {
        lateAfter,
        holidayDays,
        overrideDates,
        asOf: nowIso.slice(0, 10),
      });
    });
    return jsonResponse(envelope(history));
  } catch (error) {
    if (error instanceof TenantDbNotConfiguredError) return tenantDbNotConfiguredResponse();
    throw error;
  }
}

// ── POST /staff-attendance/manual-request ────────────────────────────────────
export async function handleCreateManualRequest(req: Request, config: AppConfig): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;
  const denied = requireMark(auth.claims);
  if (denied) return denied;
  try {
    const body = await readJson<Record<string, unknown>>(req);
    const eventType = String(body?.eventType ?? body?.event_type ?? "").trim();
    if (eventType !== "check_in" && eventType !== "check_out") {
      throw new StaffAttendanceValidationError("INVALID_EVENT_TYPE", "eventType must be check_in|check_out");
    }
    const reason = String(body?.reason ?? "").trim();
    if (reason.length < 3) {
      throw new StaffAttendanceValidationError("REASON_REQUIRED", "A reason is required for a manual request");
    }
    const claims = auth.claims;
    const organizationId = organizationIdFromClaims(claims);
    const schoolId = schoolIdFromClaims(claims);
    const row = await withTenantContext(config, claims, async (db) => {
      const created = await createAttendanceRequest(db, organizationId, schoolId, {
        userId: subjectOf(claims),
        staffName: String(body?.staffName ?? body?.staff_name ?? "").trim(),
        eventType: eventType as StaffCheckEventType,
        reason,
      });
      const spec = staffAttendanceAudit.manualRequestCreated(created.id, created.user_id, eventType);
      await recordMutationAudit(db, claims, spec.audit, spec.domain, req);
      return created;
    });
    return jsonResponse(envelope({ id: row.id, status: row.status, eventType: row.event_type }));
  } catch (error) {
    if (error instanceof TenantDbNotConfiguredError) return tenantDbNotConfiguredResponse();
    if (error instanceof StaffAttendanceValidationError) return validationResponse(error);
    throw error;
  }
}

// ── POST /staff-attendance/manual-request/decide ─────────────────────────────
export async function handleDecideManualRequest(req: Request, config: AppConfig): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;
  const denied = requireApprove(auth.claims);
  if (denied) return denied;
  try {
    const body = await readJson<Record<string, unknown>>(req);
    const requestId = String(body?.requestId ?? body?.request_id ?? "").trim();
    if (!requestId) {
      throw new StaffAttendanceValidationError("REQUEST_ID_REQUIRED", "requestId is required");
    }
    const approve = body?.approve === true || body?.approved === true;
    const claims = auth.claims;
    const organizationId = organizationIdFromClaims(claims);
    const schoolId = schoolIdFromClaims(claims);
    const result = await withTenantContext(config, claims, async (db) => {
      const out = await decideAttendanceRequest(
        db, organizationId, schoolId, requestId, subjectOf(claims), approve,
      );
      const spec = staffAttendanceAudit.manualRequestDecided(requestId, subjectOf(claims), out.request.status);
      await recordMutationAudit(db, claims, spec.audit, spec.domain, req);
      return out;
    });
    return jsonResponse(envelope({
      id: result.request.id,
      status: result.request.status,
      checkInId: result.checkIn?.id ?? null,
    }));
  } catch (error) {
    if (error instanceof TenantDbNotConfiguredError) return tenantDbNotConfiguredResponse();
    if (error instanceof StaffAttendanceValidationError) return validationResponse(error);
    throw error;
  }
}
