import type { TenantQueryClient } from "../tenant_db.ts";
import { detectTeacherConflicts, type PeriodWithMeta } from "./timetable_engine.ts";

/**
 * Roadmap gap #8 — PERSISTED timetable substitutions (write path).
 *
 * A substitution is a dated overlay on a v7.5 academic_timetable_periods row:
 * "for THIS period, on THIS date, teacher X stands in". It never edits the
 * published grid (see the reject_published_period_edit trigger); it lives in
 * academic_timetable_substitutions and is resolved per-date at read time.
 */

export class SubstitutionValidationError extends Error {
  readonly code: string;
  readonly httpStatus: number;
  constructor(code: string, message: string, httpStatus = 422) {
    super(message);
    this.name = "SubstitutionValidationError";
    this.code = code;
    this.httpStatus = httpStatus;
  }
}

export interface SubstitutionRow {
  id: string;
  organization_id: string;
  school_id: string;
  academic_year_id: string;
  period_id: string;
  sub_date: string;
  original_teacher_id: string | null;
  substitute_teacher_id: string | null;
  reason: string;
  created_by: string | null;
  created_at: string;
}

interface PeriodContextRow {
  period_id: string;
  timetable_id: string;
  academic_year_id: string;
  section_id: string;
  day_of_week: number;
  period_number: number;
  subject_label: string;
  teacher_id: string | null;
  teacher_assignment_id: string | null;
  room_label: string;
}

/**
 * ISO day-of-week (Mon=1 .. Sun=7) for a YYYY-MM-DD date, matching the
 * academic_timetable_periods.day_of_week convention (1..7). Parsed as UTC so a
 * bare date is timezone-stable.
 */
export function isoDayOfWeek(subDate: string): number {
  const d = new Date(`${subDate}T00:00:00.000Z`);
  const js = d.getUTCDay(); // 0=Sun .. 6=Sat
  return js === 0 ? 7 : js;
}

function isValidDate(subDate: string): boolean {
  if (!/^\d{4}-\d{2}-\d{2}$/.test(subDate)) return false;
  const d = new Date(`${subDate}T00:00:00.000Z`);
  return !Number.isNaN(d.getTime());
}

/** Load the target period, validating it belongs to org+school. */
async function loadPeriodContext(
  db: TenantQueryClient,
  orgId: string,
  schoolId: string,
  periodId: string,
): Promise<PeriodContextRow | null> {
  const rows = await db.queryObject<PeriodContextRow>(
    `SELECT p.id AS period_id, p.timetable_id, t.academic_year_id, t.section_id,
            p.day_of_week, p.period_number, p.subject_label,
            p.teacher_id, p.teacher_assignment_id, p.room_label
     FROM academic_timetable_periods p
     INNER JOIN academic_timetables t ON t.id = p.timetable_id
     WHERE p.id = $1 AND p.organization_id = $2 AND p.school_id = $3`,
    [periodId, orgId, schoolId],
  );
  return rows[0] ?? null;
}

/**
 * Resolve the school's period grid for a specific slot (day_of_week +
 * period_number), applying any same-date substitutions so the "who is teaching
 * this slot" question is answered against the LIVE roster, not the base grid.
 * Used to detect whether a proposed substitute is already occupied.
 */
async function resolveGridForSlot(
  db: TenantQueryClient,
  orgId: string,
  schoolId: string,
  academicYearId: string,
  dayOfWeek: number,
  subDate: string,
): Promise<PeriodWithMeta[]> {
  const rows = await db.queryObject<{
    period_id: string;
    timetable_id: string;
    section_id: string;
    day_of_week: number;
    period_number: number;
    subject_label: string;
    base_teacher_id: string | null;
    teacher_assignment_id: string | null;
    room_label: string;
    substitute_teacher_id: string | null;
  }>(
    `SELECT p.id AS period_id, p.timetable_id, t.section_id, p.day_of_week,
            p.period_number, p.subject_label, p.teacher_id AS base_teacher_id,
            p.teacher_assignment_id, p.room_label,
            s.substitute_teacher_id
     FROM academic_timetable_periods p
     INNER JOIN academic_timetables t ON t.id = p.timetable_id
     LEFT JOIN academic_timetable_substitutions s
       ON s.period_id = p.id AND s.sub_date = $4
     WHERE t.organization_id = $1 AND t.school_id = $2
       AND t.academic_year_id = $3
       AND t.status <> 'archived'
       AND p.day_of_week = $5`,
    [orgId, schoolId, academicYearId, subDate, dayOfWeek],
  );

  return rows.map((row) => ({
    timetableId: row.timetable_id,
    sectionId: row.section_id,
    dayOfWeek: row.day_of_week,
    periodNumber: row.period_number,
    subjectLabel: row.subject_label,
    // Effective teacher = substitute if present, else base teacher.
    teacherId: row.substitute_teacher_id ?? row.base_teacher_id,
    teacherAssignmentId: row.teacher_assignment_id,
    roomLabel: row.room_label,
  }));
}

