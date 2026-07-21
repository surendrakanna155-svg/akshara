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
import {
  allocateAndInsertStudentProfile,
  insertStudentIdentityRow,
} from "./sis_student_identity.ts";
import {
  ClearanceDuesBlockedError,
  resolveClearanceDecision,
} from "../clearance/clearance_gate.ts";
import { consumeWaiver } from "../clearance/clearance_waiver_repository.ts";

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
  public_student_id: string | null;
  academic_year: string | null;
  class_name: string | null;
  section_name: string | null;
  roll_number: string | null;
  guardian_name: string | null;
  guardian_phone: string | null;
  guardian_count: string;
  created_at: string;
  updated_at: string;
}

export interface StudentTransferFilters {
  fromDate?: string;
  toDate?: string;
  status?: string;
}

export interface StudentTransferRow {
  student_id: string;
  student_code: string;
  display_name: string;
  status: string;
  admission_number: string | null;
  academic_year: string | null;
  class_name: string | null;
  section_name: string | null;
  roll_number: string | null;
  transitioned_at: string;
  created_at: string;
  // SIS-5 — reason from the latest Transfer Certificate for this student
  // (read-only correlated sub-select). Null when no TC was ever issued.
  exit_reason: string | null;
}

// SIS-4 — one sibling summary row: another student in the SAME school who
// shares an active guardian with the subject. Read-only, no new PII beyond what
// the registry/profile already surface (name, admission number, class/section,
// status).
export interface StudentSiblingRow {
  student_id: string;
  student_code: string;
  display_name: string;
  status: string;
  admission_number: string | null;
  public_student_id: string | null;
  class_name: string | null;
  section_name: string | null;
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
  public_student_id: string | null;
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

/**
 * Identity rule C5 ("an id never changes"): a student's admission_number is
 * SET-ONCE. Once a non-empty admission_number exists on the profile it is a
 * hard, immutable, permanent identity value — there is NO self-service override.
 * Attempting to change it to a different value is rejected (409). The
 * DB trigger `reject_admission_number_change` (migration 20260847000000)
 * backstops this guard against any direct/rogue UPDATE.
 */
export class AdmissionNumberImmutableError extends Error {
  readonly attempted: string;
  readonly current: string;
  constructor(current: string, attempted: string) {
    super(
      `Admission number is set-once and cannot be changed (current: ${current}, attempted: ${attempted})`,
    );
    this.name = "AdmissionNumberImmutableError";
    this.current = current;
    this.attempted = attempted;
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
    sp.public_student_id,
    se.academic_year,
    se.class_name,
    se.section_name,
    se.roll_number,
    -- SIS-2: primary guardian display_name + phone for the richer registry
    -- export. LEFT-JOIN semantics via correlated subqueries so students with no
    -- primary (or no active) guardian still list with null name/phone.
    (
      SELECT u.display_name
      FROM student_guardians sg
      JOIN users u ON u.id = sg.guardian_user_id
      WHERE sg.student_id = s.id
        AND sg.organization_id = s.organization_id
        AND sg.school_id = s.school_id
        AND sg.status = 'active'
        AND sg.is_primary = true
      ORDER BY sg.created_at ASC
      LIMIT 1
    ) AS guardian_name,
    (
      SELECT u.phone
      FROM student_guardians sg
      JOIN users u ON u.id = sg.guardian_user_id
      WHERE sg.student_id = s.id
        AND sg.organization_id = s.organization_id
        AND sg.school_id = s.school_id
        AND sg.status = 'active'
        AND sg.is_primary = true
      ORDER BY sg.created_at ASC
      LIMIT 1
    ) AS guardian_phone,
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

// SIS-5 — transfer / exit terminal statuses (see sis_status_codec:
// TERMINAL_DB_STATUSES). `alumni` is the DB storage for graduated.
const TRANSFER_DB_STATUSES = ["transferred", "alumni"] as const;

function transferFromSql(): string {
  // Join the student's LAST enrollment (highest created_at) — for a transferred
  // /alumni student `is_current` is typically already false, so `listFromSql`'s
  // `is_current = true` join would drop the class/section context. LATERAL picks
  // the most recent enrollment regardless of current-flag.
  return `FROM students s
  LEFT JOIN LATERAL (
    SELECT se.academic_year, se.class_name, se.section_name, se.roll_number
    FROM sis_student_enrollments se
    WHERE se.student_id = s.id
      AND se.organization_id = s.organization_id
      AND se.school_id = s.school_id
    ORDER BY se.created_at DESC
    LIMIT 1
  ) se ON true`;
}

function transferWhereSql(): string {
  // Timestamp source: `students.updated_at`. transferred/alumni are terminal
  // (no further transitions per the status codec), so the row's last update is
  // its exit timestamp — the only reliable per-row timestamp without joining the
  // append-only audit log. Documented choice; range filter is inclusive of the
  // whole `toDate` day via a strict-upper-bound on the next day.
  return `WHERE s.organization_id = $1
    AND s.school_id = $2
    AND s.status = ANY($3::text[])
    AND ($4::text IS NULL OR s.status = $4)
    AND ($5::timestamptz IS NULL OR s.updated_at >= $5::timestamptz)
    AND ($6::timestamptz IS NULL OR s.updated_at < ($6::timestamptz + interval '1 day'))`;
}

function transferArgs(
  organizationId: string,
  schoolId: string,
  filters: StudentTransferFilters,
): unknown[] {
  // `status` filter is honoured only when it is itself a transfer status; any
  // other value would return nothing, so treat it as unset.
  const statusFilter =
    filters.status && (TRANSFER_DB_STATUSES as readonly string[]).includes(filters.status)
      ? filters.status
      : null;
  return [
    organizationId,
    schoolId,
    TRANSFER_DB_STATUSES,
    statusFilter,
    filters.fromDate?.trim() || null,
    filters.toDate?.trim() || null,
  ];
}

/**
 * SIS-5 — date-ranged list of students who have exited (status transferred or
 * alumni/graduated), with their last enrollment context and an exit timestamp,
 * paginated like {@link listStudents}. Backing surface for the exportable
 * transfer/exit log (CSV export is client-side XCT-1).
 */
export async function listStudentTransfers(
  db: TenantQueryClient,
  organizationId: string,
  schoolId: string,
  filters: StudentTransferFilters,
  pagination: PaginationParams,
): Promise<PaginationResult<StudentTransferRow>> {
  const limit = Math.min(Math.max(pagination.pageSize, 1), 100);
  const offset = offsetFor(pagination.page, limit);
  const args = transferArgs(organizationId, schoolId, filters);

  const total = await db.queryCount(
    `SELECT count(*)::text AS count
     ${transferFromSql()}
     ${transferWhereSql()}`,
    args,
  );

  const items = await db.queryObject<StudentTransferRow>(
    `SELECT
        s.id AS student_id,
        s.student_code,
        s.display_name,
        s.status,
        (
          SELECT sp.admission_number
          FROM student_profiles sp
          WHERE sp.student_id = s.id
            AND sp.organization_id = s.organization_id
            AND sp.school_id = s.school_id
          LIMIT 1
        ) AS admission_number,
        se.academic_year,
        se.class_name,
        se.section_name,
        se.roll_number,
        s.updated_at AS transitioned_at,
        s.created_at,
        (
          SELECT tc.reason
          FROM sis_certificate_issues tc
          WHERE tc.student_id = s.id
            AND tc.organization_id = s.organization_id
            AND tc.school_id = s.school_id
            AND tc.certificate_type = 'transfer'
          ORDER BY tc.issued_at DESC
          LIMIT 1
        ) AS exit_reason
     ${transferFromSql()}
     ${transferWhereSql()}
     ORDER BY s.updated_at DESC, s.display_name ASC
     LIMIT $7 OFFSET $8`,
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
    `SELECT id, student_id, admission_number, public_student_id,
            date_of_birth::text AS date_of_birth,
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

/**
 * SIS-4 — read-only list of a student's siblings: other students in the SAME
 * org + school who share an ACTIVE guardian with {@link studentId}. The subject
 * student is self-excluded and results are ORDER BY display_name. Returns `[]`
 * when the student has no active guardian or no other student shares one.
 *
 * Cross-school isolation is structural: both sides of the shared-guardian join
 * (`sib`/`subj`) are pinned to the SAME organization_id + school_id, and the
 * outer `students s` row is pinned to the caller's org/school ($1/$2). A guardian
 * shared with a student in another school/tenant therefore never surfaces.
 */
export async function listStudentSiblings(
  db: TenantQueryClient,
  organizationId: string,
  schoolId: string,
  studentId: string,
): Promise<StudentSiblingRow[]> {
  return await db.queryObject<StudentSiblingRow>(
    `SELECT
        s.id AS student_id,
        s.student_code,
        s.display_name,
        s.status,
        sp.admission_number,
        sp.public_student_id,
        se.class_name,
        se.section_name
     FROM students s
     LEFT JOIN student_profiles sp
       ON sp.student_id = s.id
      AND sp.organization_id = s.organization_id
      AND sp.school_id = s.school_id
     LEFT JOIN sis_student_enrollments se
       ON se.student_id = s.id
      AND se.organization_id = s.organization_id
      AND se.school_id = s.school_id
      AND se.is_current = true
     WHERE s.organization_id = $1
       AND s.school_id = $2
       AND s.id <> $3
       AND EXISTS (
         SELECT 1
         FROM student_guardians sib
         JOIN student_guardians subj
           ON subj.guardian_user_id = sib.guardian_user_id
          AND subj.organization_id = sib.organization_id
          AND subj.school_id = sib.school_id
         WHERE sib.student_id = s.id
           AND sib.organization_id = s.organization_id
           AND sib.school_id = s.school_id
           AND sib.status = 'active'
           AND subj.student_id = $3
           AND subj.status = 'active'
       )
     ORDER BY s.display_name ASC`,
    [organizationId, schoolId, studentId],
  );
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

  // RT-03: `generateStudentCode` is MAX+1 with no lock, so two concurrent
  // enrolments compute the same code and one 500s on the UNIQUE(school_id,
  // student_code) constraint. Retry-on-conflict: a savepoint lets us roll back
  // just the failed INSERT (not the whole transaction) and re-derive the code
  // — by then the winner is committed/visible, so MAX+1 advances past it.
  let studentId: string | undefined;
  for (let attempt = 0; attempt < 5; attempt++) {
    const studentCode = await generateStudentCode(db, schoolId);
    await db.queryObject("SAVEPOINT sis_student_code");
    try {
      // ICA-F2: identity-table row via the single SIS-owned writer.
      const studentRow = await insertStudentIdentityRow(db, organizationId, schoolId, {
        studentCode,
        displayName,
        status: dbStatus,
        createdBy: input.createdBy,
      });
      await db.queryObject("RELEASE SAVEPOINT sis_student_code");
      studentId = studentRow!.id;
      break;
    } catch (error) {
      await db.queryObject("ROLLBACK TO SAVEPOINT sis_student_code");
      if (String(error).includes("duplicate key") && attempt < 4) continue;
      throw error;
    }
  }
  if (!studentId) {
    throw new ValidationError("Could not allocate a unique student code; please retry");
  }

  // PSID + profile: allocate the permanent Public Student ID and write the
  // identity profile via the single SIS-owned writer (ICA-F2). Set-once at
  // creation; the counter is never-reused/gapped and concurrency-safe. Fails
  // loudly if the school has no code (PSID requires it).
  //
  // RT-02: the admissionNumberExists() check above is TOCTOU-racy. The DB now
  // enforces UNIQUE(school_id, admission_number); map the violation to the same
  // DuplicateAdmissionNumberError (409) so a concurrent duplicate is rejected
  // cleanly instead of 500ing. The whole transaction rolls back (no orphan
  // students row).
  try {
    await allocateAndInsertStudentProfile(db, organizationId, schoolId, studentId, {
      admissionNumber,
      dateOfBirth: input.dateOfBirth || null,
      gender: input.gender ?? null,
      bloodGroup: input.bloodGroup ?? null,
      address: input.address ?? null,
      city: input.city ?? null,
      state: input.state ?? null,
      postalCode: input.postalCode ?? null,
      country: input.country ?? null,
      createdBy: input.createdBy,
    });
  } catch (error) {
    if (
      String(error).includes("duplicate key") &&
      String(error).includes("admission")
    ) {
      throw new DuplicateAdmissionNumberError(admissionNumber);
    }
    throw error;
  }

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

  if (input.admissionNumber !== undefined) {
    const admissionNumber = input.admissionNumber.trim();
    if (admissionNumber) {
      // C5 set-once identity lock: once a non-empty admission_number exists it
      // is immutable. An incoming value that DIFFERS from the current one is a
      // lock violation (409); an identical value is an idempotent no-op and is
      // allowed so unchanged-value / other-field updates still succeed.
      const current = (existing.profile?.admission_number ?? "").trim();
      if (current && current !== admissionNumber) {
        throw new AdmissionNumberImmutableError(current, admissionNumber);
      }
      // Duplicate check still applies for the legitimate first-time set (current
      // empty) and the idempotent no-op is harmless (excludes self).
      if (await admissionNumberExists(db, organizationId, schoolId, admissionNumber, studentId)) {
        throw new DuplicateAdmissionNumberError(admissionNumber);
      }
    }
  }

  if (input.status !== undefined) {
    assertValidStatusTransition(existing.student.status, input.status);
    // SCE-1 (audit F1 P0): the general update is a second writer of
    // status='transferred' — it must enforce the SAME no-dues gate as
    // PATCH /status and the TC engine, or the bypass stays open here.
    await enforceTransferClearance(
      db,
      organizationId,
      schoolId,
      studentId,
      parseApiStatus(input.status),
    );
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

/**
 * SCE-1 (owner-approved 2026-07-12): EVERY transition to `transferred` — whoever
 * writes the status — must clear the SAME no-dues gate as the TC engine, so no
 * status-writing endpoint can bypass the Transfer-Certificate law. Shared by
 * `updateStudentStatus` (PATCH /status) AND `updateStudent` (PUT /students/:id).
 * Consults the clearance gate on lifecycle 'transfer_certificate' (identical
 * finance-blocking policy AND the shared waiver pool), fails CLOSED on unwaived
 * dues (→ ClearanceDuesBlockedError → 409 DUES_PENDING), and CONSUMES a covering
 * approved waiver single-use (no TC issue row, so consumed_by_issue_id null;
 * re-blocks on a lost consume race). No-op for any target other than
 * `transferred` — `graduated` is DELIBERATELY NOT gated (open owner policy on
 * cohort-graduation dues-blocking). MUST run inside the caller's transaction,
 * BEFORE the status UPDATE, so a block rolls the whole change back.
 */
export async function enforceTransferClearance(
  db: TenantQueryClient,
  organizationId: string,
  schoolId: string,
  studentId: string,
  targetStatus: string,
): Promise<void> {
  if (targetStatus !== "transferred") return;
  const decision = await resolveClearanceDecision(
    db,
    { organizationId, schoolId },
    studentId,
    "transfer_certificate",
  );
  if (decision.blocked) {
    throw new ClearanceDuesBlockedError(decision.blockingAmount);
  }
  if (decision.waiver) {
    const consumed = await consumeWaiver(
      db,
      { organizationId, schoolId },
      studentId,
      "transfer_certificate",
      null,
    );
    // Single-use guard (mirrors the TC path): a concurrent exit may have already
    // consumed the covering waiver → it can't clear THIS transfer → fail closed.
    if (!consumed) {
      throw new ClearanceDuesBlockedError(decision.duesAtGate);
    }
  }
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
  const targetStatus = parseApiStatus(input.status);
  const dbStatus = statusToDb(targetStatus);

  await enforceTransferClearance(db, organizationId, schoolId, studentId, targetStatus);

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
