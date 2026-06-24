import type { TenantQueryClient } from "../tenant_db.ts";
import {
  createImportedStudent,
  createPlaceholderStudent,
  ensureSchoolMembership,
  findDuplicateStudent,
  findStudentByAadhaarHash,
  hashAadhaar,
  isValidAadhaar,
  normalizeAadhaar,
  normalizeImportPhone,
  rollbackImportedStudent,
  type StudentImportRow,
  type TeacherImportRow,
  upsertUserByPhone,
} from "./onboarding_user_provisioning.ts";

export const ONBOARDING_IMPORT_JOB_PROBE_SCHOOL_A = "d7000000-0000-4000-8000-000000000001";
export const ONBOARDING_IMPORT_JOB_PROBE_SCHOOL_B = "d7000000-0000-4000-8000-000000000002";
export const ONBOARDING_IMPORT_JOB_PROBE_SQL = `
  SELECT count(*)::text AS count FROM onboarding_import_jobs WHERE id = $1::uuid
`;

export const ONBOARDING_INVITE_PROBE_SCHOOL_A = "d7100000-0000-4000-8000-000000000001";
export const ONBOARDING_INVITE_PROBE_SCHOOL_B = "d7100000-0000-4000-8000-000000000002";
export const ONBOARDING_INVITE_PROBE_SQL = `
  SELECT count(*)::text AS count FROM onboarding_invites WHERE id = $1::uuid
`;

export interface ImportJobRow {
  id: string;
  organization_id: string;
  school_id: string;
  import_type: string;
  status: string;
  file_name: string;
  total_rows: number;
  valid_rows: number;
  invalid_rows: number;
  duplicate_rows: number;
  committed_rows: number;
  report: Record<string, unknown>;
  created_at: string;
  updated_at: string;
}

export interface ImportPreviewRow {
  rowNumber: number;
  status: string;
  payload: Record<string, unknown>;
  errors: string[];
  matchedEntityId: string | null;
}

const IMPORT_PHONE_PATTERN = /^\+?\d{10,15}$/;
const ISO_DATE_PATTERN = /^\d{4}-\d{2}-\d{2}$/;

function isValidImportPhone(phone: string): boolean {
  return IMPORT_PHONE_PATTERN.test(phone.replace(/\s+/g, ""));
}

/** True when value is yyyy-mm-dd AND a real calendar date. */
export function isValidIsoDate(value: string): boolean {
  if (!ISO_DATE_PATTERN.test(value)) return false;
  const date = new Date(`${value}T00:00:00Z`);
  return !Number.isNaN(date.getTime()) &&
    date.toISOString().slice(0, 10) === value;
}

/** Parses one CSV line respecting double-quoted fields (commas inside quotes). */
export function parseCsvLine(line: string): string[] {
  const values: string[] = [];
  let current = "";
  let inQuotes = false;
  for (let i = 0; i < line.length; i++) {
    const ch = line[i]!;
    if (ch === '"') {
      if (inQuotes && line[i + 1] === '"') {
        current += '"';
        i++;
      } else {
        inQuotes = !inQuotes;
      }
    } else if (ch === "," && !inQuotes) {
      values.push(current.trim().replace(/^"|"$/g, ""));
      current = "";
    } else {
      current += ch;
    }
  }
  values.push(current.trim().replace(/^"|"$/g, ""));
  return values;
}

