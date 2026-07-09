import type { TenantQueryClient } from "../tenant_db.ts";
import { buildSchedulingRecommendations } from "../timetable/timetable_scheduling_advisor.ts";
import { reassignTimetablePeriodTeacher } from "../timetable/timetable_repository.ts";
import type {
  SchedulingRecommendation,
  TeacherWorkloadEntry,
  TimetableSummary,
  TimetableValidationResult,
} from "../timetable/timetable_types.ts";

/**
 * A recommendation the client can act on carries a stable, parseable id.
 * `readOnly` is widened to `boolean` (SchedulingRecommendation locks it to the
 * literal `true` — every explanatory recommendation from the shared advisor
 * is readOnly by construction) so this module can also emit actionable ones.
 */
export interface ActionableRecommendation {
  kind: SchedulingRecommendation["kind"];
  title: string;
  detail: string;
  readOnly: boolean;
  recommendationId?: string;
}

export interface TimetableOptimizationResult {
  qualityScore: number;
  overloadAlerts: Array<{ teacherId: string; teacherName: string; periodCount: number }>;
  freePeriodAnalysis: Array<{ teacherId: string; teacherName: string; freePeriods: number }>;
  conflictCount: number;
  substituteSuggestions: Array<{ conflictMessage: string; suggestion: string }>;
  recommendations: ActionableRecommendation[];
}

export interface ApplyTimetableOptimizationApi {
  appliedRecommendationIds: string[];
  appliedCount: number;
  updatedConflictCount: number;
  updatedQualityScore: number;
  message: string;
}

const OVERLOAD_THRESHOLD = 24;
// Weekly period count a fully-loaded teacher is expected to carry. Exported so
// the substitute/reassignment wizards (timetable_workforce_service.ts) score
// "free periods" against the SAME baseline this optimizer already uses.
export const EXPECTED_WEEKLY_PERIODS = 20;

