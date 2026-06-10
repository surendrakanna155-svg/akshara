import type {
  SchedulingRecommendation,
  TimetableConflict,
  TimetableSummary,
  TimetableValidationResult,
} from "./timetable_types.ts";
import type { TeacherWorkloadEntry } from "./timetable_types.ts";

export function buildSchedulingRecommendations(input: {
  validation: TimetableValidationResult;
  workload: TeacherWorkloadEntry[];
  summary: TimetableSummary;
}): SchedulingRecommendation[] {
  const recommendations: SchedulingRecommendation[] = [];

  for (const conflict of input.validation.conflicts.slice(0, 5)) {
    recommendations.push(explainConflict(conflict));
  }

  for (const teacher of input.workload.filter((w) => w.isOverloaded).slice(0, 3)) {
    recommendations.push({
      kind: "overloaded_teacher",
      title: `Overloaded: ${teacher.teacherName}`,
      detail:
        `${teacher.teacherName} has ${teacher.periodCount} assigned periods (threshold exceeded). Consider redistributing subjects to other subject teachers.`,
      readOnly: true,
    });
  }

  if (input.summary.gapCount > 0) {
    recommendations.push({
      kind: "timetable_gap",
      title: "Timetable gaps detected",
      detail:
        `${input.summary.gapCount} empty period slots remain across draft timetables. Fill gaps before publishing.`,
      readOnly: true,
    });
  }

  const underloaded = input.workload.filter((w) => w.periodCount > 0 && w.periodCount < 10);
  const overloaded = input.workload.filter((w) => w.isOverloaded);
  if (underloaded.length > 0 && overloaded.length > 0) {
    recommendations.push({
      kind: "balance_teachers",
      title: "Rebalance teacher workload",
      detail:
        `${overloaded.length} teachers are overloaded while ${underloaded.length} have lighter schedules. Shift subject periods from overloaded teachers where catalog assignments allow.`,
      readOnly: true,
    });
  }

  if (recommendations.length === 0 && input.summary.conflictCount === 0) {
    recommendations.push({
      kind: "balance_teachers",
      title: "Timetable looks balanced",
      detail: "No major conflicts or overload signals detected in the current draft set.",
      readOnly: true,
    });
  }

  return recommendations;
}

function explainConflict(conflict: TimetableConflict): SchedulingRecommendation {
  const detail = switchConflictMessage(conflict);
  return {
    kind: "explain_conflict",
    title: `${conflict.type} conflict — Day ${conflict.dayOfWeek} P${conflict.periodNumber}`,
    detail,
    readOnly: true,
  };
}

function switchConflictMessage(conflict: TimetableConflict): string {
  switch (conflict.type) {
    case "teacher":
      return conflict.message +
        `. Affected sections: ${conflict.sectionIds.join(", ")}. Resolve by moving one period to a free slot or assigning a substitute teacher.`;
    case "section":
      return conflict.message + ". Remove duplicate period entries for the section.";
    case "room":
      return conflict.message +
        ". Assign an alternate room or shift one class to a different period.";
  }
}
