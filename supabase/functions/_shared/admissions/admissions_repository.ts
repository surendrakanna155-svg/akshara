import type { TenantQueryClient } from "../tenant_db.ts";
import { resolveAcademicPlacement } from "../academic/academic_catalog_resolver.ts";
import { createHandoffFromEnrollment } from "./admissions_handoffs_repository.ts";
import { normalizePhone } from "./admissions_format.ts";
import type {
  AdmissionsApplicationRow,
  AdmissionsApprovalRow,
  AdmissionsDocumentRow,
  AdmissionsEnrollmentRow,
  AdmissionsLeadActivityRow,
  AdmissionsLeadFollowUpRow,
  AdmissionsLeadRow,
} from "./admissions_mapper.ts";

export interface PaginationParams {
  page: number;
  pageSize: number;
}

export interface PaginationResult<T> {
  items: T[];
  total: number;
  page: number;
  pageSize: number;
  hasMore: boolean;
}

function offsetFor(page: number, pageSize: number): number {
  return Math.max(0, (page - 1) * pageSize);
}

// ─── Leads ───────────────────────────────────────────────────────────────────

export async function listLeads(
  db: TenantQueryClient,
  organizationId: string,
  schoolId: string,
  pagination: PaginationParams,
): Promise<PaginationResult<AdmissionsLeadRow>> {
  const limit = Math.min(Math.max(pagination.pageSize, 1), 100);
  const offset = offsetFor(pagination.page, limit);

  const total = await db.queryCount(
    `SELECT count(*)::text AS count FROM admissions_leads
     WHERE organization_id = $1 AND school_id = $2`,
    [organizationId, schoolId],
  );

  const items = await db.queryObject<AdmissionsLeadRow>(
    `SELECT * FROM admissions_leads
     WHERE organization_id = $1 AND school_id = $2
     ORDER BY created_at DESC
     LIMIT $3 OFFSET $4`,
    [organizationId, schoolId, limit, offset],
  );

  return {
    items,
    total,
    page: pagination.page,
    pageSize: limit,
    hasMore: offset + items.length < total,
  };
}

export async function getLeadById(
  db: TenantQueryClient,
  organizationId: string,
  schoolId: string,
  leadId: string,
): Promise<AdmissionsLeadRow | null> {
  const rows = await db.queryObject<AdmissionsLeadRow>(
    `SELECT * FROM admissions_leads
     WHERE id = $1 AND organization_id = $2 AND school_id = $3`,
    [leadId, organizationId, schoolId],
  );
  return rows[0] ?? null;
}

export interface CreateLeadInput {
  parentName: string;
  studentName: string;
  classLabel: string;
  phone: string;
  source: string;
  campaign: string;
  counselor: string;
  email: string;
  address: string;
  notes: string;
}

export async function createLead(
  db: TenantQueryClient,
  organizationId: string,
  schoolId: string,
  input: CreateLeadInput,
): Promise<AdmissionsLeadRow> {
  const rows = await db.queryObject<AdmissionsLeadRow>(
    `INSERT INTO admissions_leads (
      organization_id, school_id, parent_name, student_name, class_label, phone,
      source, campaign, stage, counselor, score, next_follow_up_label,
      email, address, notes
    ) VALUES (
      $1, $2, $3, $4, $5, $6,
      $7, $8, 'new_enquiry', $9, 'warm', 'Not scheduled',
      $10, $11, $12
    )
    RETURNING *`,
    [
      organizationId,
      schoolId,
      input.parentName,
      input.studentName,
      input.classLabel,
      input.phone,
      input.source,
      input.campaign,
      input.counselor,
      input.email || null,
      input.address || null,
      input.notes || null,
    ],
  );
  return rows[0]!;
}

export interface UpdateLeadInput {
  parentName?: string;
  studentName?: string;
  classLabel?: string;
  phone?: string;
  source?: string;
  campaign?: string;
  email?: string;
  address?: string;
  notes?: string;
}

