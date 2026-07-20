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

/**
 * Separation of duties on admissions approval: the person who SUBMITTED an
 * application (the maker) may not also APPROVE it (the checker), because approval
 * creates a fee handoff (a payable). Mirrors the FIN-D4 / generic-approval SoD
 * guard (ApprovalSelfApproveDeniedError). Mapped to SELF_APPROVE_DENIED / 409.
 */
export class AdmissionsSelfApproveDeniedError extends Error {
  constructor(public readonly approvalId: string) {
    super(
      `Application submitter cannot approve their own admission: ${approvalId}`,
    );
    this.name = "AdmissionsSelfApproveDeniedError";
  }
}

/**
 * PRA-P0-13: thrown when an enrollment submit names an application that has not
 * cleared the approval workflow (status ≠ 'approved'). Blocks minting a real
 * active student from a draft/submitted/under_review application — the entrance/
 * interview/merit control the module exists to enforce.
 */
export class EnrollmentNotApprovedError extends Error {
  constructor(public readonly applicationId: string, public readonly status: string) {
    super(`Application ${applicationId} is not approved (status: ${status})`);
    this.name = "EnrollmentNotApprovedError";
  }
}

/** PRA-P0-13: thrown when the named application does not exist in this tenant. */
export class EnrollmentApplicationNotFoundError extends Error {
  constructor(public readonly applicationId: string) {
    super(`Admissions application not found: ${applicationId}`);
    this.name = "EnrollmentApplicationNotFoundError";
  }
}

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

// ─── ADM-D1: mark lead lost + reason (fixed picklist) ────────────────────────

/** Allowed lost reasons (Appendix default: small fixed picklist). */
export const LEAD_LOST_REASONS = [
  "fees_high",
  "competitor",
  "distance",
  "other",
] as const;
export type LeadLostReason = (typeof LEAD_LOST_REASONS)[number];

export function isValidLostReason(value: string): value is LeadLostReason {
  return (LEAD_LOST_REASONS as readonly string[]).includes(value);
}

/**
 * Move a lead to stage='lost' and record the reason. The reason is validated
 * against LEAD_LOST_REASONS at the handler layer; this write trusts a
 * pre-validated value.
 */
export async function markLeadLost(
  db: TenantQueryClient,
  organizationId: string,
  schoolId: string,
  leadId: string,
  reason: LeadLostReason,
): Promise<AdmissionsLeadRow | null> {
  const rows = await db.queryObject<AdmissionsLeadRow>(
    `UPDATE admissions_leads SET
      stage = 'lost',
      lost_reason = $4,
      updated_at = timezone('utc', now())
    WHERE id = $1 AND organization_id = $2 AND school_id = $3
    RETURNING *`,
    [leadId, organizationId, schoolId, reason],
  );
  return rows[0] ?? null;
}

// ─── ADM-D2: duplicate-lead lookup by phone (warn-only) ──────────────────────

export interface DuplicateLeadMatch {
  leadId: string;
  studentName: string;
  parentName: string;
  stage: string;
}

/**
 * Return any existing leads that share a phone number so the client can warn
 * the operator and offer "open existing". Warn-only — createLead is unchanged
 * and never hard-blocks on a duplicate.
 */
export async function findLeadsByPhone(
  db: TenantQueryClient,
  organizationId: string,
  schoolId: string,
  phone: string,
): Promise<DuplicateLeadMatch[]> {
  const rows = await db.queryObject<{
    id: string;
    student_name: string;
    parent_name: string;
    stage: string;
  }>(
    `SELECT id, student_name, parent_name, stage
     FROM admissions_leads
     WHERE organization_id = $1 AND school_id = $2 AND phone = $3
     ORDER BY created_at DESC
     LIMIT 20`,
    [organizationId, schoolId, phone],
  );
  return rows.map((row) => ({
    leadId: row.id,
    studentName: row.student_name,
    parentName: row.parent_name,
    stage: row.stage,
  }));
}

// ─── ADM-3: bulk lead actions ────────────────────────────────────────────────

export interface BulkLeadOutcome {
  updated: string[];
  skipped: Array<{ leadId: string; reason: string }>;
}

/**
 * Assign a counselor to many leads in one call. Loops the existing per-lead
 * assign logic; a lead that does not resolve (wrong school / missing) is
 * skipped with a reason rather than failing the whole batch. Per-lead audit +
 * activity are emitted by the caller via the returned updated ids.
 */
