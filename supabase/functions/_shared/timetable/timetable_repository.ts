import type { TenantQueryClient } from "../tenant_db.ts";
import { listTeacherAssignmentsPage } from "../academic/teacher_assignments_repository.ts";
import { listSectionsPage } from "../academic/sections_repository.ts";
import {
  detectAllConflicts,
  generateSectionPeriods,
  type CatalogAssignment,
  type GenerationSectionContext,
  type PeriodWithMeta,
  validateTimetablePeriods,
} from "./timetable_engine.ts";
import { countOverloadedTeachers, workloadFromSchoolPeriods } from "./timetable_workload.ts";
import type {
  TimetableConflict,
  TimetablePeriodInput,
  TimetableRow,
  TimetableStatus,
  TimetableSummary,
  TimetableValidationResult,
} from "./timetable_types.ts";

export const ACADEMIC_TIMETABLE_PROBE_SCHOOL_A = "d0500000-0000-4000-8000-000000000001";
export const ACADEMIC_TIMETABLE_PROBE_SCHOOL_B = "d0500000-0000-4000-8000-000000000002";
export const ACADEMIC_TIMETABLE_PROBE_SQL = `
  SELECT count(*)::text AS count FROM academic_timetables WHERE id = $1::uuid
`;

export class TimetableNotFoundError extends Error {
  constructor(id: string) {
    super(`Timetable not found: ${id}`);
    this.name = "TimetableNotFoundError";
  }
}

/** A move/write would introduce a NEW teacher or room double-booking. */
export class TimetableClashError extends Error {
  readonly conflicts: TimetableConflict[];
  constructor(conflicts: TimetableConflict[]) {
    super(
      `Move rejected: introduces ${conflicts.length} new clash(es): ` +
        conflicts.map((c) => `${c.type}@d${c.dayOfWeek}p${c.periodNumber}`).join(", "),
    );
    this.name = "TimetableClashError";
    this.conflicts = conflicts;
  }
}

/** Editing periods of a PUBLISHED timetable is forbidden (app-layer guard). */
export class TimetablePublishedError extends Error {
  constructor() {
    super("Cannot edit periods of a published timetable");
    this.name = "TimetablePublishedError";
  }
}

/**
 * Stable identity for a conflict so before/after sets can be diffed. Two runs of
 * detectAllConflicts over equivalent grids produce equal keys for the "same"
 * clash, letting us reject only NEWLY-introduced double-bookings (a move that
 * merely leaves a pre-existing clash untouched is not blocked).
 */
function conflictKey(c: TimetableConflict): string {
  return [
    c.type,
    c.entityId,
    c.dayOfWeek,
    c.periodNumber,
    [...c.sectionIds].sort().join("+"),
  ].join(":");
}

/**
 * Reject the write if `after` contains a teacher/room clash that was NOT present
 * in `before`. Section-duplicate conflicts are ignored here (the UNIQUE
 * (timetable_id, day_of_week, period_number) constraint already prevents a
 * section double-book at the DB layer).
 */
function assertNoNewClashes(before: PeriodWithMeta[], after: PeriodWithMeta[]): void {
  const relevant = (list: PeriodWithMeta[]) =>
    detectAllConflicts(list).filter((c) => c.type === "teacher" || c.type === "room");
  const beforeKeys = new Set(relevant(before).map(conflictKey));
  const introduced = relevant(after).filter((c) => !beforeKeys.has(conflictKey(c)));
  if (introduced.length > 0) {
    throw new TimetableClashError(introduced);
  }
}

export interface TimetablePeriodRow {
  id: string;
  timetable_id: string;
  day_of_week: number;
  period_number: number;
  subject_label: string;
  teacher_id: string | null;
  teacher_assignment_id: string | null;
  room_label: string;
}