export async function analyzeTimetableOptimization(
  db: TenantQueryClient,
  orgId: string,
  schoolId: string,
  academicYearId: string,
): Promise<TimetableOptimizationResult> {
  const timetables = await db.queryObject<{ id: string; section_id: string; status: string }>(
    `SELECT id, section_id, status FROM academic_timetables
     WHERE organization_id = $1 AND school_id = $2 AND academic_year_id = $3
       AND status != 'archived'`,
    [orgId, schoolId, academicYearId],
  );

  const periods = await db.queryObject<{
    timetable_id: string;
    day_of_week: number;
    period_number: number;
    teacher_id: string | null;
    room_label: string;
    subject_label: string;
  }>(
    `SELECT tp.timetable_id, tp.day_of_week, tp.period_number, tp.teacher_id,
            tp.room_label, tp.subject_label
     FROM academic_timetable_periods tp
     JOIN academic_timetables t ON t.id = tp.timetable_id
     WHERE t.organization_id = $1 AND t.school_id = $2 AND t.academic_year_id = $3
       AND t.status != 'archived'`,
    [orgId, schoolId, academicYearId],
  );

  const teacherNames = await db.queryObject<{ id: string; display_name: string }>(
    `SELECT u.id, COALESCE(u.display_name, u.phone, u.id::text) AS display_name
     FROM users u
     JOIN school_memberships sm ON sm.user_id = u.id
     WHERE sm.school_id = $1`,
    [schoolId],
  );
  const nameMap = new Map(teacherNames.map((t) => [t.id, t.display_name]));

  const workloadMap = new Map<string, { count: number; sections: Set<string> }>();
  const slotMap = new Map<string, Set<string>>();

  for (const p of periods) {
    if (p.teacher_id) {
      const entry = workloadMap.get(p.teacher_id) ?? { count: 0, sections: new Set() };
      entry.count += 1;
      const tt = timetables.find((t) => t.id === p.timetable_id);
      if (tt) entry.sections.add(tt.section_id);
      workloadMap.set(p.teacher_id, entry);

      const slotKey = `${p.teacher_id}:${p.day_of_week}:${p.period_number}`;
      const sections = slotMap.get(slotKey) ?? new Set();
      sections.add(p.timetable_id);
      slotMap.set(slotKey, sections);
    }
  }

  const conflicts: TimetableValidationResult["conflicts"] = [];
  for (const [slotKey, timetableIds] of slotMap) {
    if (timetableIds.size > 1) {
      const [teacherId, day, period] = slotKey.split(":");
      conflicts.push({
        type: "teacher",
        message: `Teacher double-booked on day ${day} period ${period}`,
        dayOfWeek: Number(day),
        periodNumber: Number(period),
        entityId: teacherId!,
        timetableIds: [...timetableIds],
        sectionIds: [],
      });
    }
  }

  const workload: TeacherWorkloadEntry[] = [];
  const overloadAlerts: TimetableOptimizationResult["overloadAlerts"] = [];
  const freePeriodAnalysis: TimetableOptimizationResult["freePeriodAnalysis"] = [];

  for (const [teacherId, data] of workloadMap) {
    const isOverloaded = data.count > OVERLOAD_THRESHOLD;
    workload.push({
      teacherId,
      teacherName: nameMap.get(teacherId) ?? teacherId,
      periodCount: data.count,
      sections: [...data.sections],
      isOverloaded,
    });
    if (isOverloaded) {
      overloadAlerts.push({
        teacherId,
        teacherName: nameMap.get(teacherId) ?? teacherId,
        periodCount: data.count,
      });
    }
    const freePeriods = Math.max(0, EXPECTED_WEEKLY_PERIODS - data.count);
    if (freePeriods > 5) {
      freePeriodAnalysis.push({
        teacherId,
        teacherName: nameMap.get(teacherId) ?? teacherId,
        freePeriods,
      });
    }
  }

  const gapCount = Math.max(0, timetables.length * 30 - periods.length);
  const summary: TimetableSummary = {
    academicYearId,
    totalTimetables: timetables.length,
    draftCount: timetables.filter((t) => t.status === "draft").length,
    validatedCount: timetables.filter((t) => t.status === "validated").length,
    publishedCount: timetables.filter((t) => t.status === "published").length,
    conflictCount: conflicts.length,
    gapCount,
    overloadedTeacherCount: overloadAlerts.length,
  };

  const validation: TimetableValidationResult = {
    valid: conflicts.length === 0,
    conflictCount: conflicts.length,
    gapCount,
    conflicts,
    gaps: [],
  };

  const recommendations: ActionableRecommendation[] =
    buildSchedulingRecommendations({ validation, workload, summary });

  // P0-2 — the explanatory recommendations above are all readOnly (no id to
  // act on), so "Apply"/"Apply All" in TimetableOptimizationScreen had nothing
  // to do. Append ONE genuinely actionable recommendation per overloaded
  // teacher: applyTimetableOptimization moves a real period off their grid.
  for (const alert of overloadAlerts) {
    recommendations.push({
      kind: "redistribute_workload",
      title: `Rebalance ${alert.teacherName}'s schedule`,
      detail:
        `Move one period from ${alert.teacherName} (${alert.periodCount} periods) to a lighter-loaded, subject-qualified teacher.`,
      readOnly: false,
      recommendationId: `rebalance_${alert.teacherId}`,
    });
  }

  const substituteSuggestions = conflicts.slice(0, 5).map((c) => ({
    conflictMessage: c.message,
    suggestion: `Assign substitute teacher for ${nameMap.get(c.entityId) ?? c.entityId} or move period to free slot`,
  }));

  const qualityScore = computeQualityScore({
    conflictCount: conflicts.length,
    overloadCount: overloadAlerts.length,
    gapCount,
    timetableCount: timetables.length,
  });

  return {
    qualityScore,
    overloadAlerts,
    freePeriodAnalysis,
    conflictCount: conflicts.length,
    substituteSuggestions,
    recommendations,
  };
}

export function computeQualityScore(input: {
  conflictCount: number;
  overloadCount: number;
  gapCount: number;
  timetableCount: number;
}): number {
  if (input.timetableCount === 0) return 0;
  let score = 100;
  score -= input.conflictCount * 15;
  score -= input.overloadCount * 10;
  score -= Math.min(input.gapCount, 10) * 2;
  return Math.max(0, Math.min(100, score));
}

/**
 * Move ONE period off `overloadedTeacherId`'s grid onto the least-loaded other
 * teacher (preferring one already qualified in that subject), reusing the
 * SAME guarded write `handleReassignPeriodTeacher` uses
 * (reassignTimetablePeriodTeacher — published-immutability + clash-recheck).
 * Returns false (no-op, nothing thrown) when there is nothing safe to move —
 * e.g. every period is on a published timetable, or no lighter teacher exists
 * — so the caller can report a truthful "not applied" outcome per
 * recommendation instead of failing the whole batch.
 */
