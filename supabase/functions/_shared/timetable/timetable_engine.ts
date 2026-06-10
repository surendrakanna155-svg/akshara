import type {
  TimetableConflict,
  TimetablePeriodInput,
  TimetableValidationResult,
} from "./timetable_types.ts";
import { DEFAULT_SUBJECTS } from "./timetable_types.ts";

export interface CatalogAssignment {
  assignmentId: string;
  teacherId: string;
  teacherName: string;
  sectionId: string;
  className: string;
  sectionName: string;
  role: string;
  isPrimary?: boolean;
}

export interface GenerationSectionContext {
  sectionId: string;
  className: string;
  sectionName: string;
  assignments: CatalogAssignment[];
}

export interface GenerationOptions {
  periodsPerDay: number;
  daysPerWeek: number;
  subjects?: string[];
}

function roomForSection(className: string, sectionName: string, subject: string): string {
  if (subject.toLowerCase().includes("computer") || subject.toLowerCase().includes("science")) {
    return `Lab ${className}-${sectionName}`;
  }
  return `Room ${className}${sectionName}`;
}

function pickTeacher(
  assignments: CatalogAssignment[],
  subjectIndex: number,
): CatalogAssignment | null {
  const subjectTeachers = assignments.filter((a) => a.role === "subject_teacher");
  if (subjectTeachers.length > 0) {
    return subjectTeachers[subjectIndex % subjectTeachers.length] ?? null;
  }
  const classTeacher = assignments.find((a) => a.role === "class_teacher" && a.isPrimary !== false);
  return classTeacher ?? assignments[0] ?? null;
}

/** Greedy period allocation from academic catalog teacher assignments. */
export function generateSectionPeriods(
  section: GenerationSectionContext,
  options: GenerationOptions,
): TimetablePeriodInput[] {
  const subjects = options.subjects?.length
    ? options.subjects
    : DEFAULT_SUBJECTS.slice(0, options.periodsPerDay);
  const periods: TimetablePeriodInput[] = [];
  let subjectIndex = 0;

  for (let day = 1; day <= options.daysPerWeek; day += 1) {
    for (let period = 1; period <= options.periodsPerDay; period += 1) {
      const subjectLabel = subjects[(subjectIndex + period - 1) % subjects.length]!;
      const teacher = pickTeacher(section.assignments, subjectIndex);
      periods.push({
        dayOfWeek: day,
        periodNumber: period,
        subjectLabel,
        teacherId: teacher?.teacherId ?? null,
        teacherAssignmentId: teacher?.assignmentId ?? null,
        roomLabel: roomForSection(section.className, section.sectionName, subjectLabel),
      });
      subjectIndex += 1;
    }
  }

  return periods;
}

export interface PeriodWithMeta extends TimetablePeriodInput {
  timetableId: string;
  sectionId: string;
}

export function detectTeacherConflicts(periods: PeriodWithMeta[]): TimetableConflict[] {
  const map = new Map<string, PeriodWithMeta[]>();
  for (const period of periods) {
    if (!period.teacherId) continue;
    const key = `${period.teacherId}:${period.dayOfWeek}:${period.periodNumber}`;
    const bucket = map.get(key) ?? [];
    bucket.push(period);
    map.set(key, bucket);
  }

  const conflicts: TimetableConflict[] = [];
  for (const [key, bucket] of map.entries()) {
    if (bucket.length < 2) continue;
    const [teacherId] = key.split(":");
    conflicts.push({
      type: "teacher",
      message: `Teacher ${teacherId} has overlapping assignments`,
      dayOfWeek: bucket[0]!.dayOfWeek,
      periodNumber: bucket[0]!.periodNumber,
      entityId: teacherId!,
      timetableIds: [...new Set(bucket.map((p) => p.timetableId))],
      sectionIds: [...new Set(bucket.map((p) => p.sectionId))],
    });
  }
  return conflicts;
}

