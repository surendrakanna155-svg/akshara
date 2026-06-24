import type { TenantQueryClient } from "../tenant_db.ts";

export interface StudentImportRow {
  studentName: string;
  admissionNumber: string;
  classLabel: string;
  sectionLabel: string;
  academicYear: string;
  parentName: string;
  parentPhone: string;
  studentPhone?: string;
  gender?: string;
  dateOfBirth?: string;
  rollNumber?: string;
  motherName?: string;
  /** Raw 12-digit Aadhaar (used only to derive masked + hash; never stored raw). */
  aadhaar?: string;
  /** Placeholder students have no real parent phone/login. */
  isPlaceholder?: boolean;
}

export interface TeacherImportRow {
  displayName: string;
  phone: string;
  email?: string;
  role: string;
}

/** Strips spaces/dashes from an Aadhaar string. */
export function normalizeAadhaar(aadhaar: string): string {
  return aadhaar.replace(/[\s-]/g, "");
}

/** True when the (normalized) Aadhaar is exactly 12 digits. */
export function isValidAadhaar(aadhaar: string): boolean {
  return /^\d{12}$/.test(normalizeAadhaar(aadhaar));
}

/** Masks a 12-digit Aadhaar to 'XXXXXXXX1234' (only last 4 visible). */
export function maskAadhaar(aadhaar: string): string {
  const digits = normalizeAadhaar(aadhaar);
  return "X".repeat(Math.max(0, digits.length - 4)) + digits.slice(-4);
}

/** sha256 hex of the full (normalized) Aadhaar — for dedupe only. */
export async function hashAadhaar(aadhaar: string): Promise<string> {
  const digits = normalizeAadhaar(aadhaar);
  const bytes = new TextEncoder().encode(digits);
  const digest = await crypto.subtle.digest("SHA-256", bytes);
  return Array.from(new Uint8Array(digest))
    .map((b) => b.toString(16).padStart(2, "0"))
    .join("");
}

export function normalizeImportPhone(phone: string): string {
  const trimmed = phone.trim().replace(/\s+/g, "");
  if (trimmed.startsWith("+")) return trimmed;
  if (/^\d{10}$/.test(trimmed)) return `+91${trimmed}`;
  return trimmed;
}

export async function upsertUserByPhone(
  db: TenantQueryClient,
  phone: string,
  displayName: string,
  email?: string | null,
): Promise<string> {
  const rows = await db.queryObject<{ onboarding_upsert_user_by_phone: string }>(
    `SELECT onboarding_upsert_user_by_phone($1, $2, $3) AS onboarding_upsert_user_by_phone`,
    [phone, displayName, email ?? null],
  );
  const userId = rows[0]?.onboarding_upsert_user_by_phone;
  if (!userId) {
    throw new Error("Failed to upsert user by phone");
  }
  return userId;
}

export async function ensureSchoolMembership(
  db: TenantQueryClient,
  userId: string,
  schoolId: string,
  role: string,
): Promise<void> {
  await db.queryObject(
    `SELECT onboarding_ensure_school_membership($1::uuid, $2::uuid, $3)`,
    [userId, schoolId, role],
  );
}

export async function linkStudentGuardian(
  db: TenantQueryClient,
  organizationId: string,
  schoolId: string,
  studentId: string,
  guardianUserId: string,
  relationship = "guardian",
): Promise<void> {
  await db.queryObject(
    `INSERT INTO student_guardians (
       organization_id, school_id, student_id, guardian_user_id,
       relationship, is_primary, status
     ) VALUES ($1, $2, $3, $4, $5, true, 'active')
     ON CONFLICT (student_id, guardian_user_id)
     DO UPDATE SET status = 'active', is_primary = true`,
    [organizationId, schoolId, studentId, guardianUserId, relationship],
  );
}

export async function findDuplicateStudent(
  db: TenantQueryClient,
  organizationId: string,
  schoolId: string,
  admissionNumber: string,
): Promise<string | null> {
  const rows = await db.queryObject<{ student_id: string }>(
    `SELECT sp.student_id FROM student_profiles sp
     INNER JOIN students s ON s.id = sp.student_id
     WHERE sp.organization_id = $1 AND sp.school_id = $2
       AND sp.admission_number = $3
     LIMIT 1`,
    [organizationId, schoolId, admissionNumber],
  );
  return rows[0]?.student_id ?? null;
}