async function rebalanceOneTeacherPeriod(
  db: TenantQueryClient,
  orgId: string,
  schoolId: string,
  academicYearId: string,
  overloadedTeacherId: string,
): Promise<boolean> {
  const periodRows = await db.queryObject<{
    period_id: string;
    subject_label: string;
    status: string;
  }>(
    `SELECT p.id AS period_id, p.subject_label, t.status
     FROM academic_timetable_periods p
     JOIN academic_timetables t ON t.id = p.timetable_id
     WHERE t.organization_id = $1 AND t.school_id = $2 AND t.academic_year_id = $3
       AND t.status <> 'archived' AND p.teacher_id = $4
     ORDER BY p.day_of_week DESC, p.period_number DESC`,
    [orgId, schoolId, academicYearId, overloadedTeacherId],
  );
  const movable = periodRows.find((p) => p.status !== "published");
  if (!movable) return false;

  const workloadRows = await db.queryObject<{ teacher_id: string; cnt: number }>(
    `SELECT p.teacher_id, count(*)::int AS cnt
     FROM academic_timetable_periods p
     JOIN academic_timetables t ON t.id = p.timetable_id
     WHERE t.organization_id = $1 AND t.school_id = $2 AND t.academic_year_id = $3
       AND t.status <> 'archived' AND p.teacher_id IS NOT NULL AND p.teacher_id <> $4
     GROUP BY p.teacher_id`,
    [orgId, schoolId, academicYearId, overloadedTeacherId],
  );
  if (workloadRows.length === 0) return false;

  const subjectRows = await db.queryObject<{ teacher_id: string }>(
    `SELECT DISTINCT p.teacher_id
     FROM academic_timetable_periods p
     JOIN academic_timetables t ON t.id = p.timetable_id
     WHERE t.organization_id = $1 AND t.school_id = $2 AND t.academic_year_id = $3
       AND t.status <> 'archived' AND p.teacher_id <> $4 AND p.subject_label = $5`,
    [orgId, schoolId, academicYearId, overloadedTeacherId, movable.subject_label],
  );
  const subjectQualified = new Set(subjectRows.map((r) => r.teacher_id));

  const ranked = [...workloadRows].sort((a, b) => {
    const aQualified = subjectQualified.has(a.teacher_id) ? 0 : 1;
    const bQualified = subjectQualified.has(b.teacher_id) ? 0 : 1;
    if (aQualified !== bQualified) return aQualified - bQualified;
    return a.cnt - b.cnt;
  });
  const target = ranked[0];
  if (!target || target.cnt >= OVERLOAD_THRESHOLD) return false;

  try {
    await reassignTimetablePeriodTeacher(db, orgId, schoolId, {
      periodId: movable.period_id,
      teacherId: target.teacher_id,
    });
    return true;
  } catch {
    // A clash appeared between analysis and apply (or the grid changed
    // concurrently) — skip this recommendation, do not fail the whole batch.
    return false;
  }
}

/**
 * POST /school/timetables/optimize/apply. Applies the actionable subset of
 * `analyzeTimetableOptimization`'s recommendations (currently: "redistribute_
 * workload" per overloaded teacher) and re-analyzes so the caller sees the
 * real, post-write conflict count and quality score — not an echo.
 */
export async function applyTimetableOptimization(
  db: TenantQueryClient,
  orgId: string,
  schoolId: string,
  academicYearId: string,
  recommendationIds: string[],
  applyAll: boolean,
): Promise<ApplyTimetableOptimizationApi> {
  const current = await analyzeTimetableOptimization(db, orgId, schoolId, academicYearId);
  const actionable = current.recommendations.filter((r) => !r.readOnly && r.recommendationId);
  const allowedIds = new Set(actionable.map((r) => r.recommendationId!));
  const requestedIds = applyAll
    ? allowedIds
    : new Set(recommendationIds.filter((id) => allowedIds.has(id)));

  if (requestedIds.size === 0) {
    return {
      appliedRecommendationIds: [],
      appliedCount: 0,
      updatedConflictCount: current.conflictCount,
      updatedQualityScore: current.qualityScore,
      message: "No actionable recommendations selected.",
    };
  }

  const appliedRecommendationIds: string[] = [];
  for (const recommendationId of requestedIds) {
    if (!recommendationId.startsWith("rebalance_")) continue;
    const teacherId = recommendationId.slice("rebalance_".length);
    const applied = await rebalanceOneTeacherPeriod(db, orgId, schoolId, academicYearId, teacherId);
    if (applied) appliedRecommendationIds.push(recommendationId);
  }

  const updated = await analyzeTimetableOptimization(db, orgId, schoolId, academicYearId);
  return {
    appliedRecommendationIds,
    appliedCount: appliedRecommendationIds.length,
    updatedConflictCount: updated.conflictCount,
    updatedQualityScore: updated.qualityScore,
    message: appliedRecommendationIds.length > 0
      ? `${appliedRecommendationIds.length} recommendation(s) applied.`
      : "No matching recommendations could be applied (candidate periods were published or no lighter-loaded teacher was available).",
  };
}
