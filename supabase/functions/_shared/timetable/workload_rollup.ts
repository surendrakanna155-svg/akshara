// Roadmap gap #9 — Unified per-teacher workload rollup (fair scheduling).
//
// Before this module there were TWO disjoint, inconsistent "workloads":
//   1. timetable_workload.ts  — counts SCHEDULED academic_timetable_periods,
//      overload threshold 24, but its `sections[]` was ALWAYS EMPTY.
//   2. subject_assignments_repository.computeSubjectWorkload — sums
//      teacher_subject_assignments.periods_per_week, overload threshold 25,
//      keyed per (teacher, subject) — a different unit entirely.
//
// This is the ONE unified per-teacher rollup that reconciles them:
//   • The SCHEDULED grid (academic_timetable_periods, via
//     loadSchoolPeriodsWithMeta) is the CANONICAL period source — a teacher's
//     periodCount is exactly how many periods they actually stand in front of a
//     class each week.
//   • That period meta ALSO carries sectionId + teacherAssignmentId, so we can
//     finally FILL the sections[] (the DISTINCT set of sections the teacher
//     teaches) that the legacy rollup left empty.
//   • Subject context is layered on top: subjectIds come from the scheduled
//     period's subject_label PLUS the teacher_subject_assignments catalog
//     (which is where the school records what a teacher is *qualified* to teach),
//     giving an honest union even when a subject is assigned but not yet timetabled.
//   • ONE shared overload threshold (24). The subject-assignment 25 is SUPERSEDED
//     for this unified view (see UNIFIED_OVERLOAD_THRESHOLD note below).
//
// Scope: principal / single-school (no director multi-school view this wave).
// No config, no migration — derived entirely from existing rows.

import type { TenantQueryClient } from "../tenant_db.ts";

/**
 * The single reconciled overload threshold for the unified workload view:
 * a teacher standing in front of a class for MORE than 24 scheduled periods per
 * week is overloaded.
 *
 * This equals the legacy timetable threshold (TEACHER_OVERLOAD_THRESHOLD = 24 in
 * timetable_workload.ts) and intentionally SUPERSEDES the per-(teacher,subject)
 * threshold of 25 in subject_assignments_repository.computeSubjectWorkload — the
 * two are no longer allowed to disagree in this unified rollup.
 */
export const UNIFIED_OVERLOAD_THRESHOLD = 24;

/** A teacher below this many scheduled periods per week is under-utilised. */
export const UNIFIED_UNDERLOAD_THRESHOLD = 10;

export type WorkloadStatus = "over" | "under" | "balanced";

export interface TeacherWorkloadRollup {
  teacherId: string;
  teacherName: string;
  /** Scheduled periods per week (canonical: academic_timetable_periods). */
  periodCount: number;
  /** Non-contact ("free") periods this week: working-week grid − periodCount,
   * clamped ≥ 0 (PRC-A cap 130). 0 when no timetable / no grid exists. */
  freePeriods: number;
  /** DISTINCT sections this teacher is scheduled to teach (was always empty). */
  sections: string[];
  /** DISTINCT subjects: union of scheduled subject labels + assignment catalog. */
  subjectIds: string[];
  status: WorkloadStatus;
  isOverloaded: boolean;
}

export interface WorkloadRollupSummary {
  totalTeachers: number;
  overloaded: number;
  underloaded: number;
  balanced: number;
  /** Mean scheduled periods across teachers (0 when there are no teachers). */
  avgPeriods: number;
}

export interface WorkloadRollupResult {
  teachers: TeacherWorkloadRollup[];
  summary: WorkloadRollupSummary;
}

/** Classify a scheduled period count into over / under / balanced. */
export function classifyWorkload(periodCount: number): WorkloadStatus {
  if (periodCount > UNIFIED_OVERLOAD_THRESHOLD) return "over";
  if (periodCount < UNIFIED_UNDERLOAD_THRESHOLD) return "under";
  return "balanced";
}

/** Free (non-contact) periods = working-week grid slots − scheduled contact
 * periods, never negative (PRC-A cap 130). Pure for unit testing. A teacher
 * scheduled beyond the nominal grid (multi-section overlap edge) clamps to 0
 * rather than reporting a negative "free" count. */
export function computeFreePeriods(gridSlots: number, periodCount: number): number {
  return Math.max(0, gridSlots - periodCount);
}

interface SchoolPeriodMetaRow {
  timetable_id: string;
  section_id: string;
  subject_label: string;
  teacher_id: string | null;
  teacher_assignment_id: string | null;
}

interface TeacherNameRow {
  teacher_id: string;
  teacher_name: string;
}

interface TeacherSubjectRow {
  teacher_user_id: string;
  subject_id: string;
}

/**
 * Build the ONE unified per-teacher workload rollup for a school+year.
 *
 * Honest zeros: when no timetable exists for the year the scheduled grid is
 * empty, so `teachers` is `[]` and every summary count is 0 (avgPeriods 0) —
 * we never fabricate a workload.
 */