export async function updateLead(
  db: TenantQueryClient,
  organizationId: string,
  schoolId: string,
  leadId: string,
  input: UpdateLeadInput,
): Promise<AdmissionsLeadRow | null> {
  const existing = await getLeadById(db, organizationId, schoolId, leadId);
  if (!existing) return null;

  const rows = await db.queryObject<AdmissionsLeadRow>(
    `UPDATE admissions_leads SET
      parent_name = $4,
      student_name = $5,
      class_label = $6,
      phone = $7,
      source = $8,
      campaign = $9,
      email = $10,
      address = $11,
      notes = $12,
      updated_at = timezone('utc', now())
    WHERE id = $1 AND organization_id = $2 AND school_id = $3
    RETURNING *`,
    [
      leadId,
      organizationId,
      schoolId,
      input.parentName ?? existing.parent_name,
      input.studentName ?? existing.student_name,
      input.classLabel ?? existing.class_label,
      input.phone ?? existing.phone,
      input.source ?? existing.source,
      input.campaign ?? existing.campaign,
      input.email ?? existing.email ?? "",
      input.address ?? existing.address ?? "",
      input.notes ?? existing.notes ?? "",
    ],
  );
  return rows[0] ?? null;
}

// ─── Lead CRM: assignment, stage, activities, follow-ups (B1) ────────────────

export async function assignLeadCounselor(
  db: TenantQueryClient,
  organizationId: string,
  schoolId: string,
  leadId: string,
  counselor: string,
): Promise<AdmissionsLeadRow | null> {
  const rows = await db.queryObject<AdmissionsLeadRow>(
    `UPDATE admissions_leads SET
      counselor = $4,
      updated_at = timezone('utc', now())
    WHERE id = $1 AND organization_id = $2 AND school_id = $3
    RETURNING *`,
    [leadId, organizationId, schoolId, counselor],
  );
  return rows[0] ?? null;
}

export async function changeLeadStage(
  db: TenantQueryClient,
  organizationId: string,
  schoolId: string,
  leadId: string,
  stage: string,
): Promise<AdmissionsLeadRow | null> {
  const rows = await db.queryObject<AdmissionsLeadRow>(
    `UPDATE admissions_leads SET
      stage = $4,
      updated_at = timezone('utc', now())
    WHERE id = $1 AND organization_id = $2 AND school_id = $3
    RETURNING *`,
    [leadId, organizationId, schoolId, stage],
  );
  return rows[0] ?? null;
}

export interface AddLeadActivityInput {
  activityType: string;
  title: string;
  description: string;
  actor: string;
}

export async function addLeadActivity(
  db: TenantQueryClient,
  organizationId: string,
  schoolId: string,
  leadId: string,
  input: AddLeadActivityInput,
): Promise<AdmissionsLeadActivityRow> {
  const rows = await db.queryObject<AdmissionsLeadActivityRow>(
    `INSERT INTO admissions_lead_activities (
      organization_id, school_id, lead_id, activity_type, title, description, actor
    ) VALUES ($1, $2, $3, $4, $5, $6, $7)
    RETURNING *`,
    [
      organizationId,
      schoolId,
      leadId,
      input.activityType,
      input.title,
      input.description,
      input.actor,
    ],
  );
  return rows[0]!;
}

export async function listLeadActivities(
  db: TenantQueryClient,
  organizationId: string,
  schoolId: string,
  leadId: string,
): Promise<AdmissionsLeadActivityRow[]> {
  return await db.queryObject<AdmissionsLeadActivityRow>(
    `SELECT * FROM admissions_lead_activities
     WHERE lead_id = $1 AND organization_id = $2 AND school_id = $3
     ORDER BY created_at DESC`,
    [leadId, organizationId, schoolId],
  );
}

export interface AddFollowUpInput {
  task: string;
  scheduledLabel: string;
  outcome: string;
  counselor: string;
}

export async function addLeadFollowUp(
  db: TenantQueryClient,
  organizationId: string,
  schoolId: string,
  leadId: string,
  input: AddFollowUpInput,
): Promise<AdmissionsLeadFollowUpRow> {
  const rows = await db.queryObject<AdmissionsLeadFollowUpRow>(
    `INSERT INTO admissions_lead_follow_ups (
      organization_id, school_id, lead_id, task, scheduled_label, counselor, outcome
    ) VALUES ($1, $2, $3, $4, $5, $6, $7)
    RETURNING *`,
    [
      organizationId,
      schoolId,
      leadId,
      input.task,
      input.scheduledLabel,
      input.counselor,
      input.outcome || "Scheduled",
    ],
  );
  // Keep the lead list view's scalar next-follow-up label in sync.
  if (input.scheduledLabel) {
    await db.queryObject(
      `UPDATE admissions_leads SET
        next_follow_up_label = $4,
        updated_at = timezone('utc', now())
      WHERE id = $1 AND organization_id = $2 AND school_id = $3`,
      [leadId, organizationId, schoolId, input.scheduledLabel],
    );
  }
  return rows[0]!;
}

