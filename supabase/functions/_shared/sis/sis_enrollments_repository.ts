import type { TenantQueryClient } from "../tenant_db.ts";
import type {
  PaginationParams,
  PaginationResult,
} from "../finance/finance_structures_repository.ts";
import { StudentNotFoundError } from "./sis_students_repository.ts";

export interface EnrollmentListFilters {
  academicYear?: string;
  className?: string;
  sectionName?: string;
  studentId?: string;
  isCurrent?: boolean;
}

export interface EnrollmentListRow {
  enrollment_id: string;
  student_id: string;
  student_code: string;
  student_name: string;
  academic_year: string;
  class_name: string;
  section_name: string | null;
  roll_number: string | null;
  is_current: boolean;
  created_at: string;
  updated_at: string;
}

export interface EnrollmentRow {
  id: string;
  organization_id: string;
  school_id: string;
  student_id: string;
  academic_year: string;
  class_name: string;
  section_name: string | null;
  roll_number: string | null;
  is_current: boolean;
  created_by: string | null;
  created_at: string;
  updated_at: string;
}

export interface CreateEnrollmentInput {
  studentId: string;
  academicYear: string;
  className: string;
  sectionName?: string | null;
  rollNumber?: string | null;
  isCurrent?: boolean;
  createdBy: string;
}

export interface UpdateEnrollmentInput {
  academicYear?: string;
  className?: string;
  sectionName?: string | null;
  rollNumber?: string | null;
  isCurrent?: boolean;
}

export class EnrollmentNotFoundError extends Error {
  constructor(id: string) {
    super(`Enrollment not found: ${id}`);
    this.name = "EnrollmentNotFoundError";
  }
}

export class DuplicateEnrollmentError extends Error {
  constructor(studentId: string, academicYear: string) {
    super(`Enrollment already exists for student ${studentId} in ${academicYear}`);
    this.name = "DuplicateEnrollmentError";
  }
}

export class ValidationError extends Error {
  constructor(message: string) {
    super(message);
    this.name = "ValidationError";
  }
}

function offsetFor(page: number, pageSize: number): number {
  return Math.max(0, (page - 1) * pageSize);
}

function listJoinSql(): string {
  return `FROM sis_student_enrollments se
  INNER JOIN students s
    ON s.id = se.student_id
   AND s.organization_id = se.organization_id
   AND s.school_id = se.school_id`;
}

function listFromSql(): string {
  return `SELECT
    se.id AS enrollment_id,
    se.student_id,
    s.student_code,
    s.display_name AS student_name,
    se.academic_year,
    se.class_name,
    se.section_name,
    se.roll_number,
    se.is_current,
    se.created_at,
    se.updated_at
  ${listJoinSql()}`;
}

function listWhereSql(): string {
  return `WHERE se.organization_id = $1
    AND se.school_id = $2
    AND ($3::text IS NULL OR se.academic_year = $3)
    AND ($4::text IS NULL OR se.class_name = $4)
    AND ($5::text IS NULL OR se.section_name = $5)
    AND ($6::uuid IS NULL OR se.student_id = $6)
    AND ($7::boolean IS NULL OR se.is_current = $7)`;
}

function filterArgs(
  organizationId: string,
  schoolId: string,
  filters: EnrollmentListFilters,
): unknown[] {
  return [
    organizationId,
    schoolId,
    filters.academicYear ?? null,
    filters.className ?? null,
    filters.sectionName ?? null,
    filters.studentId ?? null,
    filters.isCurrent ?? null,
  ];
}

async function studentExists(
  db: TenantQueryClient,
  organizationId: string,
  schoolId: string,
  studentId: string,
): Promise<boolean> {
  const rows = await db.queryObject<{ id: string }>(
    `SELECT id FROM students
     WHERE id = $1 AND organization_id = $2 AND school_id = $3`,
    [studentId, organizationId, schoolId],
  );
  return rows.length > 0;
}

async function enrollmentExistsForYear(
  db: TenantQueryClient,
  organizationId: string,
  schoolId: string,
  studentId: string,
  academicYear: string,
  excludeEnrollmentId?: string,
): Promise<boolean> {
  const rows = await db.queryObject<{ id: string }>(
    `SELECT id FROM sis_student_enrollments
     WHERE organization_id = $1 AND school_id = $2
       AND student_id = $3 AND academic_year = $4
       AND ($5::uuid IS NULL OR id <> $5)
     LIMIT 1`,
    [organizationId, schoolId, studentId, academicYear, excludeEnrollmentId ?? null],
  );
  return rows.length > 0;
}

export async function clearCurrentEnrollmentsForStudent(
  db: TenantQueryClient,
  organizationId: string,
  schoolId: string,
  studentId: string,
  exceptEnrollmentId?: string,
): Promise<void> {
  await db.queryObject(
    `UPDATE sis_student_enrollments SET
      is_current = false,
      updated_at = timezone('utc', now())
     WHERE organization_id = $1 AND school_id = $2 AND student_id = $3
       AND is_current = true
       AND ($4::uuid IS NULL OR id <> $4)`,
    [organizationId, schoolId, studentId, exceptEnrollmentId ?? null],
  );
}

async function getEnrollmentRow(
  db: TenantQueryClient,
  organizationId: string,
  schoolId: string,
  enrollmentId: string,
): Promise<EnrollmentRow | null> {
  const rows = await db.queryObject<EnrollmentRow>(
    `SELECT * FROM sis_student_enrollments
     WHERE id = $1 AND organization_id = $2 AND school_id = $3`,
    [enrollmentId, organizationId, schoolId],
  );
  return rows[0] ?? null;
}

