import type { TenantQueryClient } from "../tenant_db.ts";
import {
  buildClassLabel,
  listCanonicalTeacherClasses,
} from "../school_completion/subject_assignments_repository.ts";

export function periodTimeRange(periodNumber: number): string {
  const startHour = 7 + periodNumber;
  const endHour = startHour + 1;
  const pad = (value: number) => String(value).padStart(2, "0");
  return `${pad(startHour)}:30 - ${pad(endHour)}:15`;
}

// PRA-P0-07 (S3): a teacher's own classes come from the CANONICAL binding
// (`teacher_subject_assignments` + class-teacher `teacher_assignments`), NOT the
// unwritten `timetable_slots` (which is empty for every real tenant, so this used
// to return seed fiction or nothing). This is the seed of the whole teacher lane
// (roster, upcoming exams, exam marks), so repointing it repairs those readers.
export async function listTeacherClassLabels(
  db: TenantQueryClient,
  orgId: string,
  schoolId: string,
  teacherUserId: string,
): Promise<string[]> {
  const classes = await listCanonicalTeacherClasses(db, orgId, schoolId, teacherUserId);
  return classes.map((c) => buildClassLabel(c.class_name, c.section_name));
}