export function parseStudentImportRow(
  raw: Record<string, unknown>,
): { row?: StudentImportRow; errors: string[] } {
  const errors: string[] = [];
  const studentName = String(raw.studentName ?? raw.student_name ?? "").trim();
  const admissionNumber = String(raw.admissionNumber ?? raw.admission_number ?? "").trim();
  const classLabel = String(raw.classLabel ?? raw.class ?? raw.class_label ?? "").trim();
  const sectionLabel = String(raw.sectionLabel ?? raw.section ?? raw.section_label ?? "").trim();
  const academicYear = String(raw.academicYear ?? raw.academic_year ?? "").trim();
  const parentName = String(raw.parentName ?? raw.parent_name ?? "").trim();
  const parentPhone = String(raw.parentPhone ?? raw.parent_phone ?? "").trim();
  const studentPhone = String(raw.studentPhone ?? raw.student_phone ?? "").trim();
  const motherName = String(raw.motherName ?? raw.mother_name ?? "").trim();
  const gender = String(raw.gender ?? "").trim();
  const dob = String(
    raw.dob ?? raw.dateOfBirth ?? raw.date_of_birth ?? "",
  ).trim();
  const aadhaarRaw = String(raw.aadhaar ?? raw.aadhaar_number ?? raw.aadhaarNumber ?? "")
    .trim();

  if (!studentName) errors.push("studentName is required");
  if (!admissionNumber) errors.push("admissionNumber is required");
  if (!classLabel) errors.push("classLabel is required");
  if (!sectionLabel) errors.push("sectionLabel is required");
  if (!academicYear) errors.push("academicYear is required");
  if (!parentName) errors.push("parentName is required");
  if (!parentPhone) errors.push("parentPhone is required");
  if (parentPhone && !isValidImportPhone(parentPhone)) {
    errors.push("parentPhone must be 10–15 digits (optional + prefix)");
  }
  if (studentPhone && !isValidImportPhone(studentPhone)) {
    errors.push("studentPhone must be 10–15 digits (optional + prefix)");
  }
  if (aadhaarRaw && !isValidAadhaar(aadhaarRaw)) {
    errors.push("aadhaar must be 12 digits");
  }
  if (dob && !isValidIsoDate(dob)) {
    errors.push("dob must be a valid date (yyyy-mm-dd)");
  }

  if (errors.length) return { errors };

  return {
    row: {
      studentName,
      admissionNumber,
      classLabel,
      sectionLabel,
      academicYear,
      parentName,
      parentPhone,
      studentPhone: studentPhone || undefined,
      gender: gender || undefined,
      dateOfBirth: dob || undefined,
      rollNumber: String(raw.rollNumber ?? raw.roll_number ?? "").trim() || undefined,
      motherName: motherName || undefined,
      aadhaar: aadhaarRaw ? normalizeAadhaar(aadhaarRaw) : undefined,
    },
    errors,
  };
}

export function parseTeacherImportRow(
  raw: Record<string, unknown>,
): { row?: TeacherImportRow; errors: string[] } {
  const errors: string[] = [];
  const displayName = String(raw.displayName ?? raw.name ?? raw.display_name ?? "").trim();
  const phone = String(raw.phone ?? "").trim();
  const role = String(raw.role ?? "teacher").trim().toLowerCase();
  if (!displayName) errors.push("displayName is required");
  if (!phone) errors.push("phone is required");
  if (phone && !isValidImportPhone(phone)) {
    errors.push("phone must be 10–15 digits (optional + prefix)");
  }
  if (!["teacher", "principal", "schooladmin"].includes(role)) {
    errors.push("role must be teacher, principal, or schoolAdmin");
  }
  if (errors.length) return { errors };
  return {
    row: {
      displayName,
      phone,
      email: String(raw.email ?? "").trim() || undefined,
      role: role === "schooladmin" ? "schoolAdmin" : role,
    },
    errors,
  };
}

export function parseCsvText(csvText: string): Record<string, unknown>[] {
  const normalized = csvText.replace(/^\uFEFF/, "").trim();
  const lines = normalized.split(/\r?\n/).filter((line) => line.trim().length > 0);
  if (lines.length < 2) return [];
  const headers = parseCsvLine(lines[0]!).map((h) => h.trim());
  return lines.slice(1).map((line) => {
    const values = parseCsvLine(line);
    const row: Record<string, unknown> = {};
    headers.forEach((header, index) => {
      row[header] = values[index] ?? "";
    });
    return row;
  });
}