/**
 * Looks up an existing student in the school by Aadhaar hash. Returns the
 * student id when a match exists (used for dedupe in preview), else null.
 */
export async function findStudentByAadhaarHash(
  db: TenantQueryClient,
  organizationId: string,
  schoolId: string,
  aadhaarHash: string,
): Promise<string | null> {
  const rows = await db.queryObject<{ id: string }>(
    `SELECT id FROM students
     WHERE organization_id = $1 AND school_id = $2 AND aadhaar_hash = $3
     LIMIT 1`,
    [organizationId, schoolId, aadhaarHash],
  );
  return rows[0]?.id ?? null;
}

export async function createImportedStudent(
  db: TenantQueryClient,
  organizationId: string,
  schoolId: string,
  row: StudentImportRow,
  parentUserId: string,
  studentUserId: string | null,
): Promise<string> {
  const studentCode = row.admissionNumber.replace(/[^A-Za-z0-9-]/g, "").slice(0, 32) ||
    `STU-${crypto.randomUUID().slice(0, 8)}`;

  let aadhaarMasked: string | null = null;
  let aadhaarHash: string | null = null;
  if (row.aadhaar && isValidAadhaar(row.aadhaar)) {
    aadhaarMasked = maskAadhaar(row.aadhaar);
    aadhaarHash = await hashAadhaar(row.aadhaar);
  }

  const inserted = await db.queryObject<{ id: string }>(
    `INSERT INTO students (
       organization_id, school_id, user_id, student_code, display_name, status,
       is_placeholder, aadhaar, aadhaar_hash
     ) VALUES ($1, $2, $3, $4, $5, 'active', false, $6, $7)
     RETURNING id`,
    [
      organizationId,
      schoolId,
      studentUserId,
      studentCode,
      row.studentName.trim(),
      aadhaarMasked,
      aadhaarHash,
    ],
  );
  const studentId = inserted[0]!.id;

  await db.queryObject(
    `INSERT INTO student_profiles (
       student_id, organization_id, school_id, admission_number, gender,
       date_of_birth, mother_name
     ) VALUES ($1, $2, $3, $4, $5, NULLIF($6, '')::date, $7)`,
    [
      studentId,
      organizationId,
      schoolId,
      row.admissionNumber.trim(),
      row.gender ?? null,
      row.dateOfBirth ?? null,
      row.motherName ?? null,
    ],
  );

  await db.queryObject(
    `INSERT INTO sis_student_enrollments (
       organization_id, school_id, student_id, academic_year, class_name,
       section_name, roll_number, is_current
     ) VALUES ($1, $2, $3, $4, $5, $6, $7, true)`,
    [
      organizationId,
      schoolId,
      studentId,
      row.academicYear.trim(),
      row.classLabel.trim(),
      row.sectionLabel.trim(),
      row.rollNumber ?? null,
    ],
  );

  await linkStudentGuardian(db, organizationId, schoolId, studentId, parentUserId);
  return studentId;
}

/** Sanitizes a label fragment for use inside an admission/student code. */
function sanitizeCodeFragment(value: string): string {
  return value.trim().replace(/[^A-Za-z0-9]+/g, "").slice(0, 24);
}

/**
 * Pure helper: builds the deterministic display name + admission number for a
 * placeholder student. Kept separate so it is unit-testable without a DB.
 * e.g. ("Grade 6", "A", 1) -> { studentName: "Grade 6A — Roll 1",
 *                               admissionNumber: "PH-Grade6-A-1" }
 */
export function buildPlaceholderIdentity(
  classLabel: string,
  sectionLabel: string,
  rollNumber: number,
): { studentName: string; admissionNumber: string } {
  const cls = classLabel.trim();
  const sec = sectionLabel.trim();
  return {
    studentName: `${cls}${sec} — Roll ${rollNumber}`,
    admissionNumber: `PH-${sanitizeCodeFragment(cls)}-${sanitizeCodeFragment(sec)}-${rollNumber}`,
  };
}

/**
 * Creates a single placeholder student (is_placeholder = true, no parent user,
 * no guardian link). Idempotent per (school, academicYear, classLabel,
 * sectionLabel, roll) via the deterministic student_code — re-running returns
 * the existing student id and does NOT duplicate. Returns { studentId, created }.
 */