async function getEnrollmentListRow(
  db: TenantQueryClient,
  organizationId: string,
  schoolId: string,
  enrollmentId: string,
): Promise<EnrollmentListRow | null> {
  const rows = await db.queryObject<EnrollmentListRow>(
    `${listFromSql()}
     WHERE se.id = $1 AND se.organization_id = $2 AND se.school_id = $3`,
    [enrollmentId, organizationId, schoolId],
  );
  return rows[0] ?? null;
}

export async function listEnrollments(
  db: TenantQueryClient,
  organizationId: string,
  schoolId: string,
  filters: EnrollmentListFilters,
  pagination: PaginationParams,
): Promise<PaginationResult<EnrollmentListRow>> {
  const limit = Math.min(Math.max(pagination.pageSize, 1), 100);
  const offset = offsetFor(pagination.page, limit);
  const args = filterArgs(organizationId, schoolId, filters);

  const total = await db.queryCount(
    `SELECT count(*)::text AS count
     ${listJoinSql()}
     ${listWhereSql()}`,
    args,
  );

  const items = await db.queryObject<EnrollmentListRow>(
    `${listFromSql()}
     ${listWhereSql()}
     ORDER BY se.is_current DESC, se.created_at DESC
     LIMIT $8 OFFSET $9`,
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

export async function createEnrollment(
  db: TenantQueryClient,
  organizationId: string,
  schoolId: string,
  input: CreateEnrollmentInput,
): Promise<EnrollmentListRow> {
  const studentId = input.studentId.trim();
  const academicYear = input.academicYear.trim();
  const className = input.className.trim();
  if (!studentId) throw new ValidationError("studentId is required");
  if (!academicYear) throw new ValidationError("academicYear is required");
  if (!className) throw new ValidationError("className is required");

  if (!await studentExists(db, organizationId, schoolId, studentId)) {
    throw new StudentNotFoundError(studentId);
  }

  if (await enrollmentExistsForYear(db, organizationId, schoolId, studentId, academicYear)) {
    throw new DuplicateEnrollmentError(studentId, academicYear);
  }

  const isCurrent = input.isCurrent ?? true;
  if (isCurrent) {
    await clearCurrentEnrollmentsForStudent(db, organizationId, schoolId, studentId);
  }

  const insertRows = await db.queryObject<{ id: string }>(
    `INSERT INTO sis_student_enrollments (
      organization_id, school_id, student_id, academic_year,
      class_name, section_name, roll_number, is_current, created_by
    ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9)
    RETURNING id`,
    [
      organizationId,
      schoolId,
      studentId,
      academicYear,
      className,
      input.sectionName ?? null,
      input.rollNumber ?? null,
      isCurrent,
      input.createdBy,
    ],
  );
  const enrollmentId = insertRows[0]!.id;

  const row = await getEnrollmentListRow(db, organizationId, schoolId, enrollmentId);
  if (!row) throw new EnrollmentNotFoundError(enrollmentId);
  return row;
}

export async function updateEnrollment(
  db: TenantQueryClient,
  organizationId: string,
  schoolId: string,
  enrollmentId: string,
  input: UpdateEnrollmentInput,
): Promise<EnrollmentListRow> {
  const existing = await getEnrollmentRow(db, organizationId, schoolId, enrollmentId);
  if (!existing) throw new EnrollmentNotFoundError(enrollmentId);

  const academicYear = input.academicYear?.trim() ?? existing.academic_year;
  const className = input.className?.trim() ?? existing.class_name;
  const sectionName = input.sectionName !== undefined
    ? input.sectionName
    : existing.section_name;
  const rollNumber = input.rollNumber !== undefined
    ? input.rollNumber
    : existing.roll_number;
  const isCurrent = input.isCurrent ?? existing.is_current;

  if (!academicYear) throw new ValidationError("academicYear cannot be empty");
  if (!className) throw new ValidationError("className cannot be empty");

  if (academicYear !== existing.academic_year &&
    await enrollmentExistsForYear(
      db,
      organizationId,
      schoolId,
      existing.student_id,
      academicYear,
      enrollmentId,
    )) {
    throw new DuplicateEnrollmentError(existing.student_id, academicYear);
  }

  if (isCurrent) {
    await clearCurrentEnrollmentsForStudent(
      db,
      organizationId,
      schoolId,
      existing.student_id,
      enrollmentId,
    );
  }

  await db.queryObject(
    `UPDATE sis_student_enrollments SET
      academic_year = $1,
      class_name = $2,
      section_name = $3,
      roll_number = $4,
      is_current = $5,
      updated_at = timezone('utc', now())
     WHERE id = $6 AND organization_id = $7 AND school_id = $8`,
    [
      academicYear,
      className,
      sectionName,
      rollNumber,
      isCurrent,
      enrollmentId,
      organizationId,
      schoolId,
    ],
  );

  const row = await getEnrollmentListRow(db, organizationId, schoolId, enrollmentId);
  if (!row) throw new EnrollmentNotFoundError(enrollmentId);
  return row;
}

/** Probe: non-school scopes denied enrollment API reads. */
export const SIS_ENROLLMENTS_API_PROBE_SQL = `
  SELECT count(*)::text AS count
  FROM sis_student_enrollments se
  INNER JOIN students s ON s.id = se.student_id
`;

/** Probe: cross-school enrollment update target visibility. */
export const SIS_ENROLLMENT_UPDATE_PROBE_SQL = `
  SELECT count(*)::text AS count
  FROM sis_student_enrollments
  WHERE id = $1
`;
