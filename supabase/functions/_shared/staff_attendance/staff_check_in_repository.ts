// B4 — staff attendance (RE-IMPLEMENTED) repository: geofence config, per-staff
// face enrollment, the geofence+anti-mock+face-match check-in ledger, and the
// audited Manual Attendance Request fallback. All DB access; pure validation/math
// lives in staff_attendance_validation.ts.

import type { TenantQueryClient } from "../tenant_db.ts";
import type { GeofenceConfig, StaffCheckEventType } from "./staff_attendance_validation.ts";
import { StaffAttendanceValidationError } from "./staff_attendance_validation.ts";

export { StaffAttendanceValidationError };

export interface StaffCheckInRow {
  id: string;
  organization_id: string;
  school_id: string;
  user_id: string;
  employee_ref: string | null;
  staff_name: string;
  staff_role: string;
  event_type: string;
  event_time: string;
  method: string;
  geo_latitude: number | null;
  geo_longitude: number | null;
  geo_accuracy_m: number | null;
  distance_m: number | null;
  location_verified: boolean;
  face_match_score: number | null;
  face_matched: boolean;
  capture_ref: string | null;
  created_at: string;
}

// ── Geofence config ──────────────────────────────────────────────────────────
export async function getGeofenceConfig(
  db: TenantQueryClient,
): Promise<GeofenceConfig | null> {
  const rows = await db.queryObject<{
    center_latitude: number;
    center_longitude: number;
    radius_m: number;
    max_accuracy_m: number;
    max_location_age_s: number;
  }>(
    `SELECT center_latitude, center_longitude, radius_m, max_accuracy_m, max_location_age_s
       FROM school_attendance_geofences
      WHERE organization_id = app_current_tenant_id()
        AND school_id = app_current_school_id()
      LIMIT 1`,
  );
  const r = rows[0];
  if (!r) return null;
  return {
    centerLatitude: r.center_latitude,
    centerLongitude: r.center_longitude,
    radiusM: r.radius_m,
    maxAccuracyM: r.max_accuracy_m,
    maxLocationAgeS: r.max_location_age_s,
  };
}

export async function upsertGeofenceConfig(
  db: TenantQueryClient,
  organizationId: string,
  schoolId: string,
  userId: string,
  cfg: GeofenceConfig,
): Promise<GeofenceConfig> {
  await db.queryObject(
    `INSERT INTO school_attendance_geofences (
       organization_id, school_id, center_latitude, center_longitude,
       radius_m, max_accuracy_m, max_location_age_s, updated_by, updated_at
     ) VALUES ($1,$2,$3,$4,$5,$6,$7,$8, timezone('utc', now()))
     ON CONFLICT (organization_id, school_id) DO UPDATE SET
       center_latitude = EXCLUDED.center_latitude,
       center_longitude = EXCLUDED.center_longitude,
       radius_m = EXCLUDED.radius_m,
       max_accuracy_m = EXCLUDED.max_accuracy_m,
       max_location_age_s = EXCLUDED.max_location_age_s,
       updated_by = EXCLUDED.updated_by,
       updated_at = timezone('utc', now())`,
    [
      organizationId,
      schoolId,
      cfg.centerLatitude,
      cfg.centerLongitude,
      cfg.radiusM,
      cfg.maxAccuracyM,
      cfg.maxLocationAgeS,
      userId,
    ],
  );
  return cfg;
}

// ── Face enrollment ──────────────────────────────────────────────────────────
// staff_face_enrollments is the SHARED P1-PROD-22 table owned EXCLUSIVELY by
// _shared/attendance_auth/face_enrollment_repository.ts (migration 20260877
// evolved it from this module's original self-only shape). This module's
// former getActiveEnrollment/enrollFace duplicates were REMOVED in SLICE 2 —
// staff_attendance_handlers.ts now calls the attendance_auth repository
// directly, so there is exactly one write path (revoke-then-insert) and one
// validation bound (64..1024 dims, matching the DB CHECK).

