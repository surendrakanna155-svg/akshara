// W4 Staff Duty — repository for the three DEDICATED staff-duty tables (Owner
// decision #6). Each table is its own typed model; NONE reference attendance.
//
//   staff_substitute_classes         → cap 131 (substitution burden)
//   staff_exam_invigilation_duties   → cap 133 (exam & event duties)
//   staff_non_teaching_duties        → cap 132 (non-teaching duties)
//
// Every query is explicitly org+school bound (belt-and-braces on top of RLS).
// The tables are append-only, so this repo exposes create + list only (no
// update/delete) — matching the SELECT/INSERT-only grant in the migration.

import type { TenantQueryClient } from "../tenant_db.ts";

export interface StaffDutyScope {
  organizationId: string;
  schoolId: string;
}

// ─── cap 131 — Substitute classes ───────────────────────────────────────────

export interface SubstituteClassRow {
  id: string;
  absent_teacher_id: string;
  substitute_teacher_id: string;
  duty_date: string;
  period_label: string;
  timetable_period_id: string | null;
  reason: string;
  created_by: string | null;
  created_at: string;
}

const SUBSTITUTE_COLUMNS =
  `id, absent_teacher_id, substitute_teacher_id, duty_date::text AS duty_date,
   period_label, timetable_period_id, reason, created_by,
   created_at::text AS created_at`;

/** Record a substitute class. The burden accrues to substituteTeacherId. */
export async function createSubstituteClass(
  db: TenantQueryClient,
  scope: StaffDutyScope,
  input: {
    absentTeacherId: string;
    substituteTeacherId: string;
    dutyDate: string;
    periodLabel: string;
    timetablePeriodId: string | null;
    reason: string;
    createdBy: string | null;
  },
): Promise<SubstituteClassRow> {
  const rows = await db.queryObject<SubstituteClassRow>(
    `INSERT INTO staff_substitute_classes (
       organization_id, school_id, absent_teacher_id, substitute_teacher_id,
       duty_date, period_label, timetable_period_id, reason, created_by
     ) VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9)
     RETURNING ${SUBSTITUTE_COLUMNS}`,
    [
      scope.organizationId,
      scope.schoolId,
      input.absentTeacherId,
      input.substituteTeacherId,
      input.dutyDate,
      input.periodLabel,
      input.timetablePeriodId,
      input.reason,
      input.createdBy,
    ],
  );
  return rows[0]!;
}

/** List substitute classes a staff member TOOK (the burden bearer). */
export async function listSubstituteClassesByStaff(
  db: TenantQueryClient,
  scope: StaffDutyScope,
  substituteTeacherId: string,
  limit: number,
): Promise<SubstituteClassRow[]> {
  return await db.queryObject<SubstituteClassRow>(
    `SELECT ${SUBSTITUTE_COLUMNS}
       FROM staff_substitute_classes
      WHERE organization_id = $1 AND school_id = $2 AND substitute_teacher_id = $3
      ORDER BY duty_date DESC, created_at DESC
      LIMIT $4`,
    [scope.organizationId, scope.schoolId, substituteTeacherId, limit],
  );
}

/** List every substitute class on a given date (whole-school view). */
export async function listSubstituteClassesByDate(
  db: TenantQueryClient,
  scope: StaffDutyScope,
  dutyDate: string,
  limit: number,
): Promise<SubstituteClassRow[]> {
  return await db.queryObject<SubstituteClassRow>(
    `SELECT ${SUBSTITUTE_COLUMNS}
       FROM staff_substitute_classes
      WHERE organization_id = $1 AND school_id = $2 AND duty_date = $3
      ORDER BY created_at DESC
      LIMIT $4`,
    [scope.organizationId, scope.schoolId, dutyDate, limit],
  );
}

// ─── cap 133 — Exam invigilation duties ─────────────────────────────────────

export interface ExamInvigilationDutyRow {
  id: string;
  staff_id: string;
  exam_id: string | null;
  exam_label: string;
  duty_date: string;
  room: string;
  session: string;
  created_by: string | null;
  created_at: string;
}

const INVIGILATION_COLUMNS =
  `id, staff_id, exam_id, exam_label, duty_date::text AS duty_date,
   room, session, created_by, created_at::text AS created_at`;

