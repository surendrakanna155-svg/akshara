import { getFeeHandoffById } from "../admissions/admissions_handoffs_repository.ts";
import type { TenantQueryClient } from "../tenant_db.ts";
import { createAnnualInvoice, getInvoiceByAssignmentId } from "./finance_invoices_repository.ts";
import type { FinanceInvoiceRow } from "./finance_invoices_repository.ts";
import type { PaginationParams, PaginationResult } from "./finance_structures_repository.ts";

export interface FinanceFeeAssignmentRow {
  id: string;
  organization_id: string;
  school_id: string;
  student_id: string;
  fee_structure_id: string;
  academic_year: string;
  assignment_status: string;
  assigned_by: string;
  assigned_at: string;
  created_at: string;
  updated_at: string;
}

export interface FinanceStudentAccountRow {
  id: string;
  organization_id: string;
  school_id: string;
  student_id: string;
  fee_assignment_id: string;
  academic_year: string;
  total_fee: string;
  amount_paid: string;
  outstanding_amount: string;
  status: string;
  created_at: string;
  updated_at: string;
}

export interface AssignmentWithAccount {
  assignment: FinanceFeeAssignmentRow;
  account: FinanceStudentAccountRow;
  invoice: FinanceInvoiceRow;
  feeStructureName?: string;
  studentName?: string;
  admissionNumber?: string;
  classLabel?: string;
}

export interface AssignFeeStructureInput {
  studentId: string;
  feeStructureId: string;
  academicYear: string;
  assignedBy: string;
}

export class DuplicateAssignmentError extends Error {
  constructor() {
    super("Fee assignment already exists for student, structure, and academic year");
    this.name = "DuplicateAssignmentError";
  }
}

export class DuplicateStudentAccountError extends Error {
  constructor() {
    super("Student account already exists for academic year");
    this.name = "DuplicateStudentAccountError";
  }
}

export class HandoffNotReadyError extends Error {
  constructor(status: string) {
    super(`Handoff not ready for assignment (status: ${status})`);
    this.name = "HandoffNotReadyError";
  }
}

const ASSIGNABLE_HANDOFF_STATUSES = new Set(["pending", "sent_to_finance"]);

function offsetFor(page: number, pageSize: number): number {
  return Math.max(0, (page - 1) * pageSize);
}

async function sumStructureFees(
  db: TenantQueryClient,
  organizationId: string,
  schoolId: string,
  feeStructureId: string,
): Promise<number> {
  const rows = await db.queryObject<{ total: string }>(
    `SELECT COALESCE(SUM(amount), 0)::text AS total
     FROM finance_fee_structure_items
     WHERE fee_structure_id = $1 AND organization_id = $2 AND school_id = $3`,
    [feeStructureId, organizationId, schoolId],
  );
  return parseFloat(rows[0]?.total ?? "0");
}

async function ensureFeeStructureExists(
  db: TenantQueryClient,
  organizationId: string,
  schoolId: string,
  feeStructureId: string,
): Promise<{ name: string; academic_year: string }> {
  const rows = await db.queryObject<{ name: string; academic_year: string }>(
    `SELECT name, academic_year FROM finance_fee_structures
     WHERE id = $1 AND organization_id = $2 AND school_id = $3 AND status = 'active'`,
    [feeStructureId, organizationId, schoolId],
  );
  const structure = rows[0];
  if (!structure) {
    throw new Error(`Fee structure not found or inactive: ${feeStructureId}`);
  }
  return structure;
}