export async function bulkAssignLeads(
  db: TenantQueryClient,
  organizationId: string,
  schoolId: string,
  leadIds: string[],
  counselor: string,
): Promise<{ outcome: BulkLeadOutcome; rows: AdmissionsLeadRow[] }> {
  const outcome: BulkLeadOutcome = { updated: [], skipped: [] };
  const rows: AdmissionsLeadRow[] = [];
  for (const leadId of leadIds) {
    const updated = await assignLeadCounselor(
      db,
      organizationId,
      schoolId,
      leadId,
      counselor,
    );
    if (!updated) {
      outcome.skipped.push({ leadId, reason: "not_found" });
      continue;
    }
    outcome.updated.push(leadId);
    rows.push(updated);
  }
  return { outcome, rows };
}

/**
 * Change the pipeline stage of many leads in one call. Same partial-success
 * contract as bulkAssignLeads.
 */
export async function bulkChangeLeadStage(
  db: TenantQueryClient,
  organizationId: string,
  schoolId: string,
  leadIds: string[],
  stage: string,
): Promise<{ outcome: BulkLeadOutcome; rows: AdmissionsLeadRow[] }> {
  const outcome: BulkLeadOutcome = { updated: [], skipped: [] };
  const rows: AdmissionsLeadRow[] = [];
  for (const leadId of leadIds) {
    const updated = await changeLeadStage(
      db,
      organizationId,
      schoolId,
      leadId,
      stage,
    );
    if (!updated) {
      outcome.skipped.push({ leadId, reason: "not_found" });
      continue;
    }
    outcome.updated.push(leadId);
    rows.push(updated);
  }
  return { outcome, rows };
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

// ─── ADM-4: follow-up complete / reschedule ──────────────────────────────────
// The status/completed_label columns exist but were never written. These give
// the follow-up its lifecycle: pending → completed (with an outcome label) or a
// reschedule to a new due label. Both are scoped by org + school.

/**
 * Mark a follow-up completed. Optionally records the completed_label /
 * outcome. Returns null when the follow-up id is not visible to this tenant.
 */
export async function completeFollowUp(
  db: TenantQueryClient,
  organizationId: string,
  schoolId: string,
  followupId: string,
  outcome: string,
): Promise<AdmissionsLeadFollowUpRow | null> {
  const completedLabel = formatCompletedLabel();
  const rows = await db.queryObject<AdmissionsLeadFollowUpRow>(
    `UPDATE admissions_lead_follow_ups SET
      status = 'completed',
      completed_label = $4,
      outcome = COALESCE(NULLIF($5, ''), outcome),
      updated_at = timezone('utc', now())
    WHERE id = $1 AND organization_id = $2 AND school_id = $3
    RETURNING *`,
    [followupId, organizationId, schoolId, completedLabel, outcome],
  );
  return rows[0] ?? null;
}

/**
 * Reschedule a follow-up to a new due label. Resets status to 'pending' (a
 * reschedule reopens the task) and keeps the lead's scalar next-follow-up label
 * in sync so the pipeline view stays honest.
 */
export async function rescheduleFollowUp(
  db: TenantQueryClient,
  organizationId: string,
  schoolId: string,
  followupId: string,
  newLabel: string,
): Promise<AdmissionsLeadFollowUpRow | null> {
  const rows = await db.queryObject<AdmissionsLeadFollowUpRow>(
    `UPDATE admissions_lead_follow_ups SET
      scheduled_label = $4,
      status = 'pending',
      updated_at = timezone('utc', now())
    WHERE id = $1 AND organization_id = $2 AND school_id = $3
    RETURNING *`,
    [followupId, organizationId, schoolId, newLabel],
  );
  const updated = rows[0] ?? null;
  if (updated) {
    await db.queryObject(
      `UPDATE admissions_leads SET
        next_follow_up_label = $4,
        updated_at = timezone('utc', now())
      WHERE id = $1 AND organization_id = $2 AND school_id = $3`,
      [updated.lead_id, organizationId, schoolId, newLabel],
    );
  }
  return updated;
}

function formatCompletedLabel(): string {
  // ISO date (YYYY-MM-DD) keeps the label deterministic and locale-free; the
  // client formats it for display alongside the other admissions date labels.
  return new Date().toISOString().slice(0, 10);
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
  submittedBy: string,
): Promise<AdmissionsApplicationRow | null> {
  // submitted_by = the "maker" for the approval SoD guard: whoever moved the
  // draft → submitted cannot later approve their own application (setApprovalDecision).
  const rows = await db.queryObject<AdmissionsApplicationRow>(
    `UPDATE admissions_applications SET
      status = 'submitted',
      submitted_at = timezone('utc', now()),
      submitted_by = $4,
      updated_at = timezone('utc', now())
    WHERE id = $1 AND organization_id = $2 AND school_id = $3
      AND status = 'draft'
    RETURNING *`,
    [applicationId, organizationId, schoolId, submittedBy],
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
  /** Storage object path of the uploaded file (tenant-prefixed). */
  storagePath: string;
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
      document_type, file_name, storage_path, is_required, status, uploaded_at
    ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, true, 'uploaded', timezone('utc', now()))
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
      input.storagePath,
    ],
  );
  return rows[0]!;
}

