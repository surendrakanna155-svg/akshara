import type { TenantQueryClient } from "../tenant_db.ts";
import { resolveAcademicPlacement } from "../academic/academic_catalog_resolver.ts";
import { clearCurrentEnrollmentsForStudent } from "./sis_enrollments_repository.ts";
import { StudentNotFoundError } from "./sis_students_repository.ts";
import { allocatePublicStudentId } from "./sis_public_student_id.ts";

export interface AdmissionsEnrollmentSourceRow {
  id: string;
  organization_id: string;
  school_id: string;
  student_id: string | null;
  student_name: string;
  seeking_class: string;
  section: string;
  academic_year: string;
  gender: string;
  date_of_birth: string;
  conversion_status: string;
  admission_number: string | null;
  converted_at: string | null;
  converted_by: string | null;
}

export interface AdmissionsConversionInput {
  enrollmentId: string;
  academicYear: string;
  academicYearId?: string | null;
  className: string;
  classId?: string | null;
  sectionName?: string | null;
  sectionId?: string | null;
  rollNumber?: string | null;
  convertedBy: string;
}

export interface AdmissionsConversionResult {
  admissionsEnrollmentId: string;
  studentId: string;
  profileId: string;
  sisEnrollmentId: string;
  admissionNumber: string;
  studentName: string;
  academicYear: string;
  className: string;
  sectionName: string | null;
  rollNumber: string | null;
  conversionStatus: string;
  idempotent: boolean;
}

export class AdmissionsEnrollmentNotFoundError extends Error {
  constructor(id: string) {
    super(`Admissions enrollment not found: ${id}`);
    this.name = "AdmissionsEnrollmentNotFoundError";
  }
}

export class ValidationError extends Error {
  constructor(message: string) {
    super(message);
    this.name = "ValidationError";
  }
}

function parseDateOfBirth(value: string): string | null {
  const trimmed = value.trim();
  if (!trimmed) return null;
  if (/^\d{4}-\d{2}-\d{2}$/.test(trimmed)) return trimmed;
  return null;
}

function requireAdmissionNumber(value: string | null, enrollmentId: string): string {
  const trimmed = value?.trim();
  if (!trimmed) {
    throw new ValidationError(
      `admission_number missing on admissions enrollment ${enrollmentId}`,
    );
  }
  return trimmed;
}