export async function listLeadFollowUps(
  db: TenantQueryClient,
  organizationId: string,
  schoolId: string,
  leadId: string,
): Promise<AdmissionsLeadFollowUpRow[]> {
  return await db.queryObject<AdmissionsLeadFollowUpRow>(
    `SELECT * FROM admissions_lead_follow_ups
     WHERE lead_id = $1 AND organization_id = $2 AND school_id = $3
     ORDER BY created_at DESC`,
    [leadId, organizationId, schoolId],
  );
}

// ─── Applications ────────────────────────────────────────────────────────────

export async function listApplications(
  db: TenantQueryClient,
  organizationId: string,
  schoolId: string,
  pagination: PaginationParams,
): Promise<PaginationResult<AdmissionsApplicationRow>> {
  const limit = Math.min(Math.max(pagination.pageSize, 1), 100);
  const offset = offsetFor(pagination.page, limit);

  const total = await db.queryCount(
    `SELECT count(*)::text AS count FROM admissions_applications
     WHERE organization_id = $1 AND school_id = $2`,
    [organizationId, schoolId],
  );

  const items = await db.queryObject<AdmissionsApplicationRow>(
    `SELECT a.*,
      (SELECT count(*)::int FROM admissions_documents d
       WHERE d.application_id = a.id AND d.status = 'verified') AS documents_complete,
      (SELECT count(*)::int FROM admissions_documents d
       WHERE d.application_id = a.id) AS documents_total
     FROM admissions_applications a
     WHERE a.organization_id = $1 AND a.school_id = $2
     ORDER BY a.created_at DESC
     LIMIT $3 OFFSET $4`,
    [organizationId, schoolId, limit, offset],
  );

  return {
    items,
    total,
    page: pagination.page,
    pageSize: limit,
    hasMore: offset + items.length < total,
  };
}

export async function getApplicationById(
  db: TenantQueryClient,
  organizationId: string,
  schoolId: string,
  applicationId: string,
): Promise<AdmissionsApplicationRow | null> {
  const rows = await db.queryObject<AdmissionsApplicationRow>(
    `SELECT a.*,
      (SELECT count(*)::int FROM admissions_documents d
       WHERE d.application_id = a.id AND d.status = 'verified') AS documents_complete,
      (SELECT count(*)::int FROM admissions_documents d
       WHERE d.application_id = a.id) AS documents_total
     FROM admissions_applications a
     WHERE a.id = $1 AND a.organization_id = $2 AND a.school_id = $3`,
    [applicationId, organizationId, schoolId],
  );
  return rows[0] ?? null;
}

export interface CreateApplicationInput {
  studentName: string;
  classLabel: string;
  parentName: string;
  leadId: string | null;
  counselor: string;
}

export async function createApplication(
  db: TenantQueryClient,
  organizationId: string,
  schoolId: string,
  input: CreateApplicationInput,
): Promise<AdmissionsApplicationRow> {
  const rows = await db.queryObject<AdmissionsApplicationRow>(
    `INSERT INTO admissions_applications (
      organization_id, school_id, lead_id, student_name, class_label,
      parent_name, counselor, status
    ) VALUES ($1, $2, $3, $4, $5, $6, $7, 'draft')
    RETURNING *`,
    [
      organizationId,
      schoolId,
      input.leadId,
      input.studentName,
      input.classLabel,
      input.parentName,
      input.counselor,
    ],
  );
  return rows[0]!;
}

export interface UpdateApplicationInput {
  studentName?: string;
  classLabel?: string;
  parentName?: string;
  counselor?: string;
  status?: string;
}