export async function createImportPreview(
  db: TenantQueryClient,
  organizationId: string,
  schoolId: string,
  createdBy: string,
  importType: "student" | "teacher",
  fileName: string,
  rawRows: Record<string, unknown>[],
): Promise<{ job: ImportJobRow; preview: ImportPreviewRow[] }> {
  const jobRows = await db.queryObject<ImportJobRow>(
    `INSERT INTO onboarding_import_jobs (
       organization_id, school_id, import_type, status, file_name,
       total_rows, created_by
     ) VALUES ($1, $2, $3, 'draft', $4, $5, $6)
     RETURNING *`,
    [organizationId, schoolId, importType, fileName, rawRows.length, createdBy],
  );
  const job = jobRows[0]!;

  const preview: ImportPreviewRow[] = [];
  let valid = 0;
  let invalid = 0;
  let duplicate = 0;
  // Aadhaar hashes already seen earlier in THIS file → in-file dup detection.
  const seenAadhaarHashes = new Map<string, number>();

  for (let i = 0; i < rawRows.length; i++) {
    const raw = rawRows[i]!;
    const rowNumber = i + 1;
    const parsed = importType === "student"
      ? parseStudentImportRow(raw)
      : parseTeacherImportRow(raw);

    let status = "valid";
    let matchedEntityId: string | null = null;
    const errors = [...parsed.errors];

    if (parsed.errors.length) {
      status = "invalid";
      invalid++;
    } else if (importType === "student" && parsed.row) {
      const studentRow = parsed.row as StudentImportRow;
      matchedEntityId = await findDuplicateStudent(
        db,
        organizationId,
        schoolId,
        studentRow.admissionNumber,
      );

      // Aadhaar dedupe: within this file AND against existing students.
      if (!matchedEntityId && studentRow.aadhaar) {
        const hash = await hashAadhaar(studentRow.aadhaar);
        if (seenAadhaarHashes.has(hash)) {
          matchedEntityId = null;
          errors.push("duplicate Aadhaar");
        } else {
          const existing = await findStudentByAadhaarHash(
            db,
            organizationId,
            schoolId,
            hash,
          );
          if (existing) {
            matchedEntityId = existing;
            errors.push("duplicate Aadhaar");
          } else {
            seenAadhaarHashes.set(hash, rowNumber);
          }
        }
      }

      if (errors.length && errors.includes("duplicate Aadhaar") && !matchedEntityId) {
        // In-file duplicate (no DB match): treat as duplicate row.
        status = "duplicate";
        duplicate++;
      } else if (matchedEntityId) {
        status = "duplicate";
        duplicate++;
      } else {
        valid++;
      }
    } else {
      valid++;
    }

    await db.queryObject(
      `INSERT INTO onboarding_import_rows (
         job_id, organization_id, school_id, row_number, payload, status, errors, matched_entity_id
       ) VALUES ($1, $2, $3, $4, $5::jsonb, $6, $7::jsonb, $8)`,
      [
        job.id,
        organizationId,
        schoolId,
        rowNumber,
        JSON.stringify(raw),
        status,
        JSON.stringify(errors),
        matchedEntityId,
      ],
    );

    preview.push({
      rowNumber,
      status,
      payload: raw,
      errors,
      matchedEntityId,
    });
  }

  const updated = await db.queryObject<ImportJobRow>(
    `UPDATE onboarding_import_jobs
     SET status = 'previewed', valid_rows = $2, invalid_rows = $3,
         duplicate_rows = $4, updated_at = timezone('utc', now())
     WHERE id = $1 RETURNING *`,
    [job.id, valid, invalid, duplicate],
  );

  return { job: updated[0]!, preview };
}

