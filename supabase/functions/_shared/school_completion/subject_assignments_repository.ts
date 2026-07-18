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

// ─── PRA-P0-07 / P0-08 / P0-11 (S3): canonical teacher↔class ownership ───────────
//
// One place answers "is teacher T (by JWT sub) bound to class C / subject S?"
// against the CANONICAL binding `teacher_subject_assignments` (the exam engine's
// oracle; `timetable_slots` has zero writers and must not be used). The pilot
// mobile-write lane (attendance/homework) and the pilot teacher reads both
// consume these, replacing the three rival, unwritten bindings.
//
// Two ownership questions, deliberately distinct:
//   • class-level  (attendance): the teacher teaches ANY subject in the class OR
//     is its class teacher — a form teacher who teaches no subject in their own
//     class must still be able to mark its attendance;
//   • subject-level (homework): the teacher teaches THAT subject in the class.
//
// NULL section on an assignment means "all sections of the class". Class/subject
// are matched by name (the pilot lane is text-keyed), the same bridge the exam
// oracle uses.

export interface CanonicalClassLabel {
  class_name: string;
  section_name: string | null;
}

/** Build the pilot `classLabel` ("10-A", or "10" when sectionless) from parts. */
export function buildClassLabel(className: string, sectionName: string | null): string {
  return sectionName ? `${className}-${sectionName}` : className;
}

/**
 * Class-level ownership (attendance). True when the teacher has an active
 * subject assignment for the class (any subject) OR is its class teacher.
 */
export async function teacherOwnsClass(
  db: TenantQueryClient,
  organizationId: string,
  schoolId: string,
  teacherUserId: string,
  className: string,
  sectionName: string | null,
): Promise<boolean> {
  const rows = await db.queryObject<{ owns: boolean }>(
    `SELECT (
        EXISTS (
          SELECT 1
          FROM teacher_subject_assignments tsa
          JOIN classes c ON c.id = tsa.class_id
          LEFT JOIN sections sec ON sec.id = tsa.section_id
          WHERE tsa.organization_id = $1 AND tsa.school_id = $2
            AND tsa.teacher_user_id = $3 AND tsa.status = 'active'
            AND c.class_name = $4
            AND ($5::text IS NULL OR sec.section_name IS NULL OR sec.section_name = $5)
        )
        OR EXISTS (
          SELECT 1
          FROM teacher_assignments ta
          JOIN sections sec ON sec.id = ta.section_id
          JOIN classes c ON c.id = sec.class_id
          WHERE ta.organization_id = $1 AND ta.school_id = $2
            AND ta.teacher_id = $3 AND ta.role = 'class_teacher'
            AND c.class_name = $4
            AND ($5::text IS NULL OR sec.section_name = $5)
        )
     ) AS owns`,
    [organizationId, schoolId, teacherUserId, className, sectionName],
  );
  return rows[0]?.owns === true;
}

/**
 * Subject-level ownership (homework). True when the teacher has an active
 * subject assignment for that subject in the class. Subject is matched
 * case-insensitively to tolerate client label casing on the free-text pilot
 * subject (the P1-16 precision work removes the remaining name drift).
 */
export async function teacherOwnsClassSubject(
  db: TenantQueryClient,
  organizationId: string,
  schoolId: string,
  teacherUserId: string,
  className: string,
  sectionName: string | null,
  subjectName: string,
): Promise<boolean> {
  const rows = await db.queryObject<{ owns: boolean }>(
    `SELECT EXISTS (
        SELECT 1
        FROM teacher_subject_assignments tsa
        JOIN academic_subjects subj ON subj.id = tsa.subject_id
        JOIN classes c ON c.id = tsa.class_id
        LEFT JOIN sections sec ON sec.id = tsa.section_id
        WHERE tsa.organization_id = $1 AND tsa.school_id = $2
          AND tsa.teacher_user_id = $3 AND tsa.status = 'active'
          AND lower(btrim(subj.subject_name)) = lower(btrim($4))
          AND c.class_name = $5
          AND ($6::text IS NULL OR sec.section_name IS NULL OR sec.section_name = $6)
     ) AS owns`,
    [organizationId, schoolId, teacherUserId, subjectName, className, sectionName],
  );
  return rows[0]?.owns === true;
}

/**
 * The teacher's canonical class set (class teacher + subject assignments),
 * distinct, ordered — the replacement source for the pilot teacher readers that
 * used the unwritten `timetable_slots`.
 */
export async function listCanonicalTeacherClasses(
  db: TenantQueryClient,
  organizationId: string,
  schoolId: string,
  teacherUserId: string,
): Promise<CanonicalClassLabel[]> {
  return await db.queryObject<CanonicalClassLabel>(
    `SELECT DISTINCT c.class_name AS class_name, sec.section_name AS section_name
       FROM teacher_subject_assignments tsa
       JOIN classes c ON c.id = tsa.class_id
       LEFT JOIN sections sec ON sec.id = tsa.section_id
      WHERE tsa.organization_id = $1 AND tsa.school_id = $2
        AND tsa.teacher_user_id = $3 AND tsa.status = 'active'
      UNION
     SELECT DISTINCT c.class_name AS class_name, sec.section_name AS section_name
       FROM teacher_assignments ta
       JOIN sections sec ON sec.id = ta.section_id
       JOIN classes c ON c.id = sec.class_id
      WHERE ta.organization_id = $1 AND ta.school_id = $2
        AND ta.teacher_id = $3 AND ta.role = 'class_teacher'
      ORDER BY class_name, section_name`,
    [organizationId, schoolId, teacherUserId],
  );
}

export interface CanonicalClassSubject {
  class_label: string;
  subject_name: string;
}

/**
 * PRA-P1-16 (S3): the teacher's (class, subject) pairs from the CANONICAL
 * binding — the authority for "which subjects do I teach in this class",
 * replacing the free-text `timetable_slots.subject_label` matching that silently
 * mis-scoped on label drift ("Maths" vs "Mathematics"). `class_label` is built
 * to match the pilot convention ("10-A").
 */
export async function listCanonicalTeacherClassSubjects(
  db: TenantQueryClient,
  organizationId: string,
  schoolId: string,
  teacherUserId: string,
): Promise<CanonicalClassSubject[]> {
  return await db.queryObject<CanonicalClassSubject>(
    `SELECT DISTINCT
            (c.class_name || CASE WHEN sec.section_name IS NOT NULL
                                  THEN '-' || sec.section_name ELSE '' END) AS class_label,
            subj.subject_name AS subject_name
       FROM teacher_subject_assignments tsa
       JOIN academic_subjects subj ON subj.id = tsa.subject_id
       JOIN classes c ON c.id = tsa.class_id
       LEFT JOIN sections sec ON sec.id = tsa.section_id
      WHERE tsa.organization_id = $1 AND tsa.school_id = $2
        AND tsa.teacher_user_id = $3 AND tsa.status = 'active'`,
    [organizationId, schoolId, teacherUserId],
  );
}