export async function createPlaceholderStudent(
  db: TenantQueryClient,
  organizationId: string,
  schoolId: string,
  academicYear: string,
  classLabel: string,
  sectionLabel: string,
  rollNumber: number,
): Promise<{ studentId: string; created: boolean }> {
  const { studentName, admissionNumber } = buildPlaceholderIdentity(
    classLabel,
    sectionLabel,
    rollNumber,
  );
  const studentCode = admissionNumber;

  const existing = await db.queryObject<{ id: string }>(
    `SELECT id FROM students
     WHERE school_id = $1 AND student_code = $2
     LIMIT 1`,
    [schoolId, studentCode],
  );
  if (existing[0]) {
    return { studentId: existing[0].id, created: false };
  }

  const inserted = await db.queryObject<{ id: string }>(
    `INSERT INTO students (
       organization_id, school_id, user_id, student_code, display_name, status,
       is_placeholder
     ) VALUES ($1, $2, NULL, $3, $4, 'active', true)
     ON CONFLICT (school_id, student_code) DO NOTHING
     RETURNING id`,
    [organizationId, schoolId, studentCode, studentName],
  );
  if (!inserted[0]) {
    // Lost a race; fetch the row that won.
    const winner = await db.queryObject<{ id: string }>(
      `SELECT id FROM students WHERE school_id = $1 AND student_code = $2 LIMIT 1`,
      [schoolId, studentCode],
    );
    return { studentId: winner[0]!.id, created: false };
  }
  const studentId = inserted[0].id;

  await db.queryObject(
    `INSERT INTO student_profiles (
       student_id, organization_id, school_id, admission_number
     ) VALUES ($1, $2, $3, $4)
     ON CONFLICT (student_id) DO NOTHING`,
    [studentId, organizationId, schoolId, admissionNumber],
  );

  await db.queryObject(
    `INSERT INTO sis_student_enrollments (
       organization_id, school_id, student_id, academic_year, class_name,
       section_name, roll_number, is_current
     ) VALUES ($1, $2, $3, $4, $5, $6, $7, true)`,
    [
      organizationId,
      schoolId,
      studentId,
      academicYear.trim(),
      classLabel.trim(),
      sectionLabel.trim(),
      String(rollNumber),
    ],
  );

  return { studentId, created: true };
}

export async function rollbackImportedStudent(
  db: TenantQueryClient,
  organizationId: string,
  schoolId: string,
  studentId: string,
): Promise<void> {
  await db.queryObject(
    `DELETE FROM student_guardians
     WHERE student_id = $1 AND organization_id = $2 AND school_id = $3`,
    [studentId, organizationId, schoolId],
  );
  await db.queryObject(
    `DELETE FROM sis_student_enrollments
     WHERE student_id = $1 AND organization_id = $2 AND school_id = $3`,
    [studentId, organizationId, schoolId],
  );
  await db.queryObject(
    `DELETE FROM student_profiles
     WHERE student_id = $1 AND organization_id = $2 AND school_id = $3`,
    [studentId, organizationId, schoolId],
  );
  await db.queryObject(
    `DELETE FROM students
     WHERE id = $1 AND organization_id = $2 AND school_id = $3`,
    [studentId, organizationId, schoolId],
  );
}

export async function resolveStudentLoginTarget(
  db: TenantQueryClient,
  schoolId: string,
  studentIdentifier: string,
): Promise<{ studentId: string; phone: string; userId: string } | null> {
  const rows = await db.queryObject<{
    student_id: string;
    user_id: string | null;
    phone: string | null;
  }>(
    `SELECT s.id AS student_id, s.user_id, u.phone
     FROM students s
     INNER JOIN users u ON u.id = s.user_id
     LEFT JOIN student_profiles sp ON sp.student_id = s.id
     WHERE s.school_id = $1
       AND s.user_id IS NOT NULL
       AND (s.student_code = $2 OR sp.admission_number = $2)
     LIMIT 1`,
    [schoolId, studentIdentifier.trim()],
  );
  const row = rows[0];
  if (!row?.user_id || !row.phone) return null;
  return { studentId: row.student_id, phone: row.phone, userId: row.user_id };
}
