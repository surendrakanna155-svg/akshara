import type { TenantQueryClient } from "../tenant_db.ts";
import { getSection } from "./sections_repository.ts";
import {
  clampPageSize,
  offsetFor,
  type PaginationParams,
  type PaginationResult,
} from "./academic_pagination.ts";

export const ACADEMIC_TEACHER_ASSIGNMENT_SCHOOL_A =
  "d2000000-0000-4000-8000-000000000001";
export const ACADEMIC_TEACHER_ASSIGNMENT_SCHOOL_B =
  "d2000000-0000-4000-8000-000000000002";

/** Join active teacher membership in assignment school; name from membership snapshot. */
export const TEACHER_ASSIGNMENT_NAME_JOIN = `
  LEFT JOIN school_memberships sm_teacher
    ON sm_teacher.user_id = ta.teacher_id
    AND sm_teacher.school_id = ta.school_id
    AND sm_teacher.role = 'teacher'
    AND sm_teacher.status = 'active'
`;

/** SQL fragment used by tenant isolation probes for teacher assignment visibility. */
export const ACADEMIC_TEACHER_ASSIGNMENTS_PROBE_SQL = `
  SELECT count(*)::text AS count
  FROM teacher_assignments
`;

/** SQL fragment used by API-layer tenant isolation probes (list). */
export const ACADEMIC_TEACHER_ASSIGNMENTS_API_PROBE_SQL = `
  SELECT count(*)::text AS count
  FROM teacher_assignments ta
  INNER JOIN sections s ON s.id = ta.section_id
  INNER JOIN classes c ON c.id = s.class_id
  INNER JOIN school_memberships sm_teacher
    ON sm_teacher.user_id = ta.teacher_id
    AND sm_teacher.school_id = ta.school_id
    AND sm_teacher.role = 'teacher'
    AND sm_teacher.status = 'active'
  WHERE ta.organization_id = app_current_tenant_id()
    AND ta.school_id = app_current_school_id()
`;

/** SQL fragment used by API-layer tenant isolation probes (detail/update by id). */
export const ACADEMIC_TEACHER_ASSIGNMENT_DETAIL_PROBE_SQL = `
  SELECT count(*)::text AS count
  FROM teacher_assignments ta
  INNER JOIN sections s ON s.id = ta.section_id
  INNER JOIN classes c ON c.id = s.class_id
  INNER JOIN school_memberships sm_teacher
    ON sm_teacher.user_id = ta.teacher_id
    AND sm_teacher.school_id = ta.school_id
    AND sm_teacher.role = 'teacher'
    AND sm_teacher.status = 'active'
  WHERE ta.id = $1
`;

export type TeacherAssignmentRole =
  | "class_teacher"
  | "subject_teacher"
  | "coordinator";

export interface TeacherAssignmentRow {
  id: string;
  organization_id: string;
  school_id: string;
  teacher_id: string;
  section_id: string;
  role: TeacherAssignmentRole;
  is_primary: boolean;
  created_by: string | null;
  created_at: string;
  updated_at: string;
}

export interface TeacherAssignmentWithSectionRow extends TeacherAssignmentRow {
  class_id: string;
  class_name: string;
  section_name: string;
}

export interface TeacherAssignmentListRow extends TeacherAssignmentWithSectionRow {
  teacher_name: string;
}

export interface TeacherAssignmentListFilters {
  sectionId?: string;
  teacherId?: string;
  classId?: string;
  role?: TeacherAssignmentRole;
}

export interface CreateTeacherAssignmentInput {
  teacherId: string;
  sectionId: string;
  role: TeacherAssignmentRole;
  isPrimary?: boolean;
  createdBy: string;
}

export interface UpdateTeacherAssignmentInput {
  teacherId?: string;
  sectionId?: string;
  role?: TeacherAssignmentRole;
  isPrimary?: boolean;
}

export class TeacherAssignmentNotFoundError extends Error {
  constructor(id: string) {
    super(`Teacher assignment not found: ${id}`);
    this.name = "TeacherAssignmentNotFoundError";
  }
}

export class DuplicatePrimaryClassTeacherError extends Error {
  constructor(sectionId: string) {
    super(`Primary class teacher already assigned for section ${sectionId}`);
    this.name = "DuplicatePrimaryClassTeacherError";
  }
}

export class ValidationError extends Error {
  constructor(message: string) {
    super(message);
    this.name = "ValidationError";
  }
}