export function detectSectionConflicts(periods: PeriodWithMeta[]): TimetableConflict[] {
  const map = new Map<string, PeriodWithMeta[]>();
  for (const period of periods) {
    const key = `${period.sectionId}:${period.dayOfWeek}:${period.periodNumber}`;
    const bucket = map.get(key) ?? [];
    bucket.push(period);
    map.set(key, bucket);
  }

  const conflicts: TimetableConflict[] = [];
  for (const [key, bucket] of map.entries()) {
    if (bucket.length < 2) continue;
    const [sectionId] = key.split(":");
    conflicts.push({
      type: "section",
      message: `Section ${sectionId} has duplicate period slots`,
      dayOfWeek: bucket[0]!.dayOfWeek,
      periodNumber: bucket[0]!.periodNumber,
      entityId: sectionId!,
      timetableIds: [...new Set(bucket.map((p) => p.timetableId))],
      sectionIds: [sectionId!],
    });
  }
  return conflicts;
}

export function detectRoomConflicts(periods: PeriodWithMeta[]): TimetableConflict[] {
  const map = new Map<string, PeriodWithMeta[]>();
  for (const period of periods) {
    if (!period.roomLabel.trim()) continue;
    const key =
      `${period.roomLabel.trim().toLowerCase()}:${period.dayOfWeek}:${period.periodNumber}`;
    const bucket = map.get(key) ?? [];
    bucket.push(period);
    map.set(key, bucket);
  }

  const conflicts: TimetableConflict[] = [];
  for (const [key, bucket] of map.entries()) {
    if (bucket.length < 2) continue;
    const room = bucket[0]!.roomLabel;
    conflicts.push({
      type: "room",
      message: `Room ${room} is double-booked`,
      dayOfWeek: bucket[0]!.dayOfWeek,
      periodNumber: bucket[0]!.periodNumber,
      entityId: room,
      timetableIds: [...new Set(bucket.map((p) => p.timetableId))],
      sectionIds: [...new Set(bucket.map((p) => p.sectionId))],
    });
  }
  return conflicts;
}

export function detectAllConflicts(periods: PeriodWithMeta[]): TimetableConflict[] {
  return [
    ...detectTeacherConflicts(periods),
    ...detectSectionConflicts(periods),
    ...detectRoomConflicts(periods),
  ];
}

export function findTimetableGaps(
  sectionId: string,
  periods: TimetablePeriodInput[],
  periodsPerDay: number,
  daysPerWeek: number,
): Array<{ sectionId: string; dayOfWeek: number; periodNumber: number }> {
  const filled = new Set(
    periods.map((p) => `${p.dayOfWeek}:${p.periodNumber}`),
  );
  const gaps: Array<{ sectionId: string; dayOfWeek: number; periodNumber: number }> = [];
  for (let day = 1; day <= daysPerWeek; day += 1) {
    for (let period = 1; period <= periodsPerDay; period += 1) {
      if (!filled.has(`${day}:${period}`)) {
        gaps.push({ sectionId, dayOfWeek: day, periodNumber: period });
      }
    }
  }
  return gaps;
}

export function validateTimetablePeriods(
  sectionId: string,
  timetableId: string,
  periods: TimetablePeriodInput[],
  periodsPerDay: number,
  daysPerWeek: number,
  allSchoolPeriods: PeriodWithMeta[] = [],
): TimetableValidationResult {
  const scoped = periods.map((period) => ({
    ...period,
    timetableId,
    sectionId,
  }));
  const combined = [...allSchoolPeriods.filter((p) => p.timetableId !== timetableId), ...scoped];
  const conflicts = detectAllConflicts(combined);
  const gaps = findTimetableGaps(sectionId, periods, periodsPerDay, daysPerWeek);
  return {
    valid: conflicts.length === 0 && gaps.length === 0,
    conflictCount: conflicts.length,
    gapCount: gaps.length,
    conflicts,
    gaps,
  };
}