export async function updateApplication(
  db: TenantQueryClient,
  organizationId: string,
  schoolId: string,
  applicationId: string,
  input: UpdateApplicationInput,
): Promise<AdmissionsApplicationRow | null> {
  const existing = await getApplicationById(
    db,
    organizationId,
    schoolId,
    applicationId,
  );
  if (!existing) return null;

  const rows = await db.queryObject<AdmissionsApplicationRow>(
    `UPDATE admissions_applications SET
      student_name = $4,
      class_label = $5,
      parent_name = $6,
      counselor = $7,
      status = $8,
      updated_at = timezone('utc', now())
    WHERE id = $1 AND organization_id = $2 AND school_id = $3
    RETURNING *`,
    [
      applicationId,
      organizationId,
      schoolId,
      input.studentName ?? existing.student_name,
      input.classLabel ?? existing.class_label,
      input.parentName ?? existing.parent_name,
      input.counselor ?? existing.counselor,
      input.status ?? existing.status,
    ],
  );
  return rows[0] ?? null;
}

export async function submitApplication(
  db: TenantQueryClient,
  organizationId: string,
  schoolId: string,
  applicationId: string,
): Promise<AdmissionsApplicationRow | null> {
  const rows = await db.queryObject<AdmissionsApplicationRow>(
    `UPDATE admissions_applications SET
      status = 'submitted',
      submitted_at = timezone('utc', now()),
      updated_at = timezone('utc', now())
    WHERE id = $1 AND organization_id = $2 AND school_id = $3
      AND status = 'draft'
    RETURNING *`,
    [applicationId, organizationId, schoolId],
  );
  return rows[0] ?? null;
}

// ─── Documents ─────────────────────────────────────────────────────────────────

export async function listDocuments(
  db: TenantQueryClient,
  organizationId: string,
  schoolId: string,
  pagination: PaginationParams,
): Promise<PaginationResult<AdmissionsDocumentRow>> {
  const limit = Math.min(Math.max(pagination.pageSize, 1), 100);
  const offset = offsetFor(pagination.page, limit);

  const total = await db.queryCount(
    `SELECT count(*)::text AS count FROM admissions_documents
     WHERE organization_id = $1 AND school_id = $2`,
    [organizationId, schoolId],
  );

  const items = await db.queryObject<AdmissionsDocumentRow>(
    `SELECT * FROM admissions_documents
     WHERE organization_id = $1 AND school_id = $2
     ORDER BY created_at DESC
     LIMIT $3 OFFSET $4`,
    [organizationId, schoolId, limit, offset],
  );

  return {
    items,
    total,
    page: pagination.page,
    pageSize: limit,
    hasMore: offset + items.length < total,
  };
}

export async function getDocumentById(
  db: TenantQueryClient,
  organizationId: string,
  schoolId: string,
  documentId: string,
): Promise<AdmissionsDocumentRow | null> {
  const rows = await db.queryObject<AdmissionsDocumentRow>(
    `SELECT * FROM admissions_documents
     WHERE id = $1 AND organization_id = $2 AND school_id = $3`,
    [documentId, organizationId, schoolId],
  );
  return rows[0] ?? null;
}

export interface UploadDocumentInput {
  leadId: string;
  documentType: string;
  fileName: string;
  studentName: string;
  classLabel: string;
}

export async function uploadDocument(
  db: TenantQueryClient,
  organizationId: string,
  schoolId: string,
  input: UploadDocumentInput,
): Promise<AdmissionsDocumentRow> {
  const lead = await getLeadById(db, organizationId, schoolId, input.leadId);
  const studentName = input.studentName || lead?.student_name || "";
  const classLabel = input.classLabel || lead?.class_label || "";

  const appRows = await db.queryObject<{ id: string }>(
    `SELECT id FROM admissions_applications
     WHERE lead_id = $1 AND organization_id = $2 AND school_id = $3
     ORDER BY created_at DESC LIMIT 1`,
    [input.leadId, organizationId, schoolId],
  );
  const applicationId = appRows[0]?.id ?? null;

  const rows = await db.queryObject<AdmissionsDocumentRow>(
    `INSERT INTO admissions_documents (
      organization_id, school_id, lead_id, application_id, student_name, class_label,
      document_type, file_name, is_required, status, uploaded_at
    ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, true, 'uploaded', timezone('utc', now()))
    RETURNING *`,
    [
      organizationId,
      schoolId,
      input.leadId,
      applicationId,
      studentName,
      classLabel,
      input.documentType,
      input.fileName,
    ],
  );
  return rows[0]!;
}