export async function buildTeacherWorkloadRollup(
  db: TenantQueryClient,
  orgId: string,
  schoolId: string,
  academicYearId: string,
): Promise<WorkloadRollupResult> {
  // 1. Canonical source: the SCHEDULED grid. Carries sectionId + subject_label +
  //    teacherAssignmentId, so we can fill sections[] and seed subjectIds.
  const periodRows = await db.queryObject<SchoolPeriodMetaRow>(
    `SELECT t.id AS timetable_id, t.section_id, p.subject_label,
            p.teacher_id, p.teacher_assignment_id
     FROM academic_timetable_periods p
     INNER JOIN academic_timetables t ON t.id = p.timetable_id
     WHERE t.organization_id = $1 AND t.school_id = $2 AND t.academic_year_id = $3
       AND t.status <> 'archived'`,
    [orgId, schoolId, academicYearId],
  );

  // 1b. Working-week grid for free-period derivation (PRC-A cap 130). The grid is
  //     periods_per_day × days_per_week; use the FULLEST grid across the year's
  //     live timetables so a teacher's free periods are measured against the
  //     largest working week they could be scheduled into. Honest 0 when no
  //     timetable exists (grid 0 → every teacher's freePeriods is 0, same basis
  //     as periodCount 0 — never a fabricated capacity).
  const gridRows = await db.queryObject<{ grid_slots: string | null }>(
    `SELECT MAX(periods_per_day * days_per_week) AS grid_slots
       FROM academic_timetables
      WHERE organization_id = $1 AND school_id = $2 AND academic_year_id = $3
        AND status <> 'archived'`,
    [orgId, schoolId, academicYearId],
  );
  const gridSlots = Number(gridRows[0]?.grid_slots ?? 0);

  // 2. Teacher display names (same source/shape as getSchoolWorkload).
  const teacherNameRows = await db.queryObject<TeacherNameRow>(
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
  const names = new Map(teacherNameRows.map((r) => [r.teacher_id, r.teacher_name]));

  // 3. Subject CONTEXT from the assignment catalog: what each teacher is recorded
  //    as teaching for this year. Layered on top of the scheduled subject labels
  //    so subjectIds is an honest union even for assigned-but-not-yet-timetabled
  //    subjects.
  const subjectAssignmentRows = await db.queryObject<TeacherSubjectRow>(
    `SELECT teacher_user_id, subject_id
     FROM teacher_subject_assignments
     WHERE organization_id = $1 AND school_id = $2 AND academic_year_id = $3
       AND status = 'active'`,
    [orgId, schoolId, academicYearId],
  );
  const subjectsByTeacher = new Map<string, Set<string>>();
  for (const row of subjectAssignmentRows) {
    const bucket = subjectsByTeacher.get(row.teacher_user_id) ?? new Set<string>();
    bucket.add(row.subject_id);
    subjectsByTeacher.set(row.teacher_user_id, bucket);
  }

  // 4. Roll up the scheduled grid per teacher: periodCount + DISTINCT sections +
  //    DISTINCT subject labels (seeded from the grid, merged with the catalog).
  interface Accum {
    periodCount: number;
    sections: Set<string>;
    subjectIds: Set<string>;
  }
  const byTeacher = new Map<string, Accum>();

  for (const row of periodRows) {
    if (!row.teacher_id) continue;
    const acc = byTeacher.get(row.teacher_id) ?? {
      periodCount: 0,
      sections: new Set<string>(),
      subjectIds: new Set<string>(),
    };
    acc.periodCount += 1;
    if (row.section_id) acc.sections.add(row.section_id);
    // Scheduled subject label is subject CONTEXT (the grid stores a label, not a
    // subject UUID); include it so a teacher who is timetabled for a subject not
    // in the catalog still surfaces it.
    const label = row.subject_label?.trim();
    if (label) acc.subjectIds.add(label);
    byTeacher.set(row.teacher_id, acc);
  }

  // Merge the assignment catalog subjects for every teacher who appears in the
  // scheduled grid (principal-scope: the rollup is over SCHEDULED teachers).
  for (const [teacherId, acc] of byTeacher.entries()) {
    const catalog = subjectsByTeacher.get(teacherId);
    if (catalog) for (const s of catalog) acc.subjectIds.add(s);
  }

  const teachers: TeacherWorkloadRollup[] = [...byTeacher.entries()]
    .map(([teacherId, acc]) => {
      const status = classifyWorkload(acc.periodCount);
      return {
        teacherId,
        teacherName: names.get(teacherId)?.trim() || teacherId,
        periodCount: acc.periodCount,
        freePeriods: computeFreePeriods(gridSlots, acc.periodCount),
        sections: [...acc.sections].sort(),
        subjectIds: [...acc.subjectIds].sort(),
        status,
        isOverloaded: status === "over",
      };
    })
    // Busiest first, then stable by teacherId for deterministic output.
    .sort((a, b) =>
      b.periodCount - a.periodCount || a.teacherId.localeCompare(b.teacherId)
    );

  const overloaded = teachers.filter((t) => t.status === "over").length;
  const underloaded = teachers.filter((t) => t.status === "under").length;
  const balanced = teachers.filter((t) => t.status === "balanced").length;
  const totalPeriods = teachers.reduce((sum, t) => sum + t.periodCount, 0);
  const avgPeriods = teachers.length === 0
    ? 0
    : Math.round((totalPeriods / teachers.length) * 100) / 100;

  return {
    teachers,
    summary: {
      totalTeachers: teachers.length,
      overloaded,
      underloaded,
      balanced,
      avgPeriods,
    },
  };
}