export async function listTimetables(
  db: TenantQueryClient,
  orgId: string,
  schoolId: string,
  academicYearId?: string,
): Promise<TimetableRow[]> {
  return await db.queryObject<TimetableRow>(
    `SELECT id, organization_id, school_id, academic_year_id, section_id, status, version,
            periods_per_day, days_per_week, validation_summary, published_at,
            created_by, created_at, updated_at
     FROM academic_timetables
     WHERE organization_id = $1 AND school_id = $2
       AND ($3::uuid IS NULL OR academic_year_id = $3)
     ORDER BY updated_at DESC`,
    [orgId, schoolId, academicYearId ?? null],
  );
}

export async function getTimetable(
  db: TenantQueryClient,
  orgId: string,
  schoolId: string,
  timetableId: string,
): Promise<TimetableRow> {
  const rows = await db.queryObject<TimetableRow>(
    `SELECT id, organization_id, school_id, academic_year_id, section_id, status, version,
            periods_per_day, days_per_week, validation_summary, published_at,
            created_by, created_at, updated_at
     FROM academic_timetables
     WHERE organization_id = $1 AND school_id = $2 AND id = $3`,
    [orgId, schoolId, timetableId],
  );
  if (!rows[0]) throw new TimetableNotFoundError(timetableId);
  return rows[0];
}

export async function listTimetablePeriods(
  db: TenantQueryClient,
  orgId: string,
  schoolId: string,
  timetableId: string,
): Promise<TimetablePeriodRow[]> {
  return await db.queryObject<TimetablePeriodRow>(
    `SELECT id, timetable_id, day_of_week, period_number, subject_label,
            teacher_id, teacher_assignment_id, room_label
     FROM academic_timetable_periods
     WHERE organization_id = $1 AND school_id = $2 AND timetable_id = $3
     ORDER BY day_of_week, period_number`,
    [orgId, schoolId, timetableId],
  );
}

async function loadSchoolPeriodsWithMeta(
  db: TenantQueryClient,
  orgId: string,
  schoolId: string,
  academicYearId: string,
): Promise<PeriodWithMeta[]> {
  const rows = await db.queryObject<{
    timetable_id: string;
    section_id: string;
    day_of_week: number;
    period_number: number;
    subject_label: string;
    teacher_id: string | null;
    teacher_assignment_id: string | null;
    room_label: string;
  }>(
    `SELECT t.id AS timetable_id, t.section_id, p.day_of_week, p.period_number,
            p.subject_label, p.teacher_id, p.teacher_assignment_id, p.room_label
     FROM academic_timetable_periods p
     INNER JOIN academic_timetables t ON t.id = p.timetable_id
     WHERE t.organization_id = $1 AND t.school_id = $2 AND t.academic_year_id = $3
       AND t.status <> 'archived'`,
    [orgId, schoolId, academicYearId],
  );

  return rows.map((row) => ({
    timetableId: row.timetable_id,
    sectionId: row.section_id,
    dayOfWeek: row.day_of_week,
    periodNumber: row.period_number,
    subjectLabel: row.subject_label,
    teacherId: row.teacher_id,
    teacherAssignmentId: row.teacher_assignment_id,
    roomLabel: row.room_label,
  }));
}

async function loadCatalogAssignments(
  db: TenantQueryClient,
  orgId: string,
  schoolId: string,
): Promise<Map<string, CatalogAssignment[]>> {
  const page = await listTeacherAssignmentsPage(db, orgId, schoolId, {}, { page: 1, pageSize: 500 });
  const map = new Map<string, CatalogAssignment[]>();
  for (const row of page.items) {
    const bucket = map.get(row.section_id) ?? [];
    bucket.push({
      assignmentId: row.id,
      teacherId: row.teacher_id,
      teacherName: row.teacher_name,
      sectionId: row.section_id,
      className: row.class_name,
      sectionName: row.section_name,
      role: row.role,
      isPrimary: row.is_primary,
    });
    map.set(row.section_id, bucket);
  }
  return map;
}