// ── Check-in ledger ──────────────────────────────────────────────────────────
export interface RecordStaffCheckInput {
  userId: string;
  staffName: string;
  staffRole: string;
  employeeRef: string | null;
  eventType: StaffCheckEventType;
  method: string; // 'face_match' | 'manual'
  geoLatitude: number | null;
  geoLongitude: number | null;
  geoAccuracyM: number | null;
  distanceM: number | null;
  mockDetected: boolean;
  locationVerified: boolean;
  livenessPassed: boolean;
  faceMatchScore: number | null;
  faceMatched: boolean;
  captureRef: string | null;
}

export async function recordStaffCheckIn(
  db: TenantQueryClient,
  organizationId: string,
  schoolId: string,
  input: RecordStaffCheckInput,
): Promise<StaffCheckInRow> {
  const id = `staff_chk_${crypto.randomUUID()}`;
  const rows = await db.queryObject<StaffCheckInRow>(
    `INSERT INTO staff_check_ins (
       id, organization_id, school_id, user_id, employee_ref,
       staff_name, staff_role, event_type, method,
       geo_latitude, geo_longitude, geo_accuracy_m, distance_m,
       mock_location_detected, location_verified, liveness_passed,
       face_match_score, face_matched, capture_ref, biometric_verified
     ) VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13,$14,$15,$16,$17,$18,$19, FALSE)
     RETURNING *`,
    [
      id,
      organizationId,
      schoolId,
      input.userId,
      input.employeeRef,
      input.staffName,
      input.staffRole,
      input.eventType,
      input.method,
      input.geoLatitude,
      input.geoLongitude,
      input.geoAccuracyM,
      input.distanceM,
      input.mockDetected,
      input.locationVerified,
      input.livenessPassed,
      input.faceMatchScore,
      input.faceMatched,
      input.captureRef,
    ],
  );
  return rows[0]!;
}

export function staffCheckInToApi(row: StaffCheckInRow) {
  return {
    id: row.id,
    eventType: row.event_type,
    eventTime: row.event_time,
    method: row.method,
    staffName: row.staff_name,
    staffRole: row.staff_role,
    locationVerified: row.location_verified,
    distanceM: row.distance_m,
    faceMatched: row.face_matched,
    faceMatchScore: row.face_match_score,
  };
}

// ── Manual attendance request (GA-2) ─────────────────────────────────────────
export interface AttendanceRequestRow {
  id: string;
  user_id: string;
  staff_name: string;
  event_type: string;
  reason: string;
  status: string;
  decided_by: string | null;
  decided_at: string | null;
  resulting_check_in_id: string | null;
  created_at: string;
}

export async function createAttendanceRequest(
  db: TenantQueryClient,
  organizationId: string,
  schoolId: string,
  input: { userId: string; staffName: string; eventType: StaffCheckEventType; reason: string },
): Promise<AttendanceRequestRow> {
  const id = `att_req_${crypto.randomUUID()}`;
  const rows = await db.queryObject<AttendanceRequestRow>(
    `INSERT INTO staff_attendance_requests (
       id, organization_id, school_id, user_id, staff_name, event_type, reason, status
     ) VALUES ($1,$2,$3,$4,$5,$6,$7,'pending')
     RETURNING *`,
    [id, organizationId, schoolId, input.userId, input.staffName, input.eventType, input.reason],
  );
  return rows[0]!;
}

/** SLICE 4 — the caller's OWN recent requests (staff self-service; the
 * userId is ALWAYS the JWT subject at the handler, never a request param). */
export interface MyAttendanceRequestRow {
  id: string;
  event_type: string;
  reason: string;
  status: string;
  created_at: string;
  decided_at: string | null;
}

export async function listMyAttendanceRequests(
  db: TenantQueryClient,
  organizationId: string,
  schoolId: string,
  userId: string,
): Promise<MyAttendanceRequestRow[]> {
  return await db.queryObject<MyAttendanceRequestRow>(
    `SELECT id, event_type, reason, status, created_at, decided_at
       FROM staff_attendance_requests
      WHERE organization_id = $1 AND school_id = $2 AND user_id = $3
      ORDER BY created_at DESC
      LIMIT 20`,
    [organizationId, schoolId, userId],
  );
}

/** SLICE 4 — the school's PENDING queue for approvers (uses
 * idx_attendance_requests_school_status; limit clamped at the handler). */
