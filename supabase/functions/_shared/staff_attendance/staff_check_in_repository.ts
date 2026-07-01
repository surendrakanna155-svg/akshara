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
export async function getActiveEnrollment(
  db: TenantQueryClient,
  userId: string,
): Promise<number[] | null> {
  const rows = await db.queryObject<{ embedding: number[] }>(
    `SELECT embedding
       FROM staff_face_enrollments
      WHERE organization_id = app_current_tenant_id()
        AND school_id = app_current_school_id()
        AND user_id = $1
        AND active = TRUE
      LIMIT 1`,
    [userId],
  );
  const r = rows[0];
  if (!r) return null;
  // embedding is stored as JSONB (array of numbers); the driver returns it parsed.
  return Array.isArray(r.embedding) ? r.embedding.map(Number) : null;
}

export async function enrollFace(
  db: TenantQueryClient,
  organizationId: string,
  schoolId: string,
  userId: string,
  embedding: number[],
): Promise<{ id: string; embeddingDim: number; enrolledAt: string }> {
  // Replace: deactivate any prior active enrollment, then insert the new one.
  await db.queryObject(
    `UPDATE staff_face_enrollments SET active = FALSE
      WHERE organization_id = app_current_tenant_id()
        AND school_id = app_current_school_id()
        AND user_id = $1 AND active = TRUE`,
    [userId],
  );
  const id = `face_enr_${crypto.randomUUID()}`;
  const rows = await db.queryObject<{ enrolled_at: string }>(
    `INSERT INTO staff_face_enrollments (
       id, organization_id, school_id, user_id, embedding, embedding_dim, active
     ) VALUES ($1,$2,$3,$4,$5::jsonb,$6, TRUE)
     RETURNING enrolled_at`,
    [id, organizationId, schoolId, userId, JSON.stringify(embedding), embedding.length],
  );
  return { id, embeddingDim: embedding.length, enrolledAt: rows[0]!.enrolled_at };
}

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

  let checkIn: StaffCheckInRow | null = null;
  let resultingId: string | null = null;
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
    resultingId = checkIn.id;
  }

  const updated = await db.queryObject<AttendanceRequestRow>(
    `UPDATE staff_attendance_requests
        SET status = $2, decided_by = $3, decided_at = timezone('utc', now()),
            resulting_check_in_id = $4
      WHERE organization_id = app_current_tenant_id()
        AND school_id = app_current_school_id()
        AND id = $1
      RETURNING *`,
    [requestId, approve ? "approved" : "rejected", approverId, resultingId],
  );
  return { request: updated[0]!, checkIn };
}
