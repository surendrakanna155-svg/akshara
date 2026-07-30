import type { TenantQueryClient } from "../tenant_db.ts";
import {
  allocateAndInsertStudentProfile,
  insertStudentIdentityRow,
} from "../sis/sis_student_identity.ts";

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

/**
 * Derives the deterministic employee_code from a user UUID, matching the v9.6
 * backfill scheme (`'EMP-' || first 8 hex chars of the UUID, dashes stripped`).
 * Stable per user, so re-provisioning never changes an employee's code.
 */
export function employeeCodeForUser(userId: string): string {
  return `EMP-${userId.replace(/-/g, "").slice(0, 8)}`;
}

export interface EmployeeProvisionInput {
  displayName: string;
  email?: string | null;
  phone?: string | null;
  primaryDepartment?: string | null;
}

/**
 * HR-8 — Automatic Employee Provisioning.
 *
 * Projects a staff `users` row into the HR `employees` table for (org, school,
 * user). Called from the teacher/staff onboarding commit path AFTER
 * ensureSchoolMembership, so canonical identity (`users` + `school_memberships`)
 * is already established and remains the source of truth — `employees` is a pure
 * HR projection.
 *
 * Idempotent via `ON CONFLICT (organization_id, school_id, user_id) DO NOTHING`
 * (the partial unique index added in 20260834000000): a re-import creates no
 * duplicate. On conflict the display_name / email / phone are refreshed so the
 * projection stays in sync — but employee_code and user_id are NEVER changed
 * (an employee's HR code and identity link are permanent).
 *
 * Returns the employee id and whether a NEW row was created (created=false on a
 * re-import / conflict).
 */
export async function provisionEmployee(
  db: TenantQueryClient,
  organizationId: string,
  schoolId: string,
  userId: string,
  input: EmployeeProvisionInput,
): Promise<{ employeeId: string; created: boolean }> {
  const employeeCode = employeeCodeForUser(userId);
  const displayName = input.displayName.trim() || "Staff Member";
  const primaryDepartment = (input.primaryDepartment ?? "").trim() || "General";
  const email = input.email?.trim() || null;
  const phone = input.phone?.trim() || null;

  const inserted = await db.queryObject<{ id: string }>(
    `INSERT INTO employees (
       organization_id, school_id, user_id, employee_code, display_name,
       email, phone, status, primary_department
     ) VALUES ($1, $2, $3, $4, $5, $6, $7, 'active', $8)
     ON CONFLICT (organization_id, school_id, user_id) WHERE user_id IS NOT NULL
     DO NOTHING
     RETURNING id`,
    [
      organizationId,
      schoolId,
      userId,
      employeeCode,
      displayName,
      email,
      phone,
      primaryDepartment,
    ],
  );

  if (inserted[0]) {
    return { employeeId: inserted[0].id, created: true };
  }

  // Conflict: the employee already exists for this (org, school, user).
  // Refresh the mutable HR projection fields (display_name / email / phone),
  // but NEVER touch employee_code or user_id (permanent identity). email/phone
  // are only overwritten when a fresh value is supplied (COALESCE keeps prior).
  const updated = await db.queryObject<{ id: string }>(
    `UPDATE employees
       SET display_name = $4,
           email = COALESCE($5, email),
           phone = COALESCE($6, phone),
           primary_department = COALESCE(primary_department, $7)
     WHERE organization_id = $1 AND school_id = $2 AND user_id = $3
     RETURNING id`,
    [organizationId, schoolId, userId, displayName, email, phone, primaryDepartment],
  );
  return { employeeId: updated[0]!.id, created: false };
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

  // ICA-F2: identity-table row via the single SIS-owned writer.
  const inserted = await insertStudentIdentityRow(db, organizationId, schoolId, {
    userId: studentUserId,
    studentCode,
    displayName: row.studentName.trim(),
    isPlaceholder: false,
    aadhaarMasked,
    aadhaarHash,
  });
  const studentId = inserted!.id;

  // PSID + profile: permanent Public Student ID for the imported student's
  // profile (set-once) via the single SIS-owned identity writer.
  await allocateAndInsertStudentProfile(db, organizationId, schoolId, studentId, {
    admissionNumber: row.admissionNumber.trim(),
    gender: row.gender ?? null,
    dateOfBirth: (row.dateOfBirth ?? "").trim() || null,
    motherName: row.motherName ?? null,
  });

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

  // ICA-F2: identity-table row via the single SIS-owned writer. Placeholder
  // idempotency keeps its deterministic student_code + ON CONFLICT reuse.
  const inserted = await insertStudentIdentityRow(db, organizationId, schoolId, {
    studentCode,
    displayName: studentName,
    isPlaceholder: true,
    reuseOnStudentCodeConflict: true,
  });
  if (!inserted) {
    // Lost a race; fetch the row that won.
    const winner = await db.queryObject<{ id: string }>(
      `SELECT id FROM students WHERE school_id = $1 AND student_code = $2 LIMIT 1`,
      [schoolId, studentCode],
    );
    return { studentId: winner[0]!.id, created: false };
  }
  const studentId = inserted.id;

  // PSID + profile: permanent Public Student ID for the placeholder's profile
  // (set-once) via the single SIS-owned identity writer.
  await allocateAndInsertStudentProfile(db, organizationId, schoolId, studentId, {
    admissionNumber,
    reuseOnStudentConflict: true,
  });

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
  // The erp_tenant role has no direct DELETE on student tables (non-destructive
  // by design), so rollback deletes go through a SECURITY DEFINER function that
  // performs the scoped (org + school) cascade. See migration
  // 20260715000000_onboarding_rollback_student_secdef.sql.
  await db.queryObject(
    `SELECT onboarding_rollback_student($1::uuid, $2::uuid, $3::uuid)`,
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