export async function getDocumentStoragePath(
  db: TenantQueryClient,
  organizationId: string,
  schoolId: string,
  documentId: string,
): Promise<string | null> {
  const rows = await db.queryObject<{ storage_path: string | null }>(
    `SELECT storage_path FROM admissions_documents
     WHERE id = $1 AND organization_id = $2 AND school_id = $3`,
    [documentId, organizationId, schoolId],
  );
  return rows[0]?.storage_path ?? null;
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
  checkerId: string,
): Promise<AdmissionsApprovalRow | null> {
  // Load the approval → application FIRST to resolve the "maker" (submitter) and
  // enforce separation of duties BEFORE any decision write — so the approve path
  // (which flips the application to 'approved' and unblocks the fee handoff /
  // payable) never runs when the submitter is approving their own application.
  const existing = await getApprovalById(db, organizationId, schoolId, approvalId);
  if (!existing) return null;

  if (decision === "approved") {
    const makerRows = await db.queryObject<{ submitted_by: string | null }>(
      `SELECT submitted_by FROM admissions_applications
       WHERE id = $1 AND organization_id = $2 AND school_id = $3`,
      [existing.application_id, organizationId, schoolId],
    );
    const maker = makerRows[0]?.submitted_by ?? null;
    // Fire only when the maker is recorded (rows submitted before the SoD
    // migration have submitted_by = NULL), matching the FIN-D4 / inventory guard
    // shape (maker_id && maker === checker).
    if (maker && maker === checkerId) {
      throw new AdmissionsSelfApproveDeniedError(approvalId);
    }
  }

  // RT round-3 S4: guard the decision on the pending pre-state so a decided
  // approval can never be re-decided or flipped (approved↔rejected) — the makerRows
  // read above is unlocked, and without this predicate a second checker (or a late
  // flip after enrollment) would silently overwrite the decision. A non-pending row
  // now matches 0 rows → the caller treats it as not-actionable (no application
  // status change, since the block below only runs on a returned row).
  const rows = await db.queryObject<AdmissionsApprovalRow>(
    `UPDATE admissions_approvals SET
      decision = $4,
      decided_by = $5,
      decided_at = timezone('utc', now()),
      updated_at = timezone('utc', now())
    WHERE id = $1 AND organization_id = $2 AND school_id = $3
      AND decision = 'pending'
    RETURNING *`,
    [approvalId, organizationId, schoolId, decision, checkerId],
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

/**
 * Real approval queue: approvals still awaiting a principal decision
 * (decision = 'pending'). Document counts come from the approval row's
 * subquery, mirroring getApprovalById.
 */
export async function listPendingApprovals(
  db: TenantQueryClient,
  organizationId: string,
  schoolId: string,
  pagination: PaginationParams,
): Promise<PaginationResult<AdmissionsApprovalRow>> {
  const limit = Math.min(Math.max(pagination.pageSize, 1), 100);
  const offset = offsetFor(pagination.page, limit);

  const total = await db.queryCount(
    `SELECT count(*)::text AS count FROM admissions_approvals
     WHERE organization_id = $1 AND school_id = $2 AND decision = 'pending'`,
    [organizationId, schoolId],
  );

  const items = await db.queryObject<AdmissionsApprovalRow>(
    `SELECT ap.*,
      (SELECT count(*)::int FROM admissions_documents d
       WHERE d.application_id = ap.application_id AND d.status = 'verified') AS documents_complete,
      (SELECT count(*)::int FROM admissions_documents d
       WHERE d.application_id = ap.application_id) AS documents_total
     FROM admissions_approvals ap
     WHERE ap.organization_id = $1 AND ap.school_id = $2 AND ap.decision = 'pending'
     ORDER BY ap.submitted_at DESC NULLS LAST, ap.created_at DESC
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

// ─── Enrollment ────────────────────────────────────────────────────────────────

/**
 * Real pending enrollments: approved students handed off but not yet converted
 * into an active SIS record (conversion_status = 'pending').
 */
export async function listPendingEnrollments(
  db: TenantQueryClient,
  organizationId: string,
  schoolId: string,
  pagination: PaginationParams,
): Promise<PaginationResult<AdmissionsEnrollmentRow>> {
  const limit = Math.min(Math.max(pagination.pageSize, 1), 100);
  const offset = offsetFor(pagination.page, limit);

  const total = await db.queryCount(
    `SELECT count(*)::text AS count FROM admissions_enrollments
     WHERE organization_id = $1 AND school_id = $2 AND conversion_status = 'pending'`,
    [organizationId, schoolId],
  );

  const items = await db.queryObject<AdmissionsEnrollmentRow>(
    `SELECT * FROM admissions_enrollments
     WHERE organization_id = $1 AND school_id = $2 AND conversion_status = 'pending'
     ORDER BY submitted_at DESC
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

/**
 * Prefill source for the enrollment form: the most recently approved
 * application (status = 'approved') for this school, optionally pinned to a
 * specific application id. Returns null when there is nothing approved yet so
 * the handler can return an honest empty/default prefill.
 */
export async function getEnrollmentPrefillApplication(
  db: TenantQueryClient,
  organizationId: string,
  schoolId: string,
  applicationId: string | null,
): Promise<AdmissionsApplicationRow | null> {
  if (applicationId) {
    const pinned = await getApplicationById(
      db,
      organizationId,
      schoolId,
      applicationId,
    );
    if (pinned && pinned.status === "approved") return pinned;
    if (pinned) return pinned;
  }

  const rows = await db.queryObject<AdmissionsApplicationRow>(
    `SELECT * FROM admissions_applications
     WHERE organization_id = $1 AND school_id = $2 AND status = 'approved'
     ORDER BY updated_at DESC
     LIMIT 1`,
    [organizationId, schoolId],
  );
  return rows[0] ?? null;
}

// ─── ADM-D4: offer-letter data (read) ────────────────────────────────────────

export interface OfferLetterData {
  enrollmentId: string;
  studentName: string;
  admissionNumber: string | null;
  className: string;
  section: string;
  academicYear: string;
  guardianName: string;
  reportingDateLabel: string;
  recommendedFeePlanId: string | null;
  handoffStatus: string | null;
}

/**
 * Standard offer-letter template data for an enrollment. This is a READ — the
 * PDF render is client-side. Money math stays in finance: we surface only the
 * recommended fee plan reference from the handoff, not a computed amount.
 * Returns null when the enrollment id is not visible to this tenant.
 */
export async function getOfferLetterData(
  db: TenantQueryClient,
  organizationId: string,
  schoolId: string,
  enrollmentId: string,
): Promise<OfferLetterData | null> {
  const rows = await db.queryObject<
    AdmissionsEnrollmentRow & {
      recommended_fee_plan_id: string | null;
      handoff_status: string | null;
    }
  >(
    `SELECT e.*,
            h.recommended_fee_plan_id AS recommended_fee_plan_id,
            h.handoff_status AS handoff_status
     FROM admissions_enrollments e
     LEFT JOIN admissions_fee_handoffs h ON h.enrollment_id = e.id
     WHERE e.id = $1 AND e.organization_id = $2 AND e.school_id = $3
     LIMIT 1`,
    [enrollmentId, organizationId, schoolId],
  );
  const row = rows[0];
  if (!row) return null;

  return {
    enrollmentId: row.id,
    studentName: row.student_name,
    admissionNumber: row.admission_number,
    className: row.seeking_class,
    section: row.section,
    academicYear: row.academic_year,
    guardianName: row.guardian_name,
    // Standard-template reporting date: the enrollment submission date. The
    // client formats it; we pass the ISO date so it stays locale-free.
    reportingDateLabel: String(row.submitted_at).slice(0, 10),
    recommendedFeePlanId: row.recommended_fee_plan_id,
    handoffStatus: row.handoff_status,
  };
}

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

// Postgres unique_violation SQLSTATE — the admissions_enrollments_application_uniq
// partial index raises this on a racing double-submit for the same application.
const PG_UNIQUE_VIOLATION = "23505";

function isUniqueViolation(error: unknown): boolean {
  if (typeof error !== "object" || error === null) return false;
  const code = (error as { code?: unknown; fields?: { code?: unknown } }).code ??
    (error as { fields?: { code?: unknown } }).fields?.code;
  return code === PG_UNIQUE_VIOLATION;
}

/**
 * Return the already-committed enrollment for an application, if any. Used both
 * for the idempotency guard (before creating a new student) and to recover the
 * winning row after a racing INSERT hits the unique index.
 */
export async function getEnrollmentByApplicationId(
  db: TenantQueryClient,
  organizationId: string,
  schoolId: string,
  applicationId: string,
): Promise<AdmissionsEnrollmentRow | null> {
  const rows = await db.queryObject<AdmissionsEnrollmentRow>(
    `SELECT * FROM admissions_enrollments
     WHERE application_id = $1 AND organization_id = $2 AND school_id = $3
     LIMIT 1`,
    [applicationId, organizationId, schoolId],
  );
  return rows[0] ?? null;
}

/**
 * P0 money fix — enrollment idempotency.
 *
 * A double-click / retry on an approved application must NOT mint a second
 * students row + admission number + fee handoff (duplicate payables). This is
 * enforced in three layers:
 *   1. Lock anchor: when an application_id is present we take a
 *      `SELECT ... FOR UPDATE` on the admissions_applications row so two
 *      concurrent submits for the same application serialize.
 *   2. Guard: after acquiring the lock we re-check for an existing enrollment
 *      and, if found, return it unchanged (no new student/handoff).
 *   3. Backstop: the admissions_enrollments_application_uniq partial unique
 *      index makes a racing INSERT raise 23505, which we map to the same
 *      idempotent return (never a 500).
 *
 * Walk-in enrollments (application_id = null) have no dedup key and are always
 * treated as distinct — matching the partial index `WHERE application_id IS NOT NULL`.
 */
export async function submitEnrollment(
  db: TenantQueryClient,
  organizationId: string,
  schoolId: string,
  input: EnrollmentSubmitInput,
): Promise<AdmissionsEnrollmentRow> {
  // ── Idempotency guard (layers 1 + 2) + PRA-P0-13 approval gate ─────────────
  if (input.applicationId) {
    // Lock anchor: serialize concurrent submits on the same application, and read
    // status under the lock so the approval gate sees a consistent value. The
    // lock is held until this transaction commits/rolls back.
    const appRows = await db.queryObject<{ id: string; status: string }>(
      `SELECT id, status FROM admissions_applications
       WHERE id = $1 AND organization_id = $2 AND school_id = $3
       FOR UPDATE`,
      [input.applicationId, organizationId, schoolId],
    );
    const application = appRows[0];
    if (!application) {
      throw new EnrollmentApplicationNotFoundError(input.applicationId);
    }
    const existing = await getEnrollmentByApplicationId(
      db,
      organizationId,
      schoolId,
      input.applicationId,
    );
    // Idempotency FIRST: an already-converted application returns its enrollment
    // regardless of a later status edit, so a repeat submit is never re-gated.
    if (existing) return existing;
    // PRA-P0-13: only an APPROVED application may be minted into an active
    // student. Previously the status was never read — a counselor with only
    // manageAdmissions could enroll a draft/submitted/under_review application,
    // bypassing the entrance/interview/merit/sign-off control.
    if (application.status !== "approved") {
      throw new EnrollmentNotApprovedError(input.applicationId, application.status);
    }
  }

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

  // Layer 3 backstop: even with the lock anchor, insert under a SAVEPOINT so a
  // racing 23505 on admissions_enrollments_application_uniq is recoverable
  // WITHOUT aborting the whole transaction — we roll back to the savepoint and
  // return the winning enrollment (idempotent), never surfacing a 500. The
  // just-created student row is left orphaned but harmless (no admission number
  // was minted for it, and it is never handed off to finance).
  await db.queryObject(`SAVEPOINT admissions_enroll_insert`);
  let enrollRows: AdmissionsEnrollmentRow[];
  try {
    enrollRows = await db.queryObject<AdmissionsEnrollmentRow>(
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
    await db.queryObject(`RELEASE SAVEPOINT admissions_enroll_insert`);
  } catch (error) {
    if (isUniqueViolation(error) && input.applicationId) {
      await db.queryObject(`ROLLBACK TO SAVEPOINT admissions_enroll_insert`);
      const existing = await getEnrollmentByApplicationId(
        db,
        organizationId,
        schoolId,
        input.applicationId,
      );
      if (existing) return existing;
    }
    throw error;
  }

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