export async function reviewDocument(
  db: TenantQueryClient,
  organizationId: string,
  schoolId: string,
  documentId: string,
  status: "verified" | "rejected",
  verifiedBy: string,
  note: string,
): Promise<AdmissionsDocumentRow | null> {
  const rows = await db.queryObject<AdmissionsDocumentRow>(
    `UPDATE admissions_documents SET
      status = $4,
      verified_by = $5,
      reviewer_note = $6,
      updated_at = timezone('utc', now())
    WHERE id = $1 AND organization_id = $2 AND school_id = $3
    RETURNING *`,
    [documentId, organizationId, schoolId, status, verifiedBy, note || null],
  );
  return rows[0] ?? null;
}

// ─── Approval ────────────────────────────────────────────────────────────────

export async function getApprovalById(
  db: TenantQueryClient,
  organizationId: string,
  schoolId: string,
  approvalId: string,
): Promise<AdmissionsApprovalRow | null> {
  const rows = await db.queryObject<AdmissionsApprovalRow>(
    `SELECT ap.*,
      (SELECT count(*)::int FROM admissions_documents d
       WHERE d.application_id = ap.application_id AND d.status = 'verified') AS documents_complete,
      (SELECT count(*)::int FROM admissions_documents d
       WHERE d.application_id = ap.application_id) AS documents_total
     FROM admissions_approvals ap
     WHERE ap.id = $1 AND ap.organization_id = $2 AND ap.school_id = $3`,
    [approvalId, organizationId, schoolId],
  );
  return rows[0] ?? null;
}

export async function ensureApprovalForApplication(
  db: TenantQueryClient,
  organizationId: string,
  schoolId: string,
  applicationId: string,
): Promise<AdmissionsApprovalRow> {
  const existing = await db.queryObject<AdmissionsApprovalRow>(
    `SELECT * FROM admissions_approvals
     WHERE application_id = $1 AND organization_id = $2 AND school_id = $3`,
    [applicationId, organizationId, schoolId],
  );
  if (existing[0]) return existing[0];

  const app = await getApplicationById(
    db,
    organizationId,
    schoolId,
    applicationId,
  );
  if (!app) throw new Error("Application not found");

  const rows = await db.queryObject<AdmissionsApprovalRow>(
    `INSERT INTO admissions_approvals (
      organization_id, school_id, application_id, student_name, class_label,
      parent_name, counselor, decision, ai_score, submitted_at
    ) VALUES ($1, $2, $3, $4, $5, $6, $7, 'pending', 75, $8)
    RETURNING *`,
    [
      organizationId,
      schoolId,
      applicationId,
      app.student_name,
      app.class_label,
      app.parent_name,
      app.counselor,
      app.submitted_at,
    ],
  );
  return rows[0]!;
}

export async function setApprovalDecision(
  db: TenantQueryClient,
  organizationId: string,
  schoolId: string,
  approvalId: string,
  decision: "approved" | "rejected",
): Promise<AdmissionsApprovalRow | null> {
  const rows = await db.queryObject<AdmissionsApprovalRow>(
    `UPDATE admissions_approvals SET
      decision = $4,
      updated_at = timezone('utc', now())
    WHERE id = $1 AND organization_id = $2 AND school_id = $3
    RETURNING *`,
    [approvalId, organizationId, schoolId, decision],
  );
  const approval = rows[0];
  if (!approval) return null;

  if (decision === "approved") {
    await db.queryObject(
      `UPDATE admissions_applications SET status = 'approved', updated_at = timezone('utc', now())
       WHERE id = $1 AND organization_id = $2 AND school_id = $3`,
      [approval.application_id, organizationId, schoolId],
    );
  } else {
    await db.queryObject(
      `UPDATE admissions_applications SET status = 'rejected', updated_at = timezone('utc', now())
       WHERE id = $1 AND organization_id = $2 AND school_id = $3`,
      [approval.application_id, organizationId, schoolId],
    );
  }

  return await getApprovalById(db, organizationId, schoolId, approvalId);
}

