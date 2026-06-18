import type { TenantQueryClient } from "../tenant_db.ts";

export interface AttendanceSessionRow {
  id: string;
  organization_id: string;
  school_id: string;
  class_label: string;
  session_date: string;
  taken_by: string;
  status: string;
  created_at: string;
  updated_at: string;
  record_count?: number;
}

export function attendanceSessionToApi(
  row: AttendanceSessionRow,
): Record<string, unknown> {
  return {
    id: row.id,
    classLabel: row.class_label,
    sessionDate: row.session_date,
    takenBy: row.taken_by,
    status: row.status,
    recordCount: row.record_count ?? 0,
    createdAt: row.created_at,
    updatedAt: row.updated_at,
  };
}

export class AttendanceSessionNotFoundError extends Error {
  constructor(id: string) {
    super(`Attendance session not found: ${id}`);
    this.name = "AttendanceSessionNotFoundError";
  }
}

export async function listAttendanceSessions(
  db: TenantQueryClient,
  organizationId: string,
  schoolId: string,
): Promise<AttendanceSessionRow[]> {
  return await db.queryObject<AttendanceSessionRow>(
    `SELECT s.*, count(ar.id)::int AS record_count
     FROM attendance_sessions s
     LEFT JOIN attendance_records ar ON ar.session_id = s.id
     WHERE s.organization_id = $1 AND s.school_id = $2
     GROUP BY s.id
     ORDER BY s.session_date DESC, s.updated_at DESC`,
    [organizationId, schoolId],
  );
}

export async function getAttendanceSession(
  db: TenantQueryClient,
  organizationId: string,
  schoolId: string,
  sessionId: string,
): Promise<AttendanceSessionRow | null> {
  const rows = await db.queryObject<AttendanceSessionRow>(
    `SELECT s.*, count(ar.id)::int AS record_count
     FROM attendance_sessions s
     LEFT JOIN attendance_records ar ON ar.session_id = s.id
     WHERE s.organization_id = $1 AND s.school_id = $2 AND s.id = $3::uuid
     GROUP BY s.id`,
    [organizationId, schoolId, sessionId],
  );
  return rows[0] ?? null;
}
