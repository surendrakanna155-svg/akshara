import type { TenantQueryClient } from "../tenant_db.ts";

export interface ClassSubjectAssignmentRow {
  id: string;
  organization_id: string;
  school_id: string;
  academic_year_id: string;
  class_id: string;
  section_id: string | null;
  subject_id: string;
  is_elective: boolean;
  periods_per_week: number;
  status: string;
  created_at: string;
  updated_at: string;
}

export interface TeacherSubjectAssignmentRow {
  id: string;
  organization_id: string;
  school_id: string;
  academic_year_id: string;
  teacher_user_id: string;
  subject_id: string;
  class_id: string | null;
  section_id: string | null;
  periods_per_week: number;
  is_primary: boolean;
  status: string;
  created_at: string;
  updated_at: string;
}

export interface CreateClassSubjectInput {
  academicYearId: string;
  classId: string;
  sectionId?: string | null;
  subjectId: string;
  isElective?: boolean;
  periodsPerWeek?: number;
  createdBy: string;
}

export interface CreateTeacherSubjectInput {
  academicYearId: string;
  teacherUserId: string;
  subjectId: string;
  classId?: string | null;
  sectionId?: string | null;
  periodsPerWeek?: number;
  isPrimary?: boolean;
  createdBy: string;
}

export class SubjectAssignmentValidationError extends Error {
  constructor(message: string) {
    super(message);
    this.name = "SubjectAssignmentValidationError";
  }
}

export async function listClassSubjectAssignments(
  db: TenantQueryClient,
  orgId: string,
  schoolId: string,
  academicYearId?: string,
): Promise<ClassSubjectAssignmentRow[]> {
  if (academicYearId) {
    return await db.queryObject<ClassSubjectAssignmentRow>(
      `SELECT * FROM class_subject_assignments
       WHERE organization_id = $1 AND school_id = $2 AND academic_year_id = $3
       ORDER BY class_id, section_id NULLS FIRST, subject_id`,
      [orgId, schoolId, academicYearId],
    );
  }
  return await db.queryObject<ClassSubjectAssignmentRow>(
    `SELECT * FROM class_subject_assignments
     WHERE organization_id = $1 AND school_id = $2
     ORDER BY class_id, section_id NULLS FIRST, subject_id`,
    [orgId, schoolId],
  );
}

export async function createClassSubjectAssignment(
  db: TenantQueryClient,
  orgId: string,
  schoolId: string,
  input: CreateClassSubjectInput,
): Promise<ClassSubjectAssignmentRow> {
  const duplicate = await db.queryObject<{ id: string }>(
    `SELECT id FROM class_subject_assignments
     WHERE organization_id = $1 AND school_id = $2
       AND class_id = $3
       AND COALESCE(section_id, '00000000-0000-4000-8000-000000000000'::uuid)
           = COALESCE($4::uuid, '00000000-0000-4000-8000-000000000000'::uuid)
       AND subject_id = $5`,
    [orgId, schoolId, input.classId, input.sectionId ?? null, input.subjectId],
  );
  if (duplicate.length > 0) {
    throw new SubjectAssignmentValidationError(
      "Subject already assigned to this class/section",
    );
  }

  const rows = await db.queryObject<ClassSubjectAssignmentRow>(
    `INSERT INTO class_subject_assignments (
       organization_id, school_id, academic_year_id, class_id, section_id,
       subject_id, is_elective, periods_per_week, created_by
     ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9)
     RETURNING *`,
    [
      orgId,
      schoolId,
      input.academicYearId,
      input.classId,
      input.sectionId ?? null,
      input.subjectId,
      input.isElective ?? false,
      input.periodsPerWeek ?? 5,
      input.createdBy,
    ],
  );
  return rows[0]!;
}

export async function deleteClassSubjectAssignment(
  db: TenantQueryClient,
  orgId: string,
  schoolId: string,
  assignmentId: string,
): Promise<boolean> {
  const rows = await db.queryObject<{ id: string }>(
    `DELETE FROM class_subject_assignments
     WHERE id = $1 AND organization_id = $2 AND school_id = $3
     RETURNING id`,
    [assignmentId, orgId, schoolId],
  );
  return rows.length > 0;
}