async function createAssignmentAndAccount(
  db: TenantQueryClient,
  organizationId: string,
  schoolId: string,
  input: AssignFeeStructureInput,
): Promise<AssignmentWithAccount> {
  await ensureFeeStructureExists(db, organizationId, schoolId, input.feeStructureId);

  const duplicate = await db.queryObject<{ id: string }>(
    `SELECT id FROM finance_fee_assignments
     WHERE student_id = $1 AND fee_structure_id = $2 AND academic_year = $3
       AND organization_id = $4 AND school_id = $5`,
    [
      input.studentId,
      input.feeStructureId,
      input.academicYear,
      organizationId,
      schoolId,
    ],
  );
  if (duplicate[0]) {
    throw new DuplicateAssignmentError();
  }

  // TRN-9 (owner decision): a student's per-year finance account is a SHARED
  // container — tuition + transport (and any other structure) coexist as
  // MULTIPLE invoices under ONE finance_student_accounts row. So GET-OR-CREATE
  // the account instead of throwing on a pre-existing one: reuse the existing
  // account when the student already has one for this academic year, and only
  // create a fresh account when this is the student's first structure this year.
  // The per-(student, structure, year) UNIQUE on finance_fee_assignments (guarded
  // above) still makes assigning the SAME structure twice idempotent-by-rejection;
  // this change only unblocks assigning a DIFFERENT structure to a student who
  // already has an account. The account's aggregate money columns (total_fee /
  // amount_paid / outstanding_amount) are NOT re-derived here — each structure
  // raises its own invoice with its own outstanding, which stays authoritative.
  const existingAccount = await db.queryObject<FinanceStudentAccountRow>(
    `SELECT * FROM finance_student_accounts
     WHERE student_id = $1 AND academic_year = $2 AND organization_id = $3 AND school_id = $4`,
    [input.studentId, input.academicYear, organizationId, schoolId],
  );
  const reuseAccount = existingAccount[0] ?? null;

  const totalFee = await sumStructureFees(
    db,
    organizationId,
    schoolId,
    input.feeStructureId,
  );

  const assignmentRows = await db.queryObject<FinanceFeeAssignmentRow>(
    `INSERT INTO finance_fee_assignments (
      organization_id, school_id, student_id, fee_structure_id,
      academic_year, assignment_status, assigned_by
    ) VALUES ($1, $2, $3, $4, $5, 'active', $6)
    RETURNING *`,
    [
      organizationId,
      schoolId,
      input.studentId,
      input.feeStructureId,
      input.academicYear,
      input.assignedBy,
    ],
  );

  const assignment = assignmentRows[0]!;

  // Get-or-create: reuse the student's existing per-year account when present,
  // otherwise open a new one seeded from THIS structure's total.
  const account = reuseAccount ?? (await db.queryObject<FinanceStudentAccountRow>(
    `INSERT INTO finance_student_accounts (
      organization_id, school_id, student_id, fee_assignment_id,
      academic_year, total_fee, amount_paid, outstanding_amount, status
    ) VALUES ($1, $2, $3, $4, $5, $6, 0, $6, 'open')
    RETURNING *`,
    [
      organizationId,
      schoolId,
      input.studentId,
      assignment.id,
      input.academicYear,
      totalFee,
    ],
  ))[0]!;

  const invoice = await createAnnualInvoice(db, organizationId, schoolId, {
    studentId: input.studentId,
    feeAssignmentId: assignment.id,
    academicYear: input.academicYear,
    totalAmount: totalFee,
    createdBy: input.assignedBy,
  });

  // When the per-year account is REUSED (a second/third structure for the same
  // student+year), fold THIS structure's total into the shared account container
  // so its aggregate columns stay authoritative: collections decrement
  // finance_student_accounts.outstanding_amount (finance_collections_repository),
  // and the dashboard + defaulters/recovery read it. Without this the account
  // would under-report the student's true dues by the new structure's amount and
  // a later collection against the new invoice would drive the account balance
  // wrong. A freshly-INSERTED account already carries this structure's total, so
  // only the reuse path needs the bump. amount_paid is untouched (new invoice = 0
  // paid); status re-opens because there is fresh outstanding.
  let effectiveAccount = account;
  if (reuseAccount) {
    const bumped = await db.queryObject<FinanceStudentAccountRow>(
      `UPDATE finance_student_accounts SET
         total_fee = total_fee + $1,
         outstanding_amount = outstanding_amount + $1,
         status = 'open',
         updated_at = timezone('utc', now())
       WHERE id = $2 AND organization_id = $3 AND school_id = $4
       RETURNING *`,
      [totalFee, reuseAccount.id, organizationId, schoolId],
    );
    effectiveAccount = bumped[0] ?? account;
  }

  return await enrichAssignmentWithAccount(
    db,
    organizationId,
    schoolId,
    assignment,
    effectiveAccount,
    invoice,
  );
}

