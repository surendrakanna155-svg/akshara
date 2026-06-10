import type { TenantQueryClient } from "../tenant_db.ts";
import {
  createImportedStudent,
  ensureSchoolMembership,
  findDuplicateStudent,
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

function parseStudentRow(raw: Record<string, unknown>): { row?: StudentImportRow; errors: string[] } {
  const errors: string[] = [];
  const studentName = String(raw.studentName ?? raw.student_name ?? "").trim();
  const admissionNumber = String(raw.admissionNumber ?? raw.admission_number ?? "").trim();
  const classLabel = String(raw.classLabel ?? raw.class ?? raw.class_label ?? "").trim();
  const sectionLabel = String(raw.sectionLabel ?? raw.section ?? raw.section_label ?? "").trim();
  const academicYear = String(raw.academicYear ?? raw.academic_year ?? "").trim();
  const parentName = String(raw.parentName ?? raw.parent_name ?? "").trim();
  const parentPhone = String(raw.parentPhone ?? raw.parent_phone ?? "").trim();

  if (!studentName) errors.push("studentName is required");
  if (!admissionNumber) errors.push("admissionNumber is required");
  if (!classLabel) errors.push("classLabel is required");
  if (!sectionLabel) errors.push("sectionLabel is required");
  if (!academicYear) errors.push("academicYear is required");
  if (!parentName) errors.push("parentName is required");
  if (!parentPhone) errors.push("parentPhone is required");
  if (parentPhone && !/^\+?\d{10,15}$/.test(parentPhone.replace(/\s+/g, ""))) {
    errors.push("parentPhone is invalid");
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
      studentPhone: String(raw.studentPhone ?? raw.student_phone ?? "").trim() || undefined,
      gender: String(raw.gender ?? "").trim() || undefined,
      dateOfBirth: String(raw.dateOfBirth ?? raw.date_of_birth ?? "").trim() || undefined,
      rollNumber: String(raw.rollNumber ?? raw.roll_number ?? "").trim() || undefined,
    },
    errors,
  };
}

function parseTeacherRow(raw: Record<string, unknown>): { row?: TeacherImportRow; errors: string[] } {
  const errors: string[] = [];
  const displayName = String(raw.displayName ?? raw.name ?? raw.display_name ?? "").trim();
  const phone = String(raw.phone ?? "").trim();
  const role = String(raw.role ?? "teacher").trim().toLowerCase();
  if (!displayName) errors.push("displayName is required");
  if (!phone) errors.push("phone is required");
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
  const lines = csvText.trim().split(/\r?\n/).filter((line) => line.trim().length > 0);
  if (lines.length < 2) return [];
  const headers = lines[0]!.split(",").map((h) => h.trim());
  return lines.slice(1).map((line) => {
    const values = line.split(",").map((v) => v.trim().replace(/^"|"$/g, ""));
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

  for (let i = 0; i < rawRows.length; i++) {
    const raw = rawRows[i]!;
    const rowNumber = i + 1;
    const parsed = importType === "student"
      ? parseStudentRow(raw)
      : parseTeacherRow(raw);

    let status = "valid";
    let matchedEntityId: string | null = null;

    if (parsed.errors.length) {
      status = "invalid";
      invalid++;
    } else if (importType === "student" && parsed.row) {
      matchedEntityId = await findDuplicateStudent(
        db,
        organizationId,
        schoolId,
        (parsed.row as StudentImportRow).admissionNumber,
      );
      if (matchedEntityId) {
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
        JSON.stringify(parsed.errors),
        matchedEntityId,
      ],
    );

    preview.push({
      rowNumber,
      status,
      payload: raw,
      errors: parsed.errors,
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
        const parsed = parseStudentRow(row.payload);
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
        const parsed = parseTeacherRow(row.payload);
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
    if (job.import_type === "student") {
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
