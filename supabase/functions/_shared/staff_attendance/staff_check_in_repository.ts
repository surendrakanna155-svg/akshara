// Staff Face ID attendance — append-only check-in/out ledger repository.
// The acting employee is the JWT subject (anti-buddy-punching); the body carries
// only the event + the biometric method. HARD-BLOCK: a non-biometric-verified
// event is rejected (there is no PIN fallback).

import type { TenantQueryClient } from "../tenant_db.ts";

export type StaffCheckEventType = "check_in" | "check_out";

const EVENT_TYPES: readonly StaffCheckEventType[] = ["check_in", "check_out"];

export class StaffAttendanceValidationError extends Error {
  constructor(message: string) {
    super(message);
    this.name = "StaffAttendanceValidationError";
  }
}

export interface RecordStaffCheckInput {
  userId: string;
  staffName: string;
  staffRole: string;
  employeeRef: string | null;
  eventType: StaffCheckEventType;
  method: string;
  biometricVerified: boolean;
}

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
  biometric_verified: boolean;
  created_at: string;
}

/** Parses + validates the request body into the persisted-input shape. */
export function parseStaffCheckBody(
  body: Record<string, unknown> | null,
): { eventType: StaffCheckEventType; method: string; biometricVerified: boolean; staffName: string; employeeRef: string | null } {
  if (!body) throw new StaffAttendanceValidationError("JSON body required");

  const eventTypeRaw = String(body.eventType ?? body.event_type ?? "").trim();
  if (!EVENT_TYPES.includes(eventTypeRaw as StaffCheckEventType)) {
    throw new StaffAttendanceValidationError(
      `eventType must be one of ${EVENT_TYPES.join(", ")}`,
    );
  }

  // HARD-BLOCK: the client only sends a check-in AFTER a successful real
  // biometric. A request that does not assert biometric verification is refused
  // (no device-credential / PIN fallback exists for staff check-in).
  const biometricVerified = body.biometricVerified === true ||
    body.biometric_verified === true;
  if (!biometricVerified) {
    throw new StaffAttendanceValidationError(
      "Biometric verification is required for staff check-in (no PIN fallback)",
    );
  }

  const method = String(body.method ?? "biometric").trim() || "biometric";

  return {
    eventType: eventTypeRaw as StaffCheckEventType,
    method,
    biometricVerified,
    staffName: String(body.staffName ?? body.staff_name ?? "").trim(),
    employeeRef: body.employeeRef != null || body.employee_ref != null
      ? String(body.employeeRef ?? body.employee_ref).trim()
      : null,
  };
}

export async function recordStaffCheckIn(
  db: TenantQueryClient,
  organizationId: string,
  schoolId: string,
  input: RecordStaffCheckInput,
): Promise<StaffCheckInRow> {
  if (!input.biometricVerified) {
    throw new StaffAttendanceValidationError(
      "Biometric verification is required for staff check-in (no PIN fallback)",
    );
  }
  if (!EVENT_TYPES.includes(input.eventType)) {
    throw new StaffAttendanceValidationError(`Invalid event_type: ${input.eventType}`);
  }

  const id = `staff_chk_${crypto.randomUUID()}`;
  const rows = await db.queryObject<StaffCheckInRow>(
    `INSERT INTO staff_check_ins (
       id, organization_id, school_id, user_id, employee_ref,
       staff_name, staff_role, event_type, method, biometric_verified
     ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10)
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
      input.biometricVerified,
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
    biometricVerified: row.biometric_verified,
    staffName: row.staff_name,
    staffRole: row.staff_role,
  };
}
