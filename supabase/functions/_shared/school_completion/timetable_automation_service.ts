import type { TenantQueryClient } from "../tenant_db.ts";
import { listSubjects } from "./subjects_repository.ts";
import { generateTimetablesForYear } from "../timetable/timetable_repository.ts";
import { getSchoolConflicts } from "../timetable/timetable_repository.ts";

export interface TimetableAutomationResult {
  timetablesCreated: number;
  subjectsUsed: string[];
  warnings: string[];
  conflictCount: number;
}

export async function runTimetableAutomation(
  db: TenantQueryClient,
  orgId: string,
  schoolId: string,
  academicYearId: string,
  createdBy: string,
  options: { periodsPerDay?: number; daysPerWeek?: number; sectionId?: string } = {},
): Promise<TimetableAutomationResult> {
  const subjects = await listSubjects(db, orgId, schoolId);
  const activeSubjects = subjects.filter((s) => s.status === "active");
  const subjectNames = activeSubjects.map((s) => s.subject_name);
  const warnings: string[] = [];

  if (subjectNames.length < 3) {
    warnings.push("Fewer than 3 active subjects — timetable will use default subject rotation");
  }

  const created = await generateTimetablesForYear(
    db,
    orgId,
    schoolId,
    academicYearId,
    createdBy,
    {
      ...options,
      subjects: subjectNames.length ? subjectNames : undefined,
    },
  );

  const conflicts = await getSchoolConflicts(db, orgId, schoolId, academicYearId);
  if (conflicts.length > 0) {
    warnings.push(`${conflicts.length} teacher scheduling conflicts detected — review before publish`);
  }

  return {
    timetablesCreated: created.length,
    subjectsUsed: subjectNames.length ? subjectNames : ["English", "Mathematics", "Science"],
    warnings,
    conflictCount: conflicts.length,
  };
}