export async function createExamInvigilationDuty(
  db: TenantQueryClient,
  scope: StaffDutyScope,
  input: {
    staffId: string;
    examId: string | null;
    examLabel: string;
    dutyDate: string;
    room: string;
    session: string;
    createdBy: string | null;
  },
): Promise<ExamInvigilationDutyRow> {
  const rows = await db.queryObject<ExamInvigilationDutyRow>(
    `INSERT INTO staff_exam_invigilation_duties (
       organization_id, school_id, staff_id, exam_id, exam_label,
       duty_date, room, session, created_by
     ) VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9)
     RETURNING ${INVIGILATION_COLUMNS}`,
    [
      scope.organizationId,
      scope.schoolId,
      input.staffId,
      input.examId,
      input.examLabel,
      input.dutyDate,
      input.room,
      input.session,
      input.createdBy,
    ],
  );
  return rows[0]!;
}

export async function listExamInvigilationDutiesByStaff(
  db: TenantQueryClient,
  scope: StaffDutyScope,
  staffId: string,
  limit: number,
): Promise<ExamInvigilationDutyRow[]> {
  return await db.queryObject<ExamInvigilationDutyRow>(
    `SELECT ${INVIGILATION_COLUMNS}
       FROM staff_exam_invigilation_duties
      WHERE organization_id = $1 AND school_id = $2 AND staff_id = $3
      ORDER BY duty_date DESC, created_at DESC
      LIMIT $4`,
    [scope.organizationId, scope.schoolId, staffId, limit],
  );
}

export async function listExamInvigilationDutiesByDate(
  db: TenantQueryClient,
  scope: StaffDutyScope,
  dutyDate: string,
  limit: number,
): Promise<ExamInvigilationDutyRow[]> {
  return await db.queryObject<ExamInvigilationDutyRow>(
    `SELECT ${INVIGILATION_COLUMNS}
       FROM staff_exam_invigilation_duties
      WHERE organization_id = $1 AND school_id = $2 AND duty_date = $3
      ORDER BY created_at DESC
      LIMIT $4`,
    [scope.organizationId, scope.schoolId, dutyDate, limit],
  );
}

// ─── cap 132 — Non-teaching duties ──────────────────────────────────────────

export interface NonTeachingDutyRow {
  id: string;
  staff_id: string;
  duty_type: string;
  start_date: string;
  end_date: string | null;
  description: string;
  created_by: string | null;
  created_at: string;
}

const NON_TEACHING_COLUMNS =
  `id, staff_id, duty_type, start_date::text AS start_date,
   end_date::text AS end_date, description, created_by,
   created_at::text AS created_at`;

export async function createNonTeachingDuty(
  db: TenantQueryClient,
  scope: StaffDutyScope,
  input: {
    staffId: string;
    dutyType: string;
    startDate: string;
    endDate: string | null;
    description: string;
    createdBy: string | null;
  },
): Promise<NonTeachingDutyRow> {
  const rows = await db.queryObject<NonTeachingDutyRow>(
    `INSERT INTO staff_non_teaching_duties (
       organization_id, school_id, staff_id, duty_type,
       start_date, end_date, description, created_by
     ) VALUES ($1,$2,$3,$4,$5,$6,$7,$8)
     RETURNING ${NON_TEACHING_COLUMNS}`,
    [
      scope.organizationId,
      scope.schoolId,
      input.staffId,
      input.dutyType,
      input.startDate,
      input.endDate,
      input.description,
      input.createdBy,
    ],
  );
  return rows[0]!;
}

export async function listNonTeachingDutiesByStaff(
  db: TenantQueryClient,
  scope: StaffDutyScope,
  staffId: string,
  limit: number,
): Promise<NonTeachingDutyRow[]> {
  return await db.queryObject<NonTeachingDutyRow>(
    `SELECT ${NON_TEACHING_COLUMNS}
       FROM staff_non_teaching_duties
      WHERE organization_id = $1 AND school_id = $2 AND staff_id = $3
      ORDER BY start_date DESC, created_at DESC
      LIMIT $4`,
    [scope.organizationId, scope.schoolId, staffId, limit],
  );
}

/** List non-teaching duties ACTIVE on a date: the date falls within
 * [start_date, COALESCE(end_date, start_date)]. */
export async function listNonTeachingDutiesByDate(
  db: TenantQueryClient,
  scope: StaffDutyScope,
  onDate: string,
  limit: number,
): Promise<NonTeachingDutyRow[]> {
  return await db.queryObject<NonTeachingDutyRow>(
    `SELECT ${NON_TEACHING_COLUMNS}
       FROM staff_non_teaching_duties
      WHERE organization_id = $1 AND school_id = $2
        AND start_date <= $3 AND COALESCE(end_date, start_date) >= $3
      ORDER BY start_date DESC, created_at DESC
      LIMIT $4`,
    [scope.organizationId, scope.schoolId, onDate, limit],
  );
}