export interface PendingAttendanceRequestRow {
  id: string;
  user_id: string;
  staff_name: string;
  event_type: string;
  reason: string;
  created_at: string;
}

export async function listPendingAttendanceRequests(
  db: TenantQueryClient,
  organizationId: string,
  schoolId: string,
  limit: number,
): Promise<PendingAttendanceRequestRow[]> {
  return await db.queryObject<PendingAttendanceRequestRow>(
    `SELECT id, user_id, staff_name, event_type, reason, created_at
       FROM staff_attendance_requests
      WHERE organization_id = $1 AND school_id = $2 AND status = 'pending'
      ORDER BY created_at DESC
      LIMIT $3`,
    [organizationId, schoolId, limit],
  );
}

export async function decideAttendanceRequest(
  db: TenantQueryClient,
  organizationId: string,
  schoolId: string,
  requestId: string,
  approverId: string,
  approve: boolean,
): Promise<{ request: AttendanceRequestRow; checkIn: StaffCheckInRow | null }> {
  const pending = await db.queryObject<AttendanceRequestRow>(
    `SELECT * FROM staff_attendance_requests
      WHERE organization_id = app_current_tenant_id()
        AND school_id = app_current_school_id()
        AND id = $1 AND status = 'pending'
      LIMIT 1`,
    [requestId],
  );
  const reqRow = pending[0];
  if (!reqRow) {
    throw new StaffAttendanceValidationError("REQUEST_NOT_FOUND", "No pending request with that id");
  }
  // SoD (audit R4, mirroring HR-3 leave / owner decision 2026-07-06): the
  // requester can never decide their own request — a supervisory user holds
  // markStaffAttendance too, and self-approval would let them certify their
  // own attendance with zero independent verification, defeating the whole
  // geofence+face chain. Same auth `sub` identity space; no mapping needed.
  if (approverId !== "" && reqRow.user_id === approverId) {
    throw new StaffAttendanceValidationError(
      "SELF_APPROVE_DENIED",
      "You cannot approve or reject your own attendance request",
    );
  }

  // Claim the decision FIRST, guarded on status='pending' (audit R4 race fix):
  // two approvers deciding concurrently both pass the SELECT above, but only
  // the first one's UPDATE matches — the loser gets zero rows back and a typed
  // conflict, and crucially never reaches the check-in INSERT (no duplicate
  // ledger rows). Mirrors LEAVE_ALREADY_DECIDED.
  const claimed = await db.queryObject<AttendanceRequestRow>(
    `UPDATE staff_attendance_requests
        SET status = $2, decided_by = $3, decided_at = timezone('utc', now())
      WHERE organization_id = app_current_tenant_id()
        AND school_id = app_current_school_id()
        AND id = $1 AND status = 'pending'
      RETURNING *`,
    [requestId, approve ? "approved" : "rejected", approverId],
  );
  let decided = claimed[0];
  if (!decided) {
    throw new StaffAttendanceValidationError(
      "REQUEST_ALREADY_DECIDED",
      "This request was already decided by another approver",
    );
  }

  let checkIn: StaffCheckInRow | null = null;
  if (approve) {
    checkIn = await recordStaffCheckIn(db, organizationId, schoolId, {
      userId: reqRow.user_id,
      staffName: reqRow.staff_name,
      staffRole: "",
      employeeRef: null,
      eventType: reqRow.event_type as StaffCheckEventType,
      method: "manual",
      geoLatitude: null,
      geoLongitude: null,
      geoAccuracyM: null,
      distanceM: null,
      mockDetected: false,
      locationVerified: false,
      livenessPassed: false,
      faceMatchScore: null,
      faceMatched: false,
      captureRef: null,
    });
    const linked = await db.queryObject<AttendanceRequestRow>(
      `UPDATE staff_attendance_requests
          SET resulting_check_in_id = $2
        WHERE organization_id = app_current_tenant_id()
          AND school_id = app_current_school_id()
          AND id = $1
        RETURNING *`,
      [requestId, checkIn.id],
    );
    decided = linked[0] ?? decided;
  }

  return { request: decided, checkIn };
}
