import type { TenantQueryClient } from "../tenant_db.ts";
import type {
  PaginationParams,
  PaginationResult,
} from "../finance/finance_structures_repository.ts";
import {
  assertValidStatusTransition,
  generateStudentCode,
  parseApiStatus,
  statusToDb,
} from "./sis_status_codec.ts";

export interface StudentListFilters {
  search?: string;
  academicYear?: string;
  className?: string;
  sectionName?: string;
  status?: string;
}

export interface StudentDirectoryRow {
  student_id: string;
  student_code: string;
  display_name: string;
  status: string;
  admission_number: string | null;
  academic_year: string | null;
  class_name: string | null;
  section_name: string | null;
  roll_number: string | null;
  guardian_count: string;
  created_at: string;
  updated_at: string;
}

export interface StudentCoreRow {
  id: string;
  organization_id: string;
  school_id: string;
  student_code: string;
  display_name: string;
  status: string;
  created_at: string;
  updated_at: string;
}

export interface StudentProfileRow {
  id: string;
  student_id: string;
  admission_number: string;
  date_of_birth: string | null;
  gender: string | null;
  blood_group: string | null;
  address: string | null;
  city: string | null;
  state: string | null;
  postal_code: string | null;
  country: string | null;
  created_at: string;
  updated_at: string;
}

export interface StudentEnrollmentRow {
  id: string;
  student_id: string;
  academic_year: string;
  class_name: string;
  section_name: string | null;
  roll_number: string | null;
  is_current: boolean;
  created_at: string;
  updated_at: string;
}

export interface StudentGuardianRow {
  id: string;
  student_id: string;
  guardian_user_id: string;
  relationship: string;
  is_primary: boolean;
  status: string;
  display_name: string | null;
  phone: string | null;
  email: string | null;
}

export interface StudentDetailData {
  student: StudentCoreRow;
  profile: StudentProfileRow | null;
  currentEnrollment: StudentEnrollmentRow | null;
  guardians: StudentGuardianRow[];
}

export class StudentNotFoundError extends Error {
  constructor(id: string) {
    super(`Student not found: ${id}`);
    this.name = "StudentNotFoundError";
  }
}

export class DuplicateAdmissionNumberError extends Error {
  constructor(admissionNumber: string) {
    super(`Admission number already exists: ${admissionNumber}`);
    this.name = "DuplicateAdmissionNumberError";
  }
}

export class ValidationError extends Error {
  constructor(message: string) {
    super(message);
    this.name = "ValidationError";
  }
}

export interface CreateStudentInput {
  displayName: string;
  admissionNumber: string;
  dateOfBirth?: string | null;
  gender?: string | null;
  bloodGroup?: string | null;
  address?: string | null;
  city?: string | null;
  state?: string | null;
  postalCode?: string | null;
  country?: string | null;
  status?: string;
  createdBy: string;
}

export interface UpdateStudentInput {
  displayName?: string;
  status?: string;
  admissionNumber?: string;
  dateOfBirth?: string | null;
  gender?: string | null;
  bloodGroup?: string | null;
  address?: string | null;
  city?: string | null;
  state?: string | null;
  postalCode?: string | null;
  country?: string | null;
}

export interface UpdateStudentStatusInput {
  status: string;
}

function offsetFor(page: number, pageSize: number): number {
  return Math.max(0, (page - 1) * pageSize);
}

function listFromSql(): string {
  return `FROM students s
  LEFT JOIN student_profiles sp
    ON sp.student_id = s.id
   AND sp.organization_id = s.organization_id
   AND sp.school_id = s.school_id
  LEFT JOIN sis_student_enrollments se
    ON se.student_id = s.id
   AND se.organization_id = s.organization_id
   AND se.school_id = s.school_id
   AND se.is_current = true`;
}