export async function listAssignments(
  db: TenantQueryClient,
  organizationId: string,
  schoolId: string,
  pagination: PaginationParams,
): Promise<PaginationResult<FinanceFeeAssignmentRow>> {
  const limit = Math.min(Math.max(pagination.pageSize, 1), 100);
  const offset = offsetFor(pagination.page, limit);

  const total = await db.queryCount(
    `SELECT count(*)::text AS count FROM finance_fee_assignments
     WHERE organization_id = $1 AND school_id = $2`,
    [organizationId, schoolId],
  );

  const items = await db.queryObject<FinanceFeeAssignmentRow>(
    `SELECT * FROM finance_fee_assignments
     WHERE organization_id = $1 AND school_id = $2
     ORDER BY assigned_at DESC
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

export async function getAssignment(
  db: TenantQueryClient,
  organizationId: string,
  schoolId: string,
  assignmentId: string,
): Promise<FinanceFeeAssignmentRow | null> {
  const rows = await db.queryObject<FinanceFeeAssignmentRow>(
    `SELECT * FROM finance_fee_assignments
     WHERE id = $1 AND organization_id = $2 AND school_id = $3`,
    [assignmentId, organizationId, schoolId],
  );
  return rows[0] ?? null;
}

export async function assignFeeStructure(
  db: TenantQueryClient,
  organizationId: string,
  schoolId: string,
  input: AssignFeeStructureInput,
): Promise<AssignmentWithAccount> {
  return await createAssignmentAndAccount(db, organizationId, schoolId, input);
}

export async function cancelAssignment(
  db: TenantQueryClient,
  organizationId: string,
  schoolId: string,
  assignmentId: string,
): Promise<AssignmentWithAccount | null> {
  const rows = await db.queryObject<FinanceFeeAssignmentRow>(
    `UPDATE finance_fee_assignments SET
      assignment_status = 'cancelled',
      updated_at = timezone('utc', now())
    WHERE id = $1 AND organization_id = $2 AND school_id = $3
      AND assignment_status = 'active'
    RETURNING *`,
    [assignmentId, organizationId, schoolId],
  );
  const assignment = rows[0];
  if (!assignment) return null;

  const accountRows = await db.queryObject<FinanceStudentAccountRow>(
    `UPDATE finance_student_accounts SET
      status = 'closed',
      updated_at = timezone('utc', now())
    WHERE fee_assignment_id = $1 AND organization_id = $2 AND school_id = $3
    RETURNING *`,
    [assignmentId, organizationId, schoolId],
  );

  return await enrichAssignmentWithAccount(
    db,
    organizationId,
    schoolId,
    assignment,
    accountRows[0]!,
  );
}

export async function getStudentAccount(
  db: TenantQueryClient,
  organizationId: string,
  schoolId: string,
  studentId: string,
  academicYear?: string,
): Promise<AssignmentWithAccount | null> {
  const accountSql = academicYear
    ? `SELECT * FROM finance_student_accounts
       WHERE student_id = $1 AND organization_id = $2 AND school_id = $3 AND academic_year = $4`
    : `SELECT * FROM finance_student_accounts
       WHERE student_id = $1 AND organization_id = $2 AND school_id = $3
       ORDER BY created_at DESC LIMIT 1`;
  const accountArgs = academicYear
    ? [studentId, organizationId, schoolId, academicYear]
    : [studentId, organizationId, schoolId];

  const accountRows = await db.queryObject<FinanceStudentAccountRow>(
    accountSql,
    accountArgs,
  );
  const account = accountRows[0];
  if (!account) return null;

  const assignment = await getAssignment(
    db,
    organizationId,
    schoolId,
    account.fee_assignment_id,
  );
  if (!assignment) return null;

  const enrich = await enrichAssignmentWithAccount(
    db,
    organizationId,
    schoolId,
    assignment,
    account,
  );
  return enrich;
}

async function enrichAssignmentWithAccount(
  db: TenantQueryClient,
  organizationId: string,
  schoolId: string,
  assignment: FinanceFeeAssignmentRow,
  account: FinanceStudentAccountRow,
  invoice?: FinanceInvoiceRow,
): Promise<AssignmentWithAccount> {
  const structureRows = await db.queryObject<{ name: string }>(
    `SELECT name FROM finance_fee_structures WHERE id = $1 AND organization_id = $2 AND school_id = $3`,
    [assignment.fee_structure_id, organizationId, schoolId],
  );
  const studentRows = await db.queryObject<{ display_name: string }>(
    `SELECT display_name FROM students WHERE id = $1 AND organization_id = $2 AND school_id = $3`,
    [assignment.student_id, organizationId, schoolId],
  );
  const handoffRows = await db.queryObject<{
    admission_number: string;
    class_label: string;
    student_name: string;
  }>(
    `SELECT admission_number, class_label, student_name FROM admissions_fee_handoffs
     WHERE student_id = $1 AND organization_id = $2 AND school_id = $3
     ORDER BY created_at DESC LIMIT 1`,
    [assignment.student_id, organizationId, schoolId],
  );
  const handoff = handoffRows[0];

  const resolvedInvoice = invoice ?? await getInvoiceByAssignmentId(
    db,
    organizationId,
    schoolId,
    assignment.id,
  );
  if (!resolvedInvoice) {
    throw new Error(`Invoice not found for assignment: ${assignment.id}`);
  }

  return {
    assignment,
    account,
    invoice: resolvedInvoice,
    feeStructureName: structureRows[0]?.name,
    studentName: handoff?.student_name ?? studentRows[0]?.display_name,
    admissionNumber: handoff?.admission_number,
    classLabel: handoff?.class_label,
  };
}

/** Assign fee plan from admissions handoff (v6.1 §6 — status → completed). */
export async function assignFromHandoff(
  db: TenantQueryClient,
  organizationId: string,
  schoolId: string,
  handoffId: string,
  feeStructureId: string | null,
  assignedBy: string,
): Promise<AssignmentWithAccount> {
  const handoff = await getFeeHandoffById(db, organizationId, schoolId, handoffId);
  if (!handoff) {
    throw new Error(`Handoff not found: ${handoffId}`);
  }

  if (!ASSIGNABLE_HANDOFF_STATUSES.has(handoff.handoff_status)) {
    throw new HandoffNotReadyError(handoff.handoff_status);
  }

  const structureId = feeStructureId ?? handoff.recommended_fee_plan_id;
  if (!structureId) {
    throw new Error("fee_structure_id is required when handoff has no recommended fee plan");
  }

  const result = await createAssignmentAndAccount(db, organizationId, schoolId, {
    studentId: handoff.student_id,
    feeStructureId: structureId,
    academicYear: handoff.academic_year,
    assignedBy,
  });

  await db.queryObject(
    `UPDATE admissions_fee_handoffs SET
      handoff_status = 'completed',
      sis_handoff_label = 'Fee plan assigned',
      updated_at = timezone('utc', now())
    WHERE id = $1 AND organization_id = $2 AND school_id = $3`,
    [handoffId, organizationId, schoolId],
  );

  return {
    ...result,
    studentName: handoff.student_name,
    admissionNumber: handoff.admission_number,
    classLabel: handoff.class_label,
  };
}