export async function commitImportJob(
  db: TenantQueryClient,
  organizationId: string,
  schoolId: string,
  jobId: string,
): Promise<ImportJobRow> {
  const jobRows = await db.queryObject<ImportJobRow>(
    `SELECT * FROM onboarding_import_jobs
     WHERE id = $1 AND organization_id = $2 AND school_id = $3`,
    [jobId, organizationId, schoolId],
  );
  const job = jobRows[0];
  if (!job) throw new Error("IMPORT_JOB_NOT_FOUND");
  if (job.status !== "previewed") throw new Error("IMPORT_JOB_NOT_PREVIEWED");

  const rows = await db.queryObject<{
    id: string;
    row_number: number;
    payload: Record<string, unknown>;
    status: string;
  }>(
    `SELECT id, row_number, payload, status FROM onboarding_import_rows
     WHERE job_id = $1 AND status = 'valid'
     ORDER BY row_number ASC`,
    [jobId],
  );

  let committed = 0;
  const failures: Array<{ rowNumber: number; error: string }> = [];

  for (const row of rows) {
    try {
      await db.queryObject(`SAVEPOINT onboarding_import_row`);
      if (job.import_type === "student") {
        const parsed = parseStudentImportRow(row.payload);
        if (!parsed.row) continue;
        const parentUserId = await upsertUserByPhone(
          db,
          parsed.row.parentPhone,
          parsed.row.parentName,
        );
        let studentUserId: string | null = null;
        if (parsed.row.studentPhone) {
          studentUserId = await upsertUserByPhone(
            db,
            parsed.row.studentPhone,
            parsed.row.studentName,
          );
        }
        const studentId = await createImportedStudent(
          db,
          organizationId,
          schoolId,
          parsed.row,
          parentUserId,
          studentUserId,
        );
        await db.queryObject(
          `UPDATE onboarding_import_rows
           SET status = 'committed', created_entity_id = $2
           WHERE id = $1`,
          [row.id, studentId],
        );
      } else {
        const parsed = parseTeacherImportRow(row.payload);
        if (!parsed.row) continue;
        const userId = await upsertUserByPhone(
          db,
          parsed.row.phone,
          parsed.row.displayName,
          parsed.row.email,
        );
        await ensureSchoolMembership(db, userId, schoolId, parsed.row.role);
        await db.queryObject(
          `UPDATE onboarding_import_rows
           SET status = 'committed', created_entity_id = $2
           WHERE id = $1`,
          [row.id, userId],
        );
      }
      committed++;
      await db.queryObject(`RELEASE SAVEPOINT onboarding_import_row`);
    } catch (error) {
      await db.queryObject(`ROLLBACK TO SAVEPOINT onboarding_import_row`);
      failures.push({
        rowNumber: row.row_number,
        error: error instanceof Error ? error.message : "commit failed",
      });
    }
  }

  const updated = await db.queryObject<ImportJobRow>(
    `UPDATE onboarding_import_jobs
     SET status = 'committed', committed_rows = $2,
         report = report || $3::jsonb,
         updated_at = timezone('utc', now())
     WHERE id = $1 RETURNING *`,
    [jobId, committed, JSON.stringify({ failures })],
  );
  return updated[0]!;
}

export async function rollbackImportJob(
  db: TenantQueryClient,
  organizationId: string,
  schoolId: string,
  jobId: string,
): Promise<ImportJobRow> {
  const jobRows = await db.queryObject<ImportJobRow>(
    `SELECT * FROM onboarding_import_jobs
     WHERE id = $1 AND organization_id = $2 AND school_id = $3`,
    [jobId, organizationId, schoolId],
  );
  const job = jobRows[0];
  if (!job) throw new Error("IMPORT_JOB_NOT_FOUND");
  if (job.status !== "committed") throw new Error("IMPORT_JOB_NOT_COMMITTED");

  const rows = await db.queryObject<{ id: string; created_entity_id: string | null }>(
    `SELECT id, created_entity_id FROM onboarding_import_rows
     WHERE job_id = $1 AND status = 'committed'`,
    [jobId],
  );

  for (const row of rows) {
    if (!row.created_entity_id) continue;
    if (job.import_type === "student" || job.import_type === "student_placeholder") {
      await rollbackImportedStudent(
        db,
        organizationId,
        schoolId,
        row.created_entity_id,
      );
    }
    await db.queryObject(
      `UPDATE onboarding_import_rows SET status = 'rolled_back' WHERE id = $1`,
      [row.id],
    );
  }

  const updated = await db.queryObject<ImportJobRow>(
    `UPDATE onboarding_import_jobs
     SET status = 'rolled_back', updated_at = timezone('utc', now())
     WHERE id = $1 RETURNING *`,
    [jobId],
  );
  return updated[0]!;
}

