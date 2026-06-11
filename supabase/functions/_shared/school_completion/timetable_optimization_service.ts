import type { TenantQueryClient } from "../tenant_db.ts";
import { buildSchedulingRecommendations } from "../timetable/timetable_scheduling_advisor.ts";
import type {
  SchedulingRecommendation,
  TeacherWorkloadEntry,
  TimetableSummary,
  TimetableValidationResult,
} from "../timetable/timetable_types.ts";

export interface TimetableOptimizationResult {
  qualityScore: number;
  overloadAlerts: Array<{ teacherId: string; teacherName: string; periodCount: number }>;
  freePeriodAnalysis: Array<{ teacherId: string; teacherName: string; freePeriods: number }>;
  conflictCount: number;
  substituteSuggestions: Array<{ conflictMessage: string; suggestion: string }>;
  recommendations: SchedulingRecommendation[];
}

const OVERLOAD_THRESHOLD = 24;
const EXPECTED_PERIODS = 20;

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
    const freePeriods = Math.max(0, EXPECTED_PERIODS - data.count);
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

  const recommendations = buildSchedulingRecommendations({ validation, workload, summary });

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
