import type { TeacherWorkloadEntry, TimetablePeriodInput } from "./timetable_types.ts";
import type { PeriodWithMeta } from "./timetable_engine.ts";

export const TEACHER_OVERLOAD_THRESHOLD = 24;

export function calculateTeacherWorkload(
  periods: Array<
    TimetablePeriodInput & {
      teacherName?: string | null;
    }
  >,
): TeacherWorkloadEntry[] {
  const map = new Map<string, TeacherWorkloadEntry>();

  for (const period of periods) {
    if (!period.teacherId) continue;
    const existing = map.get(period.teacherId) ?? {
      teacherId: period.teacherId,
      teacherName: period.teacherName?.trim() || period.teacherId,
      periodCount: 0,
      sections: [],
      isOverloaded: false,
    };
    existing.periodCount += 1;
    map.set(period.teacherId, existing);
  }

  return [...map.values()]
    .map((entry) => ({
      ...entry,
      isOverloaded: entry.periodCount > TEACHER_OVERLOAD_THRESHOLD,
    }))
    .sort((a, b) => b.periodCount - a.periodCount);
}

export function workloadFromSchoolPeriods(
  periods: PeriodWithMeta[],
  teacherNames: Map<string, string>,
): TeacherWorkloadEntry[] {
  return calculateTeacherWorkload(
    periods.map((period) => ({
      ...period,
      teacherName: period.teacherId ? teacherNames.get(period.teacherId) ?? period.teacherId : null,
    })),
  );
}

export function countOverloadedTeachers(entries: TeacherWorkloadEntry[]): number {
  return entries.filter((entry) => entry.isOverloaded).length;
}
