import type { TenantQueryClient } from "../tenant_db.ts";
import { resolveStudentId } from "../sis/sis_student_resolver.ts";

export type AttendanceCorrectionStatus =
  | "pending"
  | "approved"
  | "rejected"
  | "cancelled";

export interface AttendanceCorrectionRow {
  id: string;
  organization_id: string;
  school_id: string;
  sis_student_id: string;
  student_id: string | null;
  student_name: string;
  class_label: string;
  section_name: string;
  date_label: string;
  session_date: string | null;
  from_mark: string;
  to_mark: string;
  reason: string;
  requester_id: string;
  requester_name: string;
  requester_role: string;
  present_delta: number;
  status: AttendanceCorrectionStatus;
  created_at: string;
  updated_at: string;
}

export class AttendanceCorrectionNotFoundError extends Error {
  constructor(id: string) {
    super(`Attendance correction not found: ${id}`);
    this.name = "AttendanceCorrectionNotFoundError";
  }
}

export class AttendanceValidationError extends Error {
  constructor(message: string) {
    super(message);
    this.name = "AttendanceValidationError";
  }
}

function markToDb(value: string): string {
  const normalized = value.trim().toLowerCase();
  if (normalized === "present" || normalized === "absent" || normalized === "late") {
    return normalized;
  }
  if (normalized === "excused") return "excused";
  return "present";
}

export function correctionToApi(row: AttendanceCorrectionRow): Record<string, unknown> {
  return {
    id: row.id,
    sisStudentId: row.sis_student_id,
    studentName: row.student_name,
    classLabel: row.class_label,
    section: row.section_name,
    dateLabel: row.date_label,
    fromMark: capitalizeMark(row.from_mark),
    toMark: capitalizeMark(row.to_mark),
    reason: row.reason,
    requesterId: row.requester_id,
    requesterName: row.requester_name,
    requesterRole: row.requester_role,
    presentDelta: row.present_delta,
    status: row.status,
    requestedAt: row.created_at,
    studentsAffected: 1,
  };
}

function capitalizeMark(mark: string): string {
  const value = mark.trim().toLowerCase();
  if (!value) return mark;
  return value.charAt(0).toUpperCase() + value.slice(1);
}

export interface CreateAttendanceCorrectionInput {
  sisStudentId: string;
  studentName: string;
  classLabel: string;
  section: string;
  dateLabel: string;
  fromMark: string;
  toMark: string;
  reason: string;
  requesterId: string;
  requesterName: string;
  requesterRole: string;
  presentDelta?: number;
}

export async function listAttendanceCorrections(
  db: TenantQueryClient,
  organizationId: string,
  schoolId: string,
  status?: AttendanceCorrectionStatus,
): Promise<AttendanceCorrectionRow[]> {
  const args: unknown[] = [organizationId, schoolId];
  let sql = `SELECT * FROM attendance_corrections
             WHERE organization_id = $1 AND school_id = $2`;
  if (status) {
    sql += ` AND status = $3`;
    args.push(status);
  }
  sql += ` ORDER BY created_at DESC`;
  return await db.queryObject<AttendanceCorrectionRow>(sql, args);
}

export async function getAttendanceCorrection(
  db: TenantQueryClient,
  organizationId: string,
  schoolId: string,
  correctionId: string,
): Promise<AttendanceCorrectionRow | null> {
  const rows = await db.queryObject<AttendanceCorrectionRow>(
    `SELECT * FROM attendance_corrections
     WHERE organization_id = $1 AND school_id = $2 AND id = $3`,
    [organizationId, schoolId, correctionId],
  );
  return rows[0] ?? null;
}

export async function createAttendanceCorrection(
  db: TenantQueryClient,
  organizationId: string,
  schoolId: string,
  input: CreateAttendanceCorrectionInput,
): Promise<AttendanceCorrectionRow> {
  const countRows = await db.queryObject<{ count: string }>(
    `SELECT count(*)::text AS count FROM attendance_corrections
     WHERE organization_id = $1 AND school_id = $2`,
    [organizationId, schoolId],
  );
  const next = (parseInt(countRows[0]?.count ?? "0", 10) || 0) + 1;
  const id = `att_corr_${next}`;

  const studentId = await resolveStudentId(
    db,
    organizationId,
    schoolId,
    input.sisStudentId,
  );

  const rows = await db.queryObject<AttendanceCorrectionRow>(
    `INSERT INTO attendance_corrections (
       id, organization_id, school_id, sis_student_id, student_id, student_name,
       class_label, section_name, date_label, from_mark, to_mark, reason,
       requester_id, requester_name, requester_role, present_delta, status
     ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14, $15, $16, 'pending')
     RETURNING *`,
    [
      id,
      organizationId,
      schoolId,
      input.sisStudentId,
      studentId,
      input.studentName,
      input.classLabel,
      input.section,
      input.dateLabel,
      markToDb(input.fromMark),
      markToDb(input.toMark),
      input.reason,
      input.requesterId,
      input.requesterName,
      input.requesterRole,
      input.presentDelta ?? 1,
    ],
  );
  return rows[0]!;
}

export async function updateAttendanceCorrectionStatus(
  db: TenantQueryClient,
  organizationId: string,
  schoolId: string,
  correctionId: string,
  status: AttendanceCorrectionStatus,
): Promise<AttendanceCorrectionRow> {
  const rows = await db.queryObject<AttendanceCorrectionRow>(
    `UPDATE attendance_corrections
     SET status = $4, updated_at = timezone('utc', now())
     WHERE organization_id = $1 AND school_id = $2 AND id = $3
     RETURNING *`,
    [organizationId, schoolId, correctionId, status],
  );
  const row = rows[0];
  if (!row) throw new AttendanceCorrectionNotFoundError(correctionId);
  return row;
}

export async function applyAttendanceCorrection(
  db: TenantQueryClient,
  organizationId: string,
  schoolId: string,
  correctionId: string,
): Promise<AttendanceCorrectionRow> {
  const correction = await getAttendanceCorrection(
    db,
    organizationId,
    schoolId,
    correctionId,
  );
  if (!correction) throw new AttendanceCorrectionNotFoundError(correctionId);
  if (correction.status === "approved") return correction;

  if (!correction.student_id) {
    throw new Error(`Student not resolved for correction ${correctionId}`);
  }

  const targetMark = markToDb(correction.to_mark);
  const classLabel = correction.section_name
    ? `${correction.class_label}-${correction.section_name}`
    : correction.class_label;

  await db.queryObject(
    `UPDATE attendance_records ar
     SET mark = $5
     FROM attendance_sessions s
     WHERE ar.session_id = s.id
       AND ar.organization_id = $1
       AND ar.school_id = $2
       AND ar.student_id = $3::uuid
       AND s.class_label = $4
       AND s.status = 'submitted'
       AND s.session_date = (
         SELECT COALESCE(ac.session_date, CURRENT_DATE)
         FROM attendance_corrections ac
         WHERE ac.organization_id = $1 AND ac.school_id = $2 AND ac.id = $6
       )`,
    [
      organizationId,
      schoolId,
      correction.student_id,
      classLabel,
      targetMark,
      correctionId,
    ],
  );

  return await updateAttendanceCorrectionStatus(
    db,
    organizationId,
    schoolId,
    correctionId,
    "approved",
  );
}