export async function listTeacherSubjectAssignments(
  db: TenantQueryClient,
  orgId: string,
  schoolId: string,
  academicYearId?: string,
): Promise<TeacherSubjectAssignmentRow[]> {
  if (academicYearId) {
    return await db.queryObject<TeacherSubjectAssignmentRow>(
      `SELECT * FROM teacher_subject_assignments
       WHERE organization_id = $1 AND school_id = $2 AND academic_year_id = $3
       ORDER BY teacher_user_id, subject_id`,
      [orgId, schoolId, academicYearId],
    );
  }
  return await db.queryObject<TeacherSubjectAssignmentRow>(
    `SELECT * FROM teacher_subject_assignments
     WHERE organization_id = $1 AND school_id = $2
     ORDER BY teacher_user_id, subject_id`,
    [orgId, schoolId],
  );
}

export async function createTeacherSubjectAssignment(
  db: TenantQueryClient,
  orgId: string,
  schoolId: string,
  input: CreateTeacherSubjectInput,
): Promise<TeacherSubjectAssignmentRow> {
  const duplicate = await db.queryObject<{ id: string }>(
    `SELECT id FROM teacher_subject_assignments
     WHERE organization_id = $1 AND school_id = $2
       AND teacher_user_id = $3 AND subject_id = $4
       AND COALESCE(class_id, '00000000-0000-4000-8000-000000000000'::uuid)
           = COALESCE($5::uuid, '00000000-0000-4000-8000-000000000000'::uuid)
       AND COALESCE(section_id, '00000000-0000-4000-8000-000000000000'::uuid)
           = COALESCE($6::uuid, '00000000-0000-4000-8000-000000000000'::uuid)`,
    [
      orgId,
      schoolId,
      input.teacherUserId,
      input.subjectId,
      input.classId ?? null,
      input.sectionId ?? null,
    ],
  );
  if (duplicate.length > 0) {
    throw new SubjectAssignmentValidationError(
      "Teacher already assigned to this subject for the class/section",
    );
  }

  const rows = await db.queryObject<TeacherSubjectAssignmentRow>(
    `INSERT INTO teacher_subject_assignments (
       organization_id, school_id, academic_year_id, teacher_user_id, subject_id,
       class_id, section_id, periods_per_week, is_primary, created_by
     ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10)
     RETURNING *`,
    [
      orgId,
      schoolId,
      input.academicYearId,
      input.teacherUserId,
      input.subjectId,
      input.classId ?? null,
      input.sectionId ?? null,
      input.periodsPerWeek ?? 0,
      input.isPrimary ?? false,
      input.createdBy,
    ],
  );
  return rows[0]!;
}

export interface SubjectWorkloadEntry {
  teacherUserId: string;
  subjectId: string;
  totalPeriods: number;
  assignmentCount: number;
  isOverloaded: boolean;
}

export function computeSubjectWorkload(
  teacherAssignments: TeacherSubjectAssignmentRow[],
  overloadThreshold = 25,
): SubjectWorkloadEntry[] {
  const map = new Map<string, SubjectWorkloadEntry>();
  for (const row of teacherAssignments.filter((r) => r.status === "active")) {
    const key = `${row.teacher_user_id}:${row.subject_id}`;
    const existing = map.get(key);
    const periods = row.periods_per_week;
    if (existing) {
      existing.totalPeriods += periods;
      existing.assignmentCount += 1;
      existing.isOverloaded = existing.totalPeriods > overloadThreshold;
    } else {
      map.set(key, {
        teacherUserId: row.teacher_user_id,
        subjectId: row.subject_id,
        totalPeriods: periods,
        assignmentCount: 1,
        isOverloaded: periods > overloadThreshold,
      });
    }
  }
  return Array.from(map.values()).sort((a, b) => b.totalPeriods - a.totalPeriods);
}

export function classSubjectToApi(row: ClassSubjectAssignmentRow) {
  return {
    id: row.id,
    academicYearId: row.academic_year_id,
    classId: row.class_id,
    sectionId: row.section_id,
    subjectId: row.subject_id,
    isElective: row.is_elective,
    periodsPerWeek: row.periods_per_week,
    status: row.status,
  };
}

export function teacherSubjectToApi(row: TeacherSubjectAssignmentRow) {
  return {
    id: row.id,
    academicYearId: row.academic_year_id,
    teacherUserId: row.teacher_user_id,
    subjectId: row.subject_id,
    classId: row.class_id,
    sectionId: row.section_id,
    periodsPerWeek: row.periods_per_week,
    isPrimary: row.is_primary,
    status: row.status,
  };
}

export function workloadToApi(entry: SubjectWorkloadEntry) {
  return {
    teacherUserId: entry.teacherUserId,
    subjectId: entry.subjectId,
    totalPeriods: entry.totalPeriods,
    assignmentCount: entry.assignmentCount,
    isOverloaded: entry.isOverloaded,
  };
}