async function replacePeriods(
  db: TenantQueryClient,
  orgId: string,
  schoolId: string,
  timetableId: string,
  periods: TimetablePeriodInput[],
  context?: { academicYearId: string; sectionId: string },
): Promise<void> {
  // Clash-recheck (delta): reject a replacement that introduces a NEW teacher or
  // room double-booking vs the current school grid. Only runs when the caller
  // supplies the year/section context (generation path). The greedy generator
  // stays greedy — pre-existing clashes are not blocked, only newly-introduced
  // cross-timetable ones.
  if (context) {
    const before = await loadSchoolPeriodsWithMeta(db, orgId, schoolId, context.academicYearId);
    const replacement: PeriodWithMeta[] = periods.map((p) => ({
      ...p,
      timetableId,
      sectionId: context.sectionId,
    }));
    const after = [
      ...before.filter((p) => p.timetableId !== timetableId),
      ...replacement,
    ];
    assertNoNewClashes(before, after);
  }

  await db.queryObject(
    `DELETE FROM academic_timetable_periods
     WHERE organization_id = $1 AND school_id = $2 AND timetable_id = $3`,
    [orgId, schoolId, timetableId],
  );

  for (const period of periods) {
    await db.queryObject(
      `INSERT INTO academic_timetable_periods (
         timetable_id, organization_id, school_id, day_of_week, period_number,
         subject_label, teacher_id, teacher_assignment_id, room_label
       ) VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9)`,
      [
        timetableId,
        orgId,
        schoolId,
        period.dayOfWeek,
        period.periodNumber,
        period.subjectLabel,
        period.teacherId,
        period.teacherAssignmentId,
        period.roomLabel,
      ],
    );
  }
}

export async function generateTimetablesForYear(
  db: TenantQueryClient,
  orgId: string,
  schoolId: string,
  academicYearId: string,
  createdBy: string,
  options?: { periodsPerDay?: number; daysPerWeek?: number; sectionId?: string; subjects?: string[] },
): Promise<TimetableRow[]> {
  const periodsPerDay = options?.periodsPerDay ?? 6;
  const daysPerWeek = options?.daysPerWeek ?? 5;
  const assignmentsBySection = await loadCatalogAssignments(db, orgId, schoolId);
  const sections = await listSectionsPage(
    db,
    orgId,
    schoolId,
    { academicYearId, status: "active" },
    { page: 1, pageSize: 500 },
  );

  const created: TimetableRow[] = [];
  for (const section of sections.items) {
    if (options?.sectionId && section.id !== options.sectionId) continue;

    const versionRows = await db.queryObject<{ max: number | null }>(
      `SELECT max(version)::int AS max FROM academic_timetables
       WHERE organization_id = $1 AND school_id = $2
         AND academic_year_id = $3 AND section_id = $4`,
      [orgId, schoolId, academicYearId, section.id],
    );
    const version = (versionRows[0]?.max ?? 0) + 1;

    const rows = await db.queryObject<TimetableRow>(
      `INSERT INTO academic_timetables (
         organization_id, school_id, academic_year_id, section_id, status, version,
         periods_per_day, days_per_week, created_by
       ) VALUES ($1,$2,$3,$4,'draft',$5,$6,$7,$8)
       RETURNING id, organization_id, school_id, academic_year_id, section_id, status, version,
                 periods_per_day, days_per_week, validation_summary, published_at,
                 created_by, created_at, updated_at`,
      [orgId, schoolId, academicYearId, section.id, version, periodsPerDay, daysPerWeek, createdBy],
    );
    const timetable = rows[0]!;

    const context: GenerationSectionContext = {
      sectionId: section.id,
      className: section.class_name,
      sectionName: section.section_name,
      assignments: assignmentsBySection.get(section.id) ?? [],
    };
    const periods = generateSectionPeriods(context, {
      periodsPerDay,
      daysPerWeek,
      subjects: options?.subjects,
    });
    await replacePeriods(db, orgId, schoolId, timetable.id, periods, {
      academicYearId,
      sectionId: section.id,
    });
    created.push(timetable);
  }

  return created;
}