async function lockAdmissionsEnrollment(
  db: TenantQueryClient,
  organizationId: string,
  schoolId: string,
  enrollmentId: string,
): Promise<AdmissionsEnrollmentSourceRow | null> {
  const rows = await db.queryObject<AdmissionsEnrollmentSourceRow>(
    `SELECT
      id, organization_id, school_id, student_id, student_name,
      seeking_class, section, academic_year, gender, date_of_birth,
      conversion_status, admission_number,
      converted_at::text AS converted_at,
      converted_by::text AS converted_by
     FROM admissions_enrollments
     WHERE id = $1 AND organization_id = $2 AND school_id = $3
     FOR UPDATE`,
    [enrollmentId, organizationId, schoolId],
  );
  return rows[0] ?? null;
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

async function getProfileByStudentId(
  db: TenantQueryClient,
  organizationId: string,
  schoolId: string,
  studentId: string,
): Promise<{ id: string; admission_number: string } | null> {
  const rows = await db.queryObject<{ id: string; admission_number: string }>(
    `SELECT id, admission_number FROM student_profiles
     WHERE student_id = $1 AND organization_id = $2 AND school_id = $3`,
    [studentId, organizationId, schoolId],
  );
  return rows[0] ?? null;
}

async function getSisEnrollmentByYear(
  db: TenantQueryClient,
  organizationId: string,
  schoolId: string,
  studentId: string,
  academicYear: string,
): Promise<{
  id: string;
  class_name: string;
  section_name: string | null;
  roll_number: string | null;
} | null> {
  const rows = await db.queryObject<{
    id: string;
    class_name: string;
    section_name: string | null;
    roll_number: string | null;
  }>(
    `SELECT id, class_name, section_name, roll_number
     FROM sis_student_enrollments
     WHERE organization_id = $1 AND school_id = $2
       AND student_id = $3 AND academic_year = $4`,
    [organizationId, schoolId, studentId, academicYear],
  );
  return rows[0] ?? null;
}

async function ensureProfile(
  db: TenantQueryClient,
  organizationId: string,
  schoolId: string,
  studentId: string,
  source: AdmissionsEnrollmentSourceRow,
  createdBy: string,
): Promise<{ id: string; admission_number: string }> {
  const existing = await getProfileByStudentId(db, organizationId, schoolId, studentId);
  if (existing) return existing;

  const admissionNumber = requireAdmissionNumber(source.admission_number, source.id);
  // PSID: allocate the permanent Public Student ID for this newly-created profile.
  // Set-once; if the ON CONFLICT DO NOTHING path fires (profile already existed)
  // no row is inserted, so the allocated number is simply unused for this call —
  // an existing profile keeps its original PSID and is never re-allocated.
  const publicStudentId = await allocatePublicStudentId(db, organizationId, schoolId);
  const insertRows = await db.queryObject<{ id: string; admission_number: string }>(
    `INSERT INTO student_profiles (
      organization_id, school_id, student_id, admission_number, public_student_id,
      date_of_birth, gender, address, city, state, postal_code, country,
      created_by
    ) VALUES ($1, $2, $3, $4, $5, $6::date, $7, NULL, NULL, NULL, NULL, NULL, $8)
    ON CONFLICT (student_id) DO NOTHING
    RETURNING id, admission_number`,
    [
      organizationId,
      schoolId,
      studentId,
      admissionNumber,
      publicStudentId,
      parseDateOfBirth(source.date_of_birth),
      source.gender?.trim() || null,
      createdBy,
    ],
  );
  if (insertRows[0]) return insertRows[0];

  const profile = await getProfileByStudentId(db, organizationId, schoolId, studentId);
  if (!profile) {
    throw new ValidationError(`Failed to create or load profile for student ${studentId}`);
  }
  return profile;
}

async function ensureSisEnrollment(
  db: TenantQueryClient,
  organizationId: string,
  schoolId: string,
  studentId: string,
  input: AdmissionsConversionInput,
): Promise<{
  id: string;
  class_name: string;
  section_name: string | null;
  roll_number: string | null;
}> {
  const placement = await resolveAcademicPlacement(
    { db, organizationId, schoolId },
    {
      academicYear: input.academicYear,
      academicYearId: input.academicYearId,
      className: input.className,
      classId: input.classId,
      sectionName: input.sectionName,
      sectionId: input.sectionId,
    },
    { mode: "full" },
  );

  const existing = await getSisEnrollmentByYear(
    db,
    organizationId,
    schoolId,
    studentId,
    placement.academicYear,
  );
  if (existing) return existing;

  await clearCurrentEnrollmentsForStudent(db, organizationId, schoolId, studentId);

  const insertRows = await db.queryObject<{
    id: string;
    class_name: string;
    section_name: string | null;
    roll_number: string | null;
  }>(
    `INSERT INTO sis_student_enrollments (
      organization_id, school_id, student_id, academic_year, academic_year_id,
      class_name, class_id, section_name, section_id,
      roll_number, is_current, created_by
    ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, true, $11)
    ON CONFLICT (student_id, academic_year) DO NOTHING
    RETURNING id, class_name, section_name, roll_number`,
    [
      organizationId,
      schoolId,
      studentId,
      placement.academicYear,
      placement.academicYearId,
      placement.className,
      placement.classId,
      placement.sectionName,
      placement.sectionId,
      input.rollNumber ?? null,
      input.convertedBy,
    ],
  );
  if (insertRows[0]) return insertRows[0];

  const enrollment = await getSisEnrollmentByYear(
    db,
    organizationId,
    schoolId,
    studentId,
    placement.academicYear,
  );
  if (!enrollment) {
    throw new ValidationError(
      `Failed to create or load SIS enrollment for student ${studentId}`,
    );
  }
  return enrollment;
}

async function resolveSisEnrollmentForResult(
  db: TenantQueryClient,
  organizationId: string,
  schoolId: string,
  studentId: string,
  academicYear: string,
): Promise<{
  id: string;
  class_name: string;
  section_name: string | null;
  roll_number: string | null;
} | null> {
  const byYear = await getSisEnrollmentByYear(
    db,
    organizationId,
    schoolId,
    studentId,
    academicYear,
  );
  if (byYear) return byYear;

  const rows = await db.queryObject<{
    id: string;
    class_name: string;
    section_name: string | null;
    roll_number: string | null;
  }>(
    `SELECT id, class_name, section_name, roll_number
     FROM sis_student_enrollments
     WHERE organization_id = $1 AND school_id = $2 AND student_id = $3
       AND is_current = true
     ORDER BY created_at DESC
     LIMIT 1`,
    [organizationId, schoolId, studentId],
  );
  return rows[0] ?? null;
}

async function buildResultFromState(
  db: TenantQueryClient,
  organizationId: string,
  schoolId: string,
  source: AdmissionsEnrollmentSourceRow,
  input: AdmissionsConversionInput,
  idempotent: boolean,
): Promise<AdmissionsConversionResult> {
  const studentId = source.student_id!;
  const profile = await getProfileByStudentId(db, organizationId, schoolId, studentId);
  const enrollment = await resolveSisEnrollmentForResult(
    db,
    organizationId,
    schoolId,
    studentId,
    input.academicYear,
  );
  if (!profile || !enrollment) {
    throw new ValidationError(
      `Conversion state incomplete for admissions enrollment ${source.id}`,
    );
  }

  return {
    admissionsEnrollmentId: source.id,
    studentId,
    profileId: profile.id,
    sisEnrollmentId: enrollment.id,
    admissionNumber: profile.admission_number,
    studentName: source.student_name,
    academicYear: input.academicYear,
    className: enrollment.class_name,
    sectionName: enrollment.section_name,
    rollNumber: enrollment.roll_number,
    conversionStatus: source.conversion_status,
    idempotent,
  };
}

/**
 * Funnel-vocab fix — advance the originating lead to stage='joined' exactly
 * once when a conversion commits. The dashboard/reports conversionRate counts
 * stage='joined', but nothing on the conversion path ever set it, so the rate
 * read a permanent 0. Linkage: admissions_enrollments.application_id →
 * admissions_applications.lead_id → admissions_leads.id.
 *
 * Idempotency: the UPDATE only fires when the lead is not already 'joined'
 * (`AND stage <> 'joined'`), so replaying a committed conversion is a no-op.
 * A conversion with no lead linkage (walk-in / null application) is skipped.
 * No money math — this only moves the CRM stage label.
 */
async function markOriginatingLeadJoined(
  db: TenantQueryClient,
  organizationId: string,
  schoolId: string,
  enrollmentId: string,
): Promise<void> {
  const rows = await db.queryObject<{ lead_id: string | null }>(
    `SELECT app.lead_id AS lead_id
     FROM admissions_enrollments e
     INNER JOIN admissions_applications app ON app.id = e.application_id
     WHERE e.id = $1 AND e.organization_id = $2 AND e.school_id = $3`,
    [enrollmentId, organizationId, schoolId],
  );
  const leadId = rows[0]?.lead_id ?? null;
  if (!leadId) return;

  await db.queryObject(
    `UPDATE admissions_leads SET
      stage = 'joined',
      updated_at = timezone('utc', now())
     WHERE id = $1 AND organization_id = $2 AND school_id = $3
       AND stage <> 'joined'`,
    [leadId, organizationId, schoolId],
  );
}

export async function convertAdmissionsEnrollment(
  db: TenantQueryClient,
  organizationId: string,
  schoolId: string,
  input: AdmissionsConversionInput,
): Promise<AdmissionsConversionResult> {
  const enrollmentId = input.enrollmentId.trim();
  const academicYear = input.academicYear.trim();
  const className = input.className.trim();
  if (!enrollmentId) throw new ValidationError("enrollmentId is required");
  if (!academicYear) throw new ValidationError("academicYear is required");
  if (!className) throw new ValidationError("className is required");

  const source = await lockAdmissionsEnrollment(
    db,
    organizationId,
    schoolId,
    enrollmentId,
  );
  if (!source) throw new AdmissionsEnrollmentNotFoundError(enrollmentId);

  if (!source.student_id) {
    throw new ValidationError(
      `Admissions enrollment ${enrollmentId} is not linked to a student`,
    );
  }

  if (!await studentExists(db, organizationId, schoolId, source.student_id)) {
    throw new StudentNotFoundError(source.student_id);
  }

  if (source.conversion_status === "converted") {
    return await buildResultFromState(
      db,
      organizationId,
      schoolId,
      source,
      input,
      true,
    );
  }

  await ensureProfile(
    db,
    organizationId,
    schoolId,
    source.student_id,
    source,
    input.convertedBy,
  );
  await ensureSisEnrollment(db, organizationId, schoolId, source.student_id, input);

  await db.queryObject(
    `UPDATE admissions_enrollments SET
      conversion_status = 'converted',
      converted_at = timezone('utc', now()),
      converted_by = $1
     WHERE id = $2 AND organization_id = $3 AND school_id = $4`,
    [input.convertedBy, enrollmentId, organizationId, schoolId],
  );

  // Funnel-vocab: a committed conversion advances the originating lead to
  // 'joined' so the dashboard/reports conversionRate reflects reality. Guarded
  // to fire exactly once (idempotent path above returns before reaching here).
  await markOriginatingLeadJoined(db, organizationId, schoolId, enrollmentId);

  const updated = await lockAdmissionsEnrollment(
    db,
    organizationId,
    schoolId,
    enrollmentId,
  );
  if (!updated) throw new AdmissionsEnrollmentNotFoundError(enrollmentId);

  return await buildResultFromState(
    db,
    organizationId,
    schoolId,
    { ...updated, conversion_status: "converted" },
    input,
    false,
  );
}

/** Probe: non-school scopes denied admissions conversion reads. */
export const SIS_CONVERSION_PROBE_SQL = `
  SELECT count(*)::text AS count
  FROM admissions_enrollments ae
  INNER JOIN students s ON s.id = ae.student_id
  WHERE ae.conversion_status = 'pending'
`;

/** Probe: cross-school conversion target visibility. */
export const SIS_CONVERSION_TARGET_PROBE_SQL = `
  SELECT count(*)::text AS count
  FROM admissions_enrollments
  WHERE id = $1
`;

/** Probe: cross-school converted enrollment visibility. */
export const SIS_CONVERSION_CONVERTED_PROBE_SQL = `
  SELECT count(*)::text AS count
  FROM admissions_enrollments
  WHERE id = $1 AND conversion_status = 'converted'
`;