function isDuplicatePrimaryClassTeacherError(error: unknown): boolean {
  const message = String(error);
  return message.includes("teacher_assignments_one_primary_class_teacher") ||
    (message.includes("duplicate key") && message.includes("is_primary"));
}

async function assertSectionInSchool(
  db: TenantQueryClient,
  organizationId: string,
  schoolId: string,
  sectionId: string,
): Promise<{ class_id: string; school_id: string }> {
  const section = await getSection(db, organizationId, schoolId, sectionId);
  if (!section) {
    throw new ValidationError(`Section not found in school scope: ${sectionId}`);
  }
  return { class_id: section.class_id, school_id: section.school_id };
}

async function assertTeacherMembership(
  db: TenantQueryClient,
  schoolId: string,
  teacherId: string,
): Promise<void> {
  const rows = await db.queryObject<{ count: string }>(
    `SELECT count(*)::text AS count
     FROM school_memberships
     WHERE user_id = $1 AND school_id = $2 AND role = 'teacher' AND status = 'active'`,
    [teacherId, schoolId],
  );
  if (parseInt(rows[0]?.count ?? "0", 10) === 0) {
    throw new ValidationError(`Teacher is not an active member of school: ${teacherId}`);
  }
}

export async function listTeacherAssignments(
  db: TenantQueryClient,
  organizationId: string,
  schoolId: string,
  filters: TeacherAssignmentListFilters = {},
): Promise<TeacherAssignmentListRow[]> {
  const result = await listTeacherAssignmentsPage(
    db,
    organizationId,
    schoolId,
    filters,
    { page: 1, pageSize: 1000 },
  );
  return result.items;
}

export async function listTeacherAssignmentsPage(
  db: TenantQueryClient,
  organizationId: string,
  schoolId: string,
  filters: TeacherAssignmentListFilters,
  pagination: PaginationParams,
): Promise<PaginationResult<TeacherAssignmentListRow>> {
  const limit = clampPageSize(pagination.pageSize);
  const offset = offsetFor(pagination.page, limit);
  const args: unknown[] = [organizationId, schoolId];
  const conditions = ["ta.organization_id = $1", "ta.school_id = $2"];

  if (filters.sectionId) {
    conditions.push(`ta.section_id = $${args.length + 1}`);
    args.push(filters.sectionId);
  }
  if (filters.teacherId) {
    conditions.push(`ta.teacher_id = $${args.length + 1}`);
    args.push(filters.teacherId);
  }
  if (filters.classId) {
    conditions.push(`s.class_id = $${args.length + 1}`);
    args.push(filters.classId);
  }
  if (filters.role) {
    conditions.push(`ta.role = $${args.length + 1}`);
    args.push(filters.role);
  }

  const where = conditions.join(" AND ");
  const total = await db.queryCount(
    `SELECT count(*)::text AS count
     FROM teacher_assignments ta
     INNER JOIN sections s ON s.id = ta.section_id
     INNER JOIN classes c ON c.id = s.class_id
     WHERE ${where}`,
    args,
  );
  const items = await db.queryObject<TeacherAssignmentListRow>(
    `SELECT
       ta.*,
       s.class_id,
       c.class_name,
       s.section_name,
       sm_teacher.member_display_name AS teacher_name
     FROM teacher_assignments ta
     INNER JOIN sections s ON s.id = ta.section_id
     INNER JOIN classes c ON c.id = s.class_id
     ${TEACHER_ASSIGNMENT_NAME_JOIN}
     WHERE ${where}
     ORDER BY ta.created_at DESC
     LIMIT $${args.length + 1} OFFSET $${args.length + 2}`,
    [...args, limit, offset],
  );

  return {
    items,
    total,
    page: pagination.page,
    pageSize: limit,
    hasMore: offset + items.length < total,
  };
}

export async function getTeacherAssignmentWithDetails(
  db: TenantQueryClient,
  organizationId: string,
  schoolId: string,
  assignmentId: string,
): Promise<TeacherAssignmentListRow | null> {
  const rows = await db.queryObject<TeacherAssignmentListRow>(
    `SELECT
       ta.*,
       s.class_id,
       c.class_name,
       s.section_name,
       sm_teacher.member_display_name AS teacher_name
     FROM teacher_assignments ta
     INNER JOIN sections s ON s.id = ta.section_id
     INNER JOIN classes c ON c.id = s.class_id
     ${TEACHER_ASSIGNMENT_NAME_JOIN}
     WHERE ta.id = $1 AND ta.organization_id = $2 AND ta.school_id = $3`,
    [assignmentId, organizationId, schoolId],
  );
  return rows[0] ?? null;
}