export async function validateTimetableById(
  db: TenantQueryClient,
  orgId: string,
  schoolId: string,
  timetableId: string,
): Promise<TimetableValidationResult> {
  const timetable = await getTimetable(db, orgId, schoolId, timetableId);
  const periods = await listTimetablePeriods(db, orgId, schoolId, timetableId);
  const schoolPeriods = await loadSchoolPeriodsWithMeta(
    db,
    orgId,
    schoolId,
    timetable.academic_year_id,
  );
  const mapped = periods.map((p) => ({
    dayOfWeek: p.day_of_week,
    periodNumber: p.period_number,
    subjectLabel: p.subject_label,
    teacherId: p.teacher_id,
    teacherAssignmentId: p.teacher_assignment_id,
    roomLabel: p.room_label,
  }));
  const result = validateTimetablePeriods(
    timetable.section_id,
    timetable.id,
    mapped,
    timetable.periods_per_day,
    timetable.days_per_week,
    schoolPeriods,
  );

  await db.queryObject(
    `UPDATE academic_timetables
     SET status = $4, validation_summary = $5, updated_at = timezone('utc', now())
     WHERE id = $1 AND organization_id = $2 AND school_id = $3`,
    [
      timetableId,
      orgId,
      schoolId,
      result.valid ? "validated" : "draft",
      JSON.stringify({
        valid: result.valid,
        conflictCount: result.conflictCount,
        gapCount: result.gapCount,
      }),
    ],
  );

  return result;
}

export async function publishTimetableById(
  db: TenantQueryClient,
  orgId: string,
  schoolId: string,
  timetableId: string,
): Promise<TimetableRow> {
  const timetable = await getTimetable(db, orgId, schoolId, timetableId);
  if (timetable.status !== "validated") {
    throw new Error("Timetable must be validated before publish");
  }

  const rows = await db.queryObject<TimetableRow>(
    `UPDATE academic_timetables
     SET status = 'published', published_at = timezone('utc', now()), updated_at = timezone('utc', now())
     WHERE id = $1 AND organization_id = $2 AND school_id = $3
     RETURNING id, organization_id, school_id, academic_year_id, section_id, status, version,
               periods_per_day, days_per_week, validation_summary, published_at,
               created_by, created_at, updated_at`,
    [timetableId, orgId, schoolId],
  );
  return rows[0]!;
}

export async function moveTimetablePeriod(
  db: TenantQueryClient,
  orgId: string,
  schoolId: string,
  input: {
    periodId: string;
    targetDayOfWeek: number;
    targetPeriodNumber: number;
    roomLabel?: string;
  },
): Promise<{ periodId: string; dayOfWeek: number; periodNumber: number; roomLabel: string }> {
  // Load the target period + its parent timetable (status, academic_year) so we
  // can (a) block edits on a published timetable and (b) run the clash-recheck
  // against the whole school grid for that year.
  const currentRows = await db.queryObject<{
    id: string;
    timetable_id: string;
    academic_year_id: string;
    status: TimetableStatus;
    section_id: string;
    day_of_week: number;
    period_number: number;
    subject_label: string;
    teacher_id: string | null;
    teacher_assignment_id: string | null;
    room_label: string;
  }>(
    `SELECT p.id, p.timetable_id, t.academic_year_id, t.status, t.section_id,
            p.day_of_week, p.period_number, p.subject_label,
            p.teacher_id, p.teacher_assignment_id, p.room_label
     FROM academic_timetable_periods p
     INNER JOIN academic_timetables t ON t.id = p.timetable_id
     WHERE p.id = $1 AND p.organization_id = $2 AND p.school_id = $3`,
    [input.periodId, orgId, schoolId],
  );
  const current = currentRows[0];
  if (!current) throw new Error("Period not found");

  // Belt-and-suspenders with the DB trigger reject_published_period_edit().
  if (current.status === "published") {
    throw new TimetablePublishedError();
  }

  // Clash-recheck: build before/after grids and reject a move that introduces a
  // NEW teacher or room double-booking.
  const before = await loadSchoolPeriodsWithMeta(db, orgId, schoolId, current.academic_year_id);
  const nextRoom = input.roomLabel ?? current.room_label;
  const after = before.map((p) =>
    p.timetableId === current.timetable_id &&
      p.dayOfWeek === current.day_of_week &&
      p.periodNumber === current.period_number
      ? {
        ...p,
        dayOfWeek: input.targetDayOfWeek,
        periodNumber: input.targetPeriodNumber,
        roomLabel: nextRoom,
      }
      : p
  );
  assertNoNewClashes(before, after);

  const rows = await db.queryObject<{
    id: string;
    timetable_id: string;
    day_of_week: number;
    period_number: number;
    room_label: string;
  }>(
    `UPDATE academic_timetable_periods
     SET day_of_week = $4,
         period_number = $5,
         room_label = coalesce($6, room_label),
         updated_at = timezone('utc', now())
     WHERE id = $1 AND organization_id = $2 AND school_id = $3
     RETURNING id, timetable_id, day_of_week, period_number, room_label`,
    [
      input.periodId,
      orgId,
      schoolId,
      input.targetDayOfWeek,
      input.targetPeriodNumber,
      input.roomLabel ?? null,
    ],
  );
  if (!rows[0]) throw new Error("Period not found");
  const row = rows[0];
  return {
    periodId: row.id,
    dayOfWeek: row.day_of_week,
    periodNumber: row.period_number,
    roomLabel: row.room_label,
  };
}