export interface CreateSubstitutionInput {
  orgId: string;
  schoolId: string;
  periodId: string;
  subDate: string;
  substituteTeacherId: string;
  reason?: string;
  createdBy: string;
}

/**
 * Create (or idempotently re-assign) a substitution. Validates that the period
 * exists for this org+school and that the proposed substitute is NOT already
 * teaching another period in the same slot on that date → SUBSTITUTE_BUSY (409).
 */
export async function createSubstitution(
  db: TenantQueryClient,
  input: CreateSubstitutionInput,
): Promise<SubstitutionRow> {
  const { orgId, schoolId, periodId, subDate, substituteTeacherId } = input;

  if (!isValidDate(subDate)) {
    throw new SubstitutionValidationError("VALIDATION_ERROR", "subDate must be YYYY-MM-DD", 422);
  }

  const period = await loadPeriodContext(db, orgId, schoolId, periodId);
  if (!period) {
    throw new SubstitutionValidationError("NOT_FOUND", "Period not found", 404);
  }

  // Substitute-busy check: resolve the day's grid (with same-date subs applied),
  // then inject the proposed substitute into THIS period and see whether that
  // introduces a NEW teacher double-booking in the target slot.
  const dayOfWeek = isoDayOfWeek(subDate);
  const grid = await resolveGridForSlot(db, orgId, schoolId, period.academic_year_id, dayOfWeek, subDate);
  const proposed: PeriodWithMeta[] = grid.map((p) =>
    p.timetableId === period.timetable_id && p.periodNumber === period.period_number
      ? { ...p, teacherId: substituteTeacherId }
      : p
  );
  const conflicts = detectTeacherConflicts(proposed).filter(
    (c) =>
      c.entityId === substituteTeacherId &&
      c.periodNumber === period.period_number &&
      c.dayOfWeek === dayOfWeek,
  );
  if (conflicts.length > 0) {
    throw new SubstitutionValidationError(
      "SUBSTITUTE_BUSY",
      `Substitute ${substituteTeacherId} is already teaching period ${period.period_number} on ${subDate}`,
      409,
    );
  }

  const rows = await db.queryObject<SubstitutionRow>(
    `INSERT INTO academic_timetable_substitutions (
       organization_id, school_id, academic_year_id, period_id, sub_date,
       original_teacher_id, substitute_teacher_id, reason, created_by
     ) VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9)
     ON CONFLICT (period_id, sub_date) DO UPDATE SET
       substitute_teacher_id = EXCLUDED.substitute_teacher_id,
       original_teacher_id = EXCLUDED.original_teacher_id,
       reason = EXCLUDED.reason,
       created_by = EXCLUDED.created_by
     RETURNING id, organization_id, school_id, academic_year_id, period_id,
               sub_date::text AS sub_date, original_teacher_id, substitute_teacher_id,
               reason, created_by, created_at`,
    [
      orgId,
      schoolId,
      period.academic_year_id,
      periodId,
      subDate,
      period.teacher_id,
      substituteTeacherId,
      input.reason ?? "",
      input.createdBy,
    ],
  );
  return rows[0]!;
}

export interface ResolvedSubstitution {
  id: string;
  periodId: string;
  subDate: string;
  timetableId: string;
  sectionId: string;
  dayOfWeek: number;
  periodNumber: number;
  subjectLabel: string;
  originalTeacherId: string | null;
  substituteTeacherId: string | null;
  reason: string;
  roomLabel: string;
}