function listSelectSql(): string {
  return `SELECT
    s.id AS student_id,
    s.student_code,
    s.display_name,
    s.status,
    sp.admission_number,
    se.academic_year,
    se.class_name,
    se.section_name,
    se.roll_number,
    (
      SELECT count(*)::text
      FROM student_guardians sg
      WHERE sg.student_id = s.id
        AND sg.organization_id = s.organization_id
        AND sg.school_id = s.school_id
        AND sg.status = 'active'
    ) AS guardian_count,
    s.created_at,
    GREATEST(
      s.updated_at,
      COALESCE(sp.updated_at, s.updated_at),
      COALESCE(se.updated_at, s.updated_at)
    ) AS updated_at
  ${listFromSql()}`;
}

function listWhereSql(): string {
  return `WHERE s.organization_id = $1
    AND s.school_id = $2
    AND ($3::text IS NULL OR s.status = $3)
    AND ($4::text IS NULL OR se.academic_year = $4)
    AND ($5::text IS NULL OR se.class_name = $5)
    AND ($6::text IS NULL OR se.section_name = $6)
    AND (
      $7::text IS NULL OR $7 = '' OR
      s.display_name ILIKE '%' || $7 || '%' OR
      s.student_code ILIKE '%' || $7 || '%' OR
      sp.admission_number ILIKE '%' || $7 || '%'
    )`;
}

function filterArgs(
  organizationId: string,
  schoolId: string,
  filters: StudentListFilters,
): unknown[] {
  return [
    organizationId,
    schoolId,
    filters.status ?? null,
    filters.academicYear ?? null,
    filters.className ?? null,
    filters.sectionName ?? null,
    filters.search?.trim() || null,
  ];
}