export async function getTimetableSummary(
  db: TenantQueryClient,
  orgId: string,
  schoolId: string,
  academicYearId: string,
): Promise<TimetableSummary> {
  const timetables = await listTimetables(db, orgId, schoolId, academicYearId);
  const schoolPeriods = await loadSchoolPeriodsWithMeta(db, orgId, schoolId, academicYearId);
  const { detectAllConflicts } = await import("./timetable_engine.ts");
  const conflicts = detectAllConflicts(schoolPeriods);
  const workload = workloadFromSchoolPeriods(schoolPeriods, new Map());

  let gapCount = 0;
  for (const timetable of timetables) {
    if (timetable.status === "archived") continue;
    const periods = schoolPeriods.filter((p) => p.timetableId === timetable.id);
    const { findTimetableGaps } = await import("./timetable_engine.ts");
    gapCount += findTimetableGaps(
      timetable.section_id,
      periods,
      timetable.periods_per_day,
      timetable.days_per_week,
    ).length;
  }

  return {
    academicYearId,
    totalTimetables: timetables.length,
    draftCount: timetables.filter((t) => t.status === "draft").length,
    validatedCount: timetables.filter((t) => t.status === "validated").length,
    publishedCount: timetables.filter((t) => t.status === "published").length,
    conflictCount: conflicts.length,
    gapCount,
    overloadedTeacherCount: countOverloadedTeachers(workload),
  };
}

export async function getSchoolConflicts(
  db: TenantQueryClient,
  orgId: string,
  schoolId: string,
  academicYearId: string,
) {
  const schoolPeriods = await loadSchoolPeriodsWithMeta(db, orgId, schoolId, academicYearId);
  const { detectAllConflicts } = await import("./timetable_engine.ts");
  return detectAllConflicts(schoolPeriods);
}

export async function getSchoolWorkload(
  db: TenantQueryClient,
  orgId: string,
  schoolId: string,
  academicYearId: string,
) {
  const schoolPeriods = await loadSchoolPeriodsWithMeta(db, orgId, schoolId, academicYearId);
  const teacherRows = await db.queryObject<{ teacher_id: string; teacher_name: string }>(
    `SELECT DISTINCT ta.teacher_id,
            coalesce(sm_teacher.member_display_name, ta.teacher_id::text) AS teacher_name
     FROM teacher_assignments ta
     LEFT JOIN school_memberships sm_teacher
       ON sm_teacher.user_id = ta.teacher_id
       AND sm_teacher.school_id = ta.school_id
       AND sm_teacher.role = 'teacher'
     WHERE ta.organization_id = $1 AND ta.school_id = $2`,
    [orgId, schoolId],
  );
  const names = new Map(teacherRows.map((r) => [r.teacher_id, r.teacher_name]));
  return workloadFromSchoolPeriods(schoolPeriods, names);
}