export interface PlaceholderSectionInput {
  sectionLabel: string;
  studentCount: number;
}

export interface PlaceholderClassInput {
  classLabel: string;
  sections: PlaceholderSectionInput[];
}

export interface GeneratePlaceholderInput {
  academicYear: string;
  classes: PlaceholderClassInput[];
}

/**
 * Generates placeholder students (is_placeholder = true, no parent user) using
 * the existing import-job machinery so the whole batch is rollbackable via
 * rollbackImportJob. Idempotent per (school, academicYear, classLabel,
 * sectionLabel, roll): re-running creates no duplicate students.
 *
 * The job is created with import_type = 'student_placeholder' and marked
 * 'committed'. Each newly-created placeholder gets a committed import_row whose
 * created_entity_id is the student id, so rollback removes exactly those.
 */
export async function generatePlaceholderStudents(
  db: TenantQueryClient,
  organizationId: string,
  schoolId: string,
  createdBy: string,
  input: GeneratePlaceholderInput,
): Promise<{ job: ImportJobRow; generatedCount: number }> {
  const academicYear = input.academicYear.trim();
  if (!academicYear) throw new Error("PLACEHOLDER_ACADEMIC_YEAR_REQUIRED");
  if (!Array.isArray(input.classes) || input.classes.length === 0) {
    throw new Error("PLACEHOLDER_CLASSES_REQUIRED");
  }

  // Total requested rows (for total_rows accounting).
  let totalRequested = 0;
  for (const cls of input.classes) {
    for (const section of cls.sections ?? []) {
      const count = Number(section.studentCount) || 0;
      if (count < 0) throw new Error("PLACEHOLDER_COUNT_INVALID");
      totalRequested += count;
    }
  }

  const jobRows = await db.queryObject<ImportJobRow>(
    `INSERT INTO onboarding_import_jobs (
       organization_id, school_id, import_type, status, file_name,
       total_rows, created_by
     ) VALUES ($1, $2, 'student_placeholder', 'committed', $3, $4, $5)
     RETURNING *`,
    [
      organizationId,
      schoolId,
      `placeholders_${academicYear}.generated`,
      totalRequested,
      createdBy,
    ],
  );
  const job = jobRows[0]!;

  let generatedCount = 0;
  let rowNumber = 0;
  for (const cls of input.classes) {
    const classLabel = String(cls.classLabel ?? "").trim();
    if (!classLabel) throw new Error("PLACEHOLDER_CLASS_LABEL_REQUIRED");
    for (const section of cls.sections ?? []) {
      const sectionLabel = String(section.sectionLabel ?? "").trim();
      if (!sectionLabel) throw new Error("PLACEHOLDER_SECTION_LABEL_REQUIRED");
      const count = Number(section.studentCount) || 0;
      for (let n = 1; n <= count; n++) {
        rowNumber++;
        const { studentId, created } = await createPlaceholderStudent(
          db,
          organizationId,
          schoolId,
          academicYear,
          classLabel,
          sectionLabel,
          n,
        );
        if (created) generatedCount++;
        await db.queryObject(
          `INSERT INTO onboarding_import_rows (
             job_id, organization_id, school_id, row_number, payload, status,
             errors, created_entity_id
           ) VALUES ($1, $2, $3, $4, $5::jsonb, $6, '[]'::jsonb, $7)`,
          [
            job.id,
            organizationId,
            schoolId,
            rowNumber,
            JSON.stringify({ classLabel, sectionLabel, academicYear, roll: n }),
            // Only newly-created placeholders are rolled back; pre-existing ones
            // are skipped so rollback never deletes data this run didn't create.
            created ? "committed" : "duplicate",
            created ? studentId : null,
          ],
        );
      }
    }
  }

  const updated = await db.queryObject<ImportJobRow>(
    `UPDATE onboarding_import_jobs
     SET valid_rows = $2, committed_rows = $2,
         duplicate_rows = $3,
         report = report || $4::jsonb,
         updated_at = timezone('utc', now())
     WHERE id = $1 RETURNING *`,
    [
      job.id,
      generatedCount,
      totalRequested - generatedCount,
      JSON.stringify({ generatedCount, academicYear }),
    ],
  );

  return { job: updated[0]!, generatedCount };
}

