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
}

export interface TeacherImportRow {
  displayName: string;
  phone: string;
  email?: string;
  role: string;
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
  const normalized = normalizeImportPhone(phone);
  const existing = await db.queryObject<{ id: string }>(
    `SELECT id FROM users WHERE phone = $1 LIMIT 1`,
    [normalized],
  );
  if (existing[0]) {
    await db.queryObject(
      `UPDATE users SET display_name = COALESCE(NULLIF($2, ''), display_name),
         email = COALESCE($3, email), updated_at = timezone('utc', now())
       WHERE id = $1`,
      [existing[0].id, displayName, email ?? null],
    );
    return existing[0].id;
  }
  const inserted = await db.queryObject<{ id: string }>(
    `INSERT INTO users (phone, display_name, email)
     VALUES ($1, $2, $3) RETURNING id`,
    [normalized, displayName, email ?? null],
  );
  return inserted[0]!.id;
}

export async function ensureSchoolMembership(
  db: TenantQueryClient,
  userId: string,
  schoolId: string,
  role: string,
): Promise<void> {
  await db.queryObject(
    `INSERT INTO school_memberships (user_id, school_id, role, status)
     VALUES ($1, $2, $3, 'active')
     ON CONFLICT (user_id, school_id)
     DO UPDATE SET role = EXCLUDED.role, status = 'active',
       updated_at = timezone('utc', now())`,
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
  const inserted = await db.queryObject<{ id: string }>(
    `INSERT INTO students (
       organization_id, school_id, user_id, student_code, display_name, status
     ) VALUES ($1, $2, $3, $4, $5, 'active')
     RETURNING id`,
    [organizationId, schoolId, studentUserId, studentCode, row.studentName.trim()],
  );
  const studentId = inserted[0]!.id;

  await db.queryObject(
    `INSERT INTO student_profiles (
       student_id, organization_id, school_id, admission_number, gender, date_of_birth
     ) VALUES ($1, $2, $3, $4, $5, NULLIF($6, '')::date)`,
    [
      studentId,
      organizationId,
      schoolId,
      row.admissionNumber.trim(),
      row.gender ?? null,
      row.dateOfBirth ?? null,
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