/** List substitutions for a date, joined to their period context (resolved grid). */
export async function listSubstitutions(
  db: TenantQueryClient,
  orgId: string,
  schoolId: string,
  opts: { date: string },
): Promise<ResolvedSubstitution[]> {
  if (!isValidDate(opts.date)) {
    throw new SubstitutionValidationError("VALIDATION_ERROR", "date must be YYYY-MM-DD", 422);
  }
  const rows = await db.queryObject<{
    id: string;
    period_id: string;
    sub_date: string;
    timetable_id: string;
    section_id: string;
    day_of_week: number;
    period_number: number;
    subject_label: string;
    original_teacher_id: string | null;
    substitute_teacher_id: string | null;
    reason: string;
    room_label: string;
  }>(
    `SELECT s.id, s.period_id, s.sub_date::text AS sub_date, p.timetable_id,
            t.section_id, p.day_of_week, p.period_number, p.subject_label,
            s.original_teacher_id, s.substitute_teacher_id, s.reason, p.room_label
     FROM academic_timetable_substitutions s
     INNER JOIN academic_timetable_periods p ON p.id = s.period_id
     INNER JOIN academic_timetables t ON t.id = p.timetable_id
     WHERE s.organization_id = $1 AND s.school_id = $2 AND s.sub_date = $3
     ORDER BY p.day_of_week, p.period_number, t.section_id`,
    [orgId, schoolId, opts.date],
  );
  return rows.map((row) => ({
    id: row.id,
    periodId: row.period_id,
    subDate: row.sub_date,
    timetableId: row.timetable_id,
    sectionId: row.section_id,
    dayOfWeek: row.day_of_week,
    periodNumber: row.period_number,
    subjectLabel: row.subject_label,
    originalTeacherId: row.original_teacher_id,
    substituteTeacherId: row.substitute_teacher_id,
    reason: row.reason,
    roomLabel: row.room_label,
  }));
}

export async function deleteSubstitution(
  db: TenantQueryClient,
  orgId: string,
  schoolId: string,
  id: string,
): Promise<SubstitutionRow | null> {
  const rows = await db.queryObject<SubstitutionRow>(
    `DELETE FROM academic_timetable_substitutions
     WHERE id = $1 AND organization_id = $2 AND school_id = $3
     RETURNING id, organization_id, school_id, academic_year_id, period_id,
               sub_date::text AS sub_date, original_teacher_id, substitute_teacher_id,
               reason, created_by, created_at`,
    [id, orgId, schoolId],
  );
  return rows[0] ?? null;
}

export interface TeacherOnLeave {
  teacherId: string;
  fromDate: string | null;
  toDate: string | null;
  reason: string;
}

/**
 * Server-side "who is on leave on this date" derivation. Source of truth is the
 * HR/staff leave table `mobile_leave_requests` filtered to APPROVED teacher
 * leaves (requester_scope = 'teacher') whose machine-readable [from_date,
 * to_date] window covers the date. This replaces the old client-side guesswork:
 * the client stops deriving on-leave itself and reads this list.
 *
 * Rows without machine-readable date bounds (legacy label-only) never match —
 * consistent with approvedLeaveStudentIdsForToday()'s auto-excuse behaviour.
 */
export async function listTeachersOnLeave(
  db: TenantQueryClient,
  orgId: string,
  schoolId: string,
  date: string,
): Promise<TeacherOnLeave[]> {
  if (!isValidDate(date)) {
    throw new SubstitutionValidationError("VALIDATION_ERROR", "date must be YYYY-MM-DD", 422);
  }
  const rows = await db.queryObject<{
    requester_user_id: string;
    from_date: string | null;
    to_date: string | null;
    reason: string;
  }>(
    `SELECT DISTINCT requester_user_id,
            from_date::text AS from_date, to_date::text AS to_date, reason
     FROM mobile_leave_requests
     WHERE organization_id = $1 AND school_id = $2
       AND requester_scope = 'teacher'
       AND status = 'approved'
       AND from_date IS NOT NULL AND to_date IS NOT NULL
       AND from_date <= $3::date AND to_date >= $3::date`,
    [orgId, schoolId, date],
  );
  return rows.map((row) => ({
    teacherId: row.requester_user_id,
    fromDate: row.from_date,
    toDate: row.to_date,
    reason: row.reason,
  }));
}
