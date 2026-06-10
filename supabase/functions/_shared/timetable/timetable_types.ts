export type TimetableStatus = "draft" | "validated" | "published" | "archived";

export type TimetableConflictType = "teacher" | "section" | "room";

export interface TimetablePeriodInput {
  dayOfWeek: number;
  periodNumber: number;
  subjectLabel: string;
  teacherId: string | null;
  teacherAssignmentId: string | null;
  roomLabel: string;
}

export interface TimetablePeriodRow extends TimetablePeriodInput {
  id: string;
  timetableId: string;
}

export interface TimetableRow {
  id: string;
  organization_id: string;
  school_id: string;
  academic_year_id: string;
  section_id: string;
  status: TimetableStatus;
  version: number;
  periods_per_day: number;
  days_per_week: number;
  validation_summary: Record<string, unknown>;
  published_at: string | null;
  created_by: string | null;
  created_at: string;
  updated_at: string;
}

export interface TimetableConflict {
  type: TimetableConflictType;
  message: string;
  dayOfWeek: number;
  periodNumber: number;
  entityId: string;
  timetableIds: string[];
  sectionIds: string[];
}

export interface TeacherWorkloadEntry {
  teacherId: string;
  teacherName: string;
  periodCount: number;
  sections: string[];
  isOverloaded: boolean;
}

export interface TimetableSummary {
  academicYearId: string;
  totalTimetables: number;
  draftCount: number;
  validatedCount: number;
  publishedCount: number;
  conflictCount: number;
  gapCount: number;
  overloadedTeacherCount: number;
}

export interface TimetableValidationResult {
  valid: boolean;
  conflictCount: number;
  gapCount: number;
  conflicts: TimetableConflict[];
  gaps: Array<{ sectionId: string; dayOfWeek: number; periodNumber: number }>;
}

export interface SchedulingRecommendation {
  kind:
    | "explain_conflict"
    | "balance_teachers"
    | "redistribute_workload"
    | "overloaded_teacher"
    | "timetable_gap";
  title: string;
  detail: string;
  readOnly: true;
}

export const DEFAULT_SUBJECTS = [
  "Mathematics",
  "English",
  "Science",
  "Social Studies",
  "Computer Science",
  "Activity",
];
