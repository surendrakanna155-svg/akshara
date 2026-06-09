import type { TenantQueryClient } from "../tenant_db.ts";
import type { PaginationParams, PaginationResult } from "./admissions_repository.ts";

export interface AdmissionsFeeHandoffRow {
  id: string;
  organization_id: string;
  school_id: string;
  student_id: string;
  application_id: string | null;
  enrollment_id: string | null;
  academic_year: string;
  recommended_fee_plan_id: string | null;
  handoff_status: string;
  student_name: string;
  class_label: string;
  admission_number: string;
  needs_transport: boolean;
  needs_hostel: boolean;
  sis_handoff_label: string;
  created_at: string;
  updated_at: string;
}

export interface CreateHandoffInput {
  studentId: string;
  applicationId: string | null;
  enrollmentId: string;
  academicYear: string;
  studentName: string;
  classLabel: string;
  admissionNumber: string;
  needsTransport: boolean;
  needsHostel: boolean;
}

function offsetFor(page: number, pageSize: number): number {
  return Math.max(0, (page - 1) * pageSize);
}

export async function listFeeHandoffs(
  db: TenantQueryClient,
  organizationId: string,
  schoolId: string,
  pagination: PaginationParams,
): Promise<PaginationResult<AdmissionsFeeHandoffRow>> {
  const limit = Math.min(Math.max(pagination.pageSize, 1), 100);
  const offset = offsetFor(pagination.page, limit);

  const total = await db.queryCount(
    `SELECT count(*)::text AS count FROM admissions_fee_handoffs
     WHERE organization_id = $1 AND school_id = $2`,
    [organizationId, schoolId],
  );

  const items = await db.queryObject<AdmissionsFeeHandoffRow>(
    `SELECT * FROM admissions_fee_handoffs
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

export async function getFeeHandoffById(
  db: TenantQueryClient,
  organizationId: string,
  schoolId: string,
  handoffId: string,
): Promise<AdmissionsFeeHandoffRow | null> {
  const rows = await db.queryObject<AdmissionsFeeHandoffRow>(
    `SELECT * FROM admissions_fee_handoffs
     WHERE id = $1 AND organization_id = $2 AND school_id = $3`,
    [handoffId, organizationId, schoolId],
  );
  return rows[0] ?? null;
}

/** Creates a pending handoff when enrollment completes (Phase 4B0). */
export async function createHandoffFromEnrollment(
  db: TenantQueryClient,
  organizationId: string,
  schoolId: string,
  input: CreateHandoffInput,
): Promise<AdmissionsFeeHandoffRow> {
  const rows = await db.queryObject<AdmissionsFeeHandoffRow>(
    `INSERT INTO admissions_fee_handoffs (
      organization_id, school_id, student_id, application_id, enrollment_id,
      academic_year, handoff_status, student_name, class_label, admission_number,
      needs_transport, needs_hostel, sis_handoff_label
    ) VALUES (
      $1, $2, $3, $4, $5,
      $6, 'pending', $7, $8, $9,
      $10, $11, 'Pending finance confirmation'
    )
    RETURNING *`,
    [
      organizationId,
      schoolId,
      input.studentId,
      input.applicationId,
      input.enrollmentId,
      input.academicYear,
      input.studentName,
      input.classLabel,
      input.admissionNumber,
      input.needsTransport,
      input.needsHostel,
    ],
  );
  return rows[0]!;
}

export async function sendHandoffToFinance(
  db: TenantQueryClient,
  organizationId: string,
  schoolId: string,
  handoffId: string,
  feeStructureId: string,
): Promise<AdmissionsFeeHandoffRow | null> {
  const rows = await db.queryObject<AdmissionsFeeHandoffRow>(
    `UPDATE admissions_fee_handoffs SET
      recommended_fee_plan_id = $4,
      handoff_status = 'sent_to_finance',
      sis_handoff_label = 'Sent to Finance',
      updated_at = timezone('utc', now())
    WHERE id = $1 AND organization_id = $2 AND school_id = $3
      AND handoff_status IN ('pending', 'sent_to_finance')
    RETURNING *`,
    [handoffId, organizationId, schoolId, feeStructureId],
  );
  return rows[0] ?? null;
}

const VALID_STATUSES = new Set([
  "pending",
  "sent_to_finance",
  "completed",
  "failed",
]);

export async function updateHandoffStatus(
  db: TenantQueryClient,
  organizationId: string,
  schoolId: string,
  handoffId: string,
  status: string,
): Promise<AdmissionsFeeHandoffRow | null> {
  if (!VALID_STATUSES.has(status)) {
    throw new Error(`Invalid handoff status: ${status}`);
  }

  const sisLabel = status === "completed"
    ? "Active in Student SIS"
    : status === "sent_to_finance"
    ? "Sent to Finance"
    : status === "failed"
    ? "Handoff failed"
    : "Pending finance confirmation";

  const rows = await db.queryObject<AdmissionsFeeHandoffRow>(
    `UPDATE admissions_fee_handoffs SET
      handoff_status = $4,
      sis_handoff_label = $5,
      updated_at = timezone('utc', now())
    WHERE id = $1 AND organization_id = $2 AND school_id = $3
    RETURNING *`,
    [handoffId, organizationId, schoolId, status, sisLabel],
  );
  return rows[0] ?? null;
}