export async function getImportJob(
  db: TenantQueryClient,
  organizationId: string,
  schoolId: string,
  jobId: string,
): Promise<ImportJobRow | null> {
  const rows = await db.queryObject<ImportJobRow>(
    `SELECT * FROM onboarding_import_jobs
     WHERE id = $1 AND organization_id = $2 AND school_id = $3`,
    [jobId, organizationId, schoolId],
  );
  return rows[0] ?? null;
}

export async function listImportJobs(
  db: TenantQueryClient,
  organizationId: string,
  schoolId: string,
): Promise<ImportJobRow[]> {
  return await db.queryObject<ImportJobRow>(
    `SELECT * FROM onboarding_import_jobs
     WHERE organization_id = $1 AND school_id = $2
     ORDER BY created_at DESC LIMIT 50`,
    [organizationId, schoolId],
  );
}

export function buildInviteDeepLink(token: string): string {
  const base = Deno.env.get("APP_DEEP_LINK_BASE") ?? "https://app.akshara.test";
  return `${base}/invite/${token}`;
}

export function buildWhatsAppInviteLink(deepLink: string, label: string): string {
  const text = encodeURIComponent(`Welcome to Akshara ERP — ${label}. Open: ${deepLink}`);
  return `https://wa.me/?text=${text}`;
}

export async function createInvite(
  db: TenantQueryClient,
  organizationId: string,
  schoolId: string,
  createdBy: string,
  input: {
    inviteType: "parent" | "teacher" | "student";
    recipientPhone: string;
    recipientLabel: string;
    studentId?: string | null;
    channel?: "sms" | "whatsapp";
  },
): Promise<Record<string, unknown>> {
  const token = crypto.randomUUID().replace(/-/g, "").slice(0, 24);
  const deepLink = buildInviteDeepLink(token);
  const phone = normalizeImportPhone(input.recipientPhone);
  const userId = await upsertUserByPhone(db, phone, input.recipientLabel);

  const rows = await db.queryObject<Record<string, unknown>>(
    `INSERT INTO onboarding_invites (
       organization_id, school_id, invite_type, recipient_phone, recipient_label,
       student_id, user_id, token, status, channel, deep_link, expires_at, created_by
     ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, 'pending', $9, $10,
       timezone('utc', now()) + interval '7 days', $11)
     RETURNING *`,
    [
      organizationId,
      schoolId,
      input.inviteType,
      phone,
      input.recipientLabel,
      input.studentId ?? null,
      userId,
      token,
      input.channel ?? "whatsapp",
      deepLink,
      createdBy,
    ],
  );
  const invite = rows[0]!;
  return {
    ...invite,
    whatsappLink: buildWhatsAppInviteLink(deepLink, input.recipientLabel),
  };
}

export async function markInviteSent(
  db: TenantQueryClient,
  inviteId: string,
): Promise<void> {
  await db.queryObject(
    `UPDATE onboarding_invites
     SET status = 'sent', sent_at = timezone('utc', now()),
         updated_at = timezone('utc', now())
     WHERE id = $1`,
    [inviteId],
  );
}

export async function listInvites(
  db: TenantQueryClient,
  organizationId: string,
  schoolId: string,
): Promise<Record<string, unknown>[]> {
  return await db.queryObject<Record<string, unknown>>(
    `SELECT * FROM onboarding_invites
     WHERE organization_id = $1 AND school_id = $2
     ORDER BY created_at DESC LIMIT 100`,
    [organizationId, schoolId],
  );
}