export async function searchStudents(
  db: TenantQueryClient,
  organizationId: string,
  schoolId: string,
  filters: StudentListFilters,
  pagination: PaginationParams,
): Promise<PaginationResult<StudentDirectoryRow>> {
  const limit = Math.min(Math.max(pagination.pageSize, 1), 100);
  const offset = offsetFor(pagination.page, limit);
  const args = filterArgs(organizationId, schoolId, filters);

  const total = await db.queryCount(
    `SELECT count(*)::text AS count
     ${listFromSql()}
     ${listWhereSql()}`,
    args,
  );

  const items = await db.queryObject<StudentDirectoryRow>(
    `${listSelectSql()}
     ${listWhereSql()}
     ORDER BY s.display_name ASC, s.created_at DESC
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

export async function listStudents(
  db: TenantQueryClient,
  organizationId: string,
  schoolId: string,
  filters: StudentListFilters,
  pagination: PaginationParams,
): Promise<PaginationResult<StudentDirectoryRow>> {
  return await searchStudents(db, organizationId, schoolId, filters, pagination);
}

export async function getStudent(
  db: TenantQueryClient,
  organizationId: string,
  schoolId: string,
  studentId: string,
): Promise<StudentDetailData | null> {
  const studentRows = await db.queryObject<StudentCoreRow>(
    `SELECT id, organization_id, school_id, student_code, display_name, status,
            created_at, updated_at
     FROM students
     WHERE id = $1 AND organization_id = $2 AND school_id = $3`,
    [studentId, organizationId, schoolId],
  );
  const student = studentRows[0];
  if (!student) return null;

  const profileRows = await db.queryObject<StudentProfileRow>(
    `SELECT id, student_id, admission_number, date_of_birth::text AS date_of_birth,
            gender, blood_group, address, city, state, postal_code, country,
            created_at, updated_at
     FROM student_profiles
     WHERE student_id = $1 AND organization_id = $2 AND school_id = $3`,
    [studentId, organizationId, schoolId],
  );

  const enrollmentRows = await db.queryObject<StudentEnrollmentRow>(
    `SELECT id, student_id, academic_year, class_name, section_name, roll_number,
            is_current, created_at, updated_at
     FROM sis_student_enrollments
     WHERE student_id = $1 AND organization_id = $2 AND school_id = $3
       AND is_current = true
     ORDER BY created_at DESC
     LIMIT 1`,
    [studentId, organizationId, schoolId],
  );

  const guardianRows = await db.queryObject<StudentGuardianRow>(
    `SELECT sg.id, sg.student_id, sg.guardian_user_id, sg.relationship,
            sg.is_primary, sg.status,
            u.display_name, u.phone, u.email
     FROM student_guardians sg
     JOIN users u ON u.id = sg.guardian_user_id
     WHERE sg.student_id = $1
       AND sg.organization_id = $2
       AND sg.school_id = $3
     ORDER BY sg.is_primary DESC, sg.created_at ASC`,
    [studentId, organizationId, schoolId],
  );

  return {
    student,
    profile: profileRows[0] ?? null,
    currentEnrollment: enrollmentRows[0] ?? null,
    guardians: guardianRows,
  };
}

async function admissionNumberExists(
  db: TenantQueryClient,
  organizationId: string,
  schoolId: string,
  admissionNumber: string,
  excludeStudentId?: string,
): Promise<boolean> {
  const rows = await db.queryObject<{ id: string }>(
    `SELECT id FROM student_profiles
     WHERE organization_id = $1 AND school_id = $2 AND admission_number = $3
       AND ($4::uuid IS NULL OR student_id <> $4)
     LIMIT 1`,
    [organizationId, schoolId, admissionNumber, excludeStudentId ?? null],
  );
  return rows.length > 0;
}

export async function createStudent(
  db: TenantQueryClient,
  organizationId: string,
  schoolId: string,
  input: CreateStudentInput,
): Promise<StudentDetailData> {
  const displayName = input.displayName.trim();
  const admissionNumber = input.admissionNumber.trim();
  if (!displayName) throw new ValidationError("displayName is required");
  if (!admissionNumber) throw new ValidationError("admissionNumber is required");

  if (await admissionNumberExists(db, organizationId, schoolId, admissionNumber)) {
    throw new DuplicateAdmissionNumberError(admissionNumber);
  }

  const dbStatus = statusToDb(parseApiStatus(input.status));
  const studentCode = await generateStudentCode(db, schoolId);

  const studentRows = await db.queryObject<{ id: string }>(
    `INSERT INTO students (
      organization_id, school_id, student_code, display_name, status, created_by
    ) VALUES ($1, $2, $3, $4, $5, $6)
    RETURNING id`,
    [organizationId, schoolId, studentCode, displayName, dbStatus, input.createdBy],
  );
  const studentId = studentRows[0]!.id;

  await db.queryObject(
    `INSERT INTO student_profiles (
      organization_id, school_id, student_id, admission_number,
      date_of_birth, gender, blood_group, address, city, state, postal_code, country,
      created_by
    ) VALUES (
      $1, $2, $3, $4,
      $5::date, $6, $7, $8, $9, $10, $11, $12,
      $13
    )`,
    [
      organizationId,
      schoolId,
      studentId,
      admissionNumber,
      input.dateOfBirth || null,
      input.gender ?? null,
      input.bloodGroup ?? null,
      input.address ?? null,
      input.city ?? null,
      input.state ?? null,
      input.postalCode ?? null,
      input.country ?? null,
      input.createdBy,
    ],
  );

  const detail = await getStudent(db, organizationId, schoolId, studentId);
  if (!detail) throw new StudentNotFoundError(studentId);
  return detail;
}

export async function updateStudent(
  db: TenantQueryClient,
  organizationId: string,
  schoolId: string,
  studentId: string,
  input: UpdateStudentInput,
): Promise<StudentDetailData> {
  const existing = await getStudent(db, organizationId, schoolId, studentId);
  if (!existing) throw new StudentNotFoundError(studentId);

  if (input.admissionNumber?.trim()) {
    const admissionNumber = input.admissionNumber.trim();
    if (await admissionNumberExists(db, organizationId, schoolId, admissionNumber, studentId)) {
      throw new DuplicateAdmissionNumberError(admissionNumber);
    }
  }

  if (input.status !== undefined) {
    assertValidStatusTransition(existing.student.status, input.status);
  }

  if (input.displayName !== undefined || input.status !== undefined) {
    const displayName = input.displayName?.trim() ?? existing.student.display_name;
    const dbStatus = input.status !== undefined
      ? statusToDb(parseApiStatus(input.status))
      : existing.student.status;
    await db.queryObject(
      `UPDATE students SET
        display_name = $1,
        status = $2,
        updated_at = timezone('utc', now())
       WHERE id = $3 AND organization_id = $4 AND school_id = $5`,
      [displayName, dbStatus, studentId, organizationId, schoolId],
    );
  }

  if (
    input.admissionNumber !== undefined ||
    input.dateOfBirth !== undefined ||
    input.gender !== undefined ||
    input.bloodGroup !== undefined ||
    input.address !== undefined ||
    input.city !== undefined ||
    input.state !== undefined ||
    input.postalCode !== undefined ||
    input.country !== undefined
  ) {
    const profile = existing.profile;
    if (!profile) {
      throw new ValidationError("Student profile not found for update");
    }
    await db.queryObject(
      `UPDATE student_profiles SET
        admission_number = $1,
        date_of_birth = $2::date,
        gender = $3,
        blood_group = $4,
        address = $5,
        city = $6,
        state = $7,
        postal_code = $8,
        country = $9,
        updated_at = timezone('utc', now())
       WHERE student_id = $10 AND organization_id = $11 AND school_id = $12`,
      [
        input.admissionNumber?.trim() ?? profile.admission_number,
        input.dateOfBirth !== undefined ? (input.dateOfBirth || null) : profile.date_of_birth,
        input.gender !== undefined ? input.gender : profile.gender,
        input.bloodGroup !== undefined ? input.bloodGroup : profile.blood_group,
        input.address !== undefined ? input.address : profile.address,
        input.city !== undefined ? input.city : profile.city,
        input.state !== undefined ? input.state : profile.state,
        input.postalCode !== undefined ? input.postalCode : profile.postal_code,
        input.country !== undefined ? input.country : profile.country,
        studentId,
        organizationId,
        schoolId,
      ],
    );
  }

  const detail = await getStudent(db, organizationId, schoolId, studentId);
  if (!detail) throw new StudentNotFoundError(studentId);
  return detail;
}

export async function updateStudentStatus(
  db: TenantQueryClient,
  organizationId: string,
  schoolId: string,
  studentId: string,
  input: UpdateStudentStatusInput,
): Promise<StudentDetailData> {
  const existing = await getStudent(db, organizationId, schoolId, studentId);
  if (!existing) throw new StudentNotFoundError(studentId);

  assertValidStatusTransition(existing.student.status, input.status);
  const dbStatus = statusToDb(parseApiStatus(input.status));

  await db.queryObject(
    `UPDATE students SET
      status = $1,
      updated_at = timezone('utc', now())
     WHERE id = $2 AND organization_id = $3 AND school_id = $4`,
    [dbStatus, studentId, organizationId, schoolId],
  );

  const detail = await getStudent(db, organizationId, schoolId, studentId);
  if (!detail) throw new StudentNotFoundError(studentId);
  return detail;
}

/** Probe: org/parent/student cannot INSERT into student_profiles (school scope RLS). */
export const SIS_STUDENT_CREATE_PROBE_SQL = `
  SELECT count(*)::text AS count FROM student_profiles
`;

/** Probe: cross-school student update visibility. */
export const SIS_STUDENT_UPDATE_PROBE_SQL = `
  SELECT count(*)::text AS count
  FROM students
  WHERE id = $1
`;

/** SQL fragment used by tenant isolation probes for directory visibility. */
export const SIS_DIRECTORY_PROBE_SQL = `
  SELECT count(*)::text AS count
  FROM students s
  INNER JOIN student_profiles sp ON sp.student_id = s.id
  INNER JOIN sis_student_enrollments se
    ON se.student_id = s.id AND se.is_current = true
`;

export const SIS_STUDENT_DETAIL_PROBE_SQL = `
  SELECT count(*)::text AS count
  FROM students s
  INNER JOIN student_profiles sp ON sp.student_id = s.id
  WHERE s.id = $1
`;