// ─── Enrollment ────────────────────────────────────────────────────────────────

export interface EnrollmentSubmitInput {
  applicationId: string | null;
  studentFullName: string;
  dateOfBirth: string;
  gender: string;
  aadhaar: string;
  guardianName: string;
  relationship: string;
  phone: string;
  email: string;
  address: string;
  seekingClass: string;
  section: string;
  academicYear: string;
  academicYearId?: string | null;
  classId?: string | null;
  sectionId?: string | null;
  previousSchool: string;
  needsTransport: boolean;
  needsHostel: boolean;
}

export async function submitEnrollment(
  db: TenantQueryClient,
  organizationId: string,
  schoolId: string,
  input: EnrollmentSubmitInput,
): Promise<AdmissionsEnrollmentRow> {
  const guardianRows = await db.queryObject<{ guardian_user_id: string | null }>(
    `SELECT app.lookup_guardian_user_for_enrollment($1) AS guardian_user_id`,
    [normalizePhone(input.phone)],
  );
  const guardianUserId = guardianRows[0]?.guardian_user_id ?? null;

  const admissionNumber = `ADM-${new Date().getFullYear()}-${crypto.randomUUID().slice(0, 8).toUpperCase()}`;
  const studentCode = `STU-${crypto.randomUUID().slice(0, 8).toUpperCase()}`;

  const studentRows = await db.queryObject<{ id: string }>(
    `INSERT INTO students (
      organization_id, school_id, student_code, display_name, status
    ) VALUES ($1, $2, $3, $4, 'active')
    RETURNING id`,
    [organizationId, schoolId, studentCode, input.studentFullName],
  );
  const studentId = studentRows[0]!.id;

  if (guardianUserId) {
    await db.queryObject(
      `INSERT INTO student_guardians (
        organization_id, school_id, student_id, guardian_user_id,
        relationship, is_primary, status
      ) VALUES ($1, $2, $3, $4, $5, true, 'active')
      ON CONFLICT (student_id, guardian_user_id) DO NOTHING`,
      [
        organizationId,
        schoolId,
        studentId,
        guardianUserId,
        input.relationship || "guardian",
      ],
    );
  }

  const placement = await resolveAcademicPlacement(
    { db, organizationId, schoolId },
    {
      academicYear: input.academicYear,
      academicYearId: input.academicYearId,
      className: input.seekingClass,
      classId: input.classId,
      sectionName: input.section,
      sectionId: input.sectionId,
    },
    { mode: "admissions" },
  );

  const enrollRows = await db.queryObject<AdmissionsEnrollmentRow>(
    `INSERT INTO admissions_enrollments (
      organization_id, school_id, application_id, student_id, guardian_user_id,
      student_name, seeking_class, section, academic_year,
      academic_year_id, class_id, section_id,
      guardian_name, phone, gender, date_of_birth,
      conversion_status, admission_number, submitted_at
    ) VALUES (
      $1, $2, $3, $4, $5,
      $6, $7, $8, $9, $10, $11, $12,
      $13, $14, $15, $16,
      'pending', $17, timezone('utc', now())
    )
    RETURNING *`,
    [
      organizationId,
      schoolId,
      input.applicationId,
      studentId,
      guardianUserId,
      input.studentFullName,
      placement.className,
      placement.sectionName ?? "",
      placement.academicYear,
      placement.academicYearId,
      placement.classId,
      placement.sectionId,
      input.guardianName,
      input.phone,
      input.gender,
      input.dateOfBirth,
      admissionNumber,
    ],
  );

  if (input.applicationId) {
    await db.queryObject(
      `UPDATE admissions_applications SET status = 'approved', updated_at = timezone('utc', now())
       WHERE id = $1 AND organization_id = $2 AND school_id = $3`,
      [input.applicationId, organizationId, schoolId],
    );
  }

  const enrollment = enrollRows[0]!;

  await createHandoffFromEnrollment(db, organizationId, schoolId, {
    studentId,
    applicationId: input.applicationId,
    enrollmentId: enrollment.id,
    academicYear: placement.academicYear,
    studentName: input.studentFullName,
    classLabel: placement.className,
    admissionNumber,
    needsTransport: input.needsTransport,
    needsHostel: input.needsHostel,
  });

  return enrollment;
}