export async function getTeacherAssignment(
  db: TenantQueryClient,
  organizationId: string,
  schoolId: string,
  assignmentId: string,
): Promise<TeacherAssignmentRow | null> {
  const rows = await db.queryObject<TeacherAssignmentRow>(
    `SELECT * FROM teacher_assignments
     WHERE id = $1 AND organization_id = $2 AND school_id = $3`,
    [assignmentId, organizationId, schoolId],
  );
  return rows[0] ?? null;
}

export async function createTeacherAssignment(
  db: TenantQueryClient,
  organizationId: string,
  schoolId: string,
  input: CreateTeacherAssignmentInput,
): Promise<TeacherAssignmentRow> {
  await assertSectionInSchool(db, organizationId, schoolId, input.sectionId);
  await assertTeacherMembership(db, schoolId, input.teacherId);

  const isPrimary = input.isPrimary ?? false;
  if (input.role === "class_teacher" && isPrimary) {
    await clearPrimaryClassTeacher(db, organizationId, schoolId, input.sectionId);
  }

  try {
    const rows = await db.queryObject<TeacherAssignmentRow>(
      `INSERT INTO teacher_assignments (
        organization_id, school_id, teacher_id, section_id, role, is_primary, created_by
      ) VALUES ($1, $2, $3, $4, $5, $6, $7)
      RETURNING *`,
      [
        organizationId,
        schoolId,
        input.teacherId,
        input.sectionId,
        input.role,
        isPrimary,
        input.createdBy,
      ],
    );
    return rows[0]!;
  } catch (error) {
    if (isDuplicatePrimaryClassTeacherError(error)) {
      throw new DuplicatePrimaryClassTeacherError(input.sectionId);
    }
    throw error;
  }
}

export async function updateTeacherAssignment(
  db: TenantQueryClient,
  organizationId: string,
  schoolId: string,
  assignmentId: string,
  input: UpdateTeacherAssignmentInput,
): Promise<TeacherAssignmentRow> {
  const existing = await getTeacherAssignment(db, organizationId, schoolId, assignmentId);
  if (!existing) throw new TeacherAssignmentNotFoundError(assignmentId);

  const nextSectionId = input.sectionId ?? existing.section_id;
  const nextTeacherId = input.teacherId ?? existing.teacher_id;
  const nextRole = input.role ?? existing.role;
  const nextPrimary = input.isPrimary ?? existing.is_primary;

  if (input.sectionId) {
    await assertSectionInSchool(db, organizationId, schoolId, input.sectionId);
  }
  if (input.teacherId) {
    await assertTeacherMembership(db, schoolId, nextTeacherId);
  }

  if (nextRole === "class_teacher" && nextPrimary) {
    await clearPrimaryClassTeacher(
      db,
      organizationId,
      schoolId,
      nextSectionId,
      assignmentId,
    );
  }

  try {
    const rows = await db.queryObject<TeacherAssignmentRow>(
      `UPDATE teacher_assignments SET
        teacher_id = $4,
        section_id = $5,
        role = $6,
        is_primary = $7,
        updated_at = timezone('utc', now())
       WHERE id = $1 AND organization_id = $2 AND school_id = $3
       RETURNING *`,
      [
        assignmentId,
        organizationId,
        schoolId,
        nextTeacherId,
        nextSectionId,
        nextRole,
        nextPrimary,
      ],
    );
    return rows[0]!;
  } catch (error) {
    if (isDuplicatePrimaryClassTeacherError(error)) {
      throw new DuplicatePrimaryClassTeacherError(nextSectionId);
    }
    throw error;
  }
}

async function clearPrimaryClassTeacher(
  db: TenantQueryClient,
  organizationId: string,
  schoolId: string,
  sectionId: string,
  exceptId?: string,
): Promise<void> {
  const args: unknown[] = [organizationId, schoolId, sectionId];
  let sql = `UPDATE teacher_assignments
             SET is_primary = false, updated_at = timezone('utc', now())
             WHERE organization_id = $1 AND school_id = $2 AND section_id = $3
               AND role = 'class_teacher' AND is_primary = true`;
  if (exceptId) {
    sql += ` AND id <> $4`;
    args.push(exceptId);
  }
  await db.queryObject(sql, args);
}
