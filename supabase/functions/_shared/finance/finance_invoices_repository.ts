import type { TenantQueryClient } from "../tenant_db.ts";
import type { PaginationParams, PaginationResult } from "./finance_structures_repository.ts";
import { getFinanceSettingValue } from "./finance_settings_repository.ts";
import { generateInstallmentSchedule } from "./finance_installments_repository.ts";
import { seedHeadAllocations } from "./finance_head_allocations_repository.ts";

export type InvoiceStatus =
  | "draft"
  | "issued"
  | "partially_paid"
  | "paid"
  | "cancelled";

export interface FinanceInvoiceRow {
  id: string;
  organization_id: string;
  school_id: string;
  student_id: string;
  fee_assignment_id: string;
  academic_year: string;
  invoice_number: string;
  invoice_date: string;
  due_date: string;
  subtotal_amount: string;
  discount_amount: string;
  total_amount: string;
  outstanding_amount: string;
  invoice_status: InvoiceStatus;
  // FIN-D5: accrued late fee (0 = not yet accrued) + when it was applied.
  late_fee_amount: string;
  late_fee_accrued_at: string | null;
  created_by: string;
  created_at: string;
  updated_at: string;
}

export interface CreateAnnualInvoiceInput {
  studentId: string;
  feeAssignmentId: string;
  academicYear: string;
  totalAmount: number;
  createdBy: string;
}

export class DuplicateInvoiceError extends Error {
  constructor() {
    super("Invoice already exists for fee assignment");
    this.name = "DuplicateInvoiceError";
  }
}

export class InvalidInvoiceTransitionError extends Error {
  constructor(from: string, action: string) {
    super(`Cannot ${action} invoice in status: ${from}`);
    this.name = "InvalidInvoiceTransitionError";
  }
}

export class InvoiceNotFoundError extends Error {
  constructor(id: string) {
    super(`Invoice not found: ${id}`);
    this.name = "InvoiceNotFoundError";
  }
}

function offsetFor(page: number, pageSize: number): number {
  return Math.max(0, (page - 1) * pageSize);
}

function buildInvoiceNumber(academicYear: string): string {
  const yearPart = academicYear.replace(/-/g, "").slice(0, 4);
  const suffix = crypto.randomUUID().split("-")[0]!.toUpperCase();
  return `INV-${yearPart}-${suffix}`;
}

function addDaysIso(date: Date, days: number): string {
  const next = new Date(date);
  next.setUTCDate(next.getUTCDate() + days);
  return next.toISOString().slice(0, 10);
}

export async function createAnnualInvoice(
  db: TenantQueryClient,
  organizationId: string,
  schoolId: string,
  input: CreateAnnualInvoiceInput,
): Promise<FinanceInvoiceRow> {
  const duplicate = await db.queryObject<{ id: string }>(
    `SELECT id FROM finance_invoices
     WHERE fee_assignment_id = $1 AND organization_id = $2 AND school_id = $3`,
    [input.feeAssignmentId, organizationId, schoolId],
  );
  if (duplicate[0]) {
    throw new DuplicateInvoiceError();
  }

  const now = new Date();
  const invoiceDate = addDaysIso(now, 0);
  // FIN-6: due date driven by the school's `payments.due_days` setting (default
  // "30") instead of the previous hardcoded +30. An unconfigured school still
  // resolves to 30 — behaviour-preserving by default.
  const dueDays = parseInt(
    await getFinanceSettingValue(db, organizationId, schoolId, "payments", "due_days", "30"),
    10,
  );
  const dueDate = addDaysIso(now, Number.isFinite(dueDays) ? dueDays : 30);
  const total = input.totalAmount;
  const invoiceNumber = buildInvoiceNumber(input.academicYear);

  const rows = await db.queryObject<FinanceInvoiceRow>(
    `INSERT INTO finance_invoices (
      organization_id, school_id, student_id, fee_assignment_id,
      academic_year, invoice_number, invoice_date, due_date,
      subtotal_amount, discount_amount, total_amount, outstanding_amount,
      invoice_status, created_by
    ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, 0, $9, $9, 'issued', $10)
    RETURNING *`,
    [
      organizationId,
      schoolId,
      input.studentId,
      input.feeAssignmentId,
      input.academicYear,
      invoiceNumber,
      invoiceDate,
      dueDate,
      total,
      input.createdBy,
    ],
  );

  const invoice = rows[0]!;

  // FIN-6: generate the informational term-wise due schedule (does NOT create
  // extra invoices; the single outstanding stays authoritative).
  await generateInstallmentSchedule(
    db,
    organizationId,
    schoolId,
    invoice.id,
    invoiceDate,
    total,
  );

  // FIN-D2: seed the per-head allocation ledger from the structure items linked
  // via the assignment (falls back to one "General" head = total). Derived
  // ledger only — the invoice outstanding is untouched.
  await seedHeadAllocations(
    db,
    organizationId,
    schoolId,
    invoice.id,
    input.feeAssignmentId,
    total,
  );

  return invoice;
}

export async function listInvoices(
  db: TenantQueryClient,
  organizationId: string,
  schoolId: string,
  pagination: PaginationParams,
): Promise<PaginationResult<FinanceInvoiceRow>> {
  const limit = Math.min(Math.max(pagination.pageSize, 1), 100);
  const offset = offsetFor(pagination.page, limit);

  const total = await db.queryCount(
    `SELECT count(*)::text AS count FROM finance_invoices
     WHERE organization_id = $1 AND school_id = $2`,
    [organizationId, schoolId],
  );

  const items = await db.queryObject<FinanceInvoiceRow>(
    `SELECT * FROM finance_invoices
     WHERE organization_id = $1 AND school_id = $2
     ORDER BY invoice_date DESC, created_at DESC
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

export async function getInvoice(
  db: TenantQueryClient,
  organizationId: string,
  schoolId: string,
  invoiceId: string,
): Promise<FinanceInvoiceRow | null> {
  const rows = await db.queryObject<FinanceInvoiceRow>(
    `SELECT * FROM finance_invoices
     WHERE id = $1 AND organization_id = $2 AND school_id = $3`,
    [invoiceId, organizationId, schoolId],
  );
  return rows[0] ?? null;
}

export async function issueInvoice(
  db: TenantQueryClient,
  organizationId: string,
  schoolId: string,
  invoiceId: string,
): Promise<FinanceInvoiceRow> {
  const existing = await getInvoice(db, organizationId, schoolId, invoiceId);
  if (!existing) {
    throw new InvoiceNotFoundError(invoiceId);
  }
  if (existing.invoice_status !== "draft") {
    throw new InvalidInvoiceTransitionError(existing.invoice_status, "issue");
  }

  // FIN-6: the issue transition now honours the school's `payments.due_days`
  // setting (default 30) instead of a hardcoded +30, and generates the
  // informational term-wise schedule — same as the create path. Removes the
  // last hardcoded due date so ALL invoice aging keys off the configured
  // schedule.
  const now = new Date();
  const invoiceDate = addDaysIso(now, 0);
  const dueDays = parseInt(
    await getFinanceSettingValue(db, organizationId, schoolId, "payments", "due_days", "30"),
    10,
  );
  const dueDate = addDaysIso(now, Number.isFinite(dueDays) ? dueDays : 30);

  const rows = await db.queryObject<FinanceInvoiceRow>(
    `UPDATE finance_invoices
     SET invoice_status = 'issued',
         invoice_date = $4,
         due_date = $5,
         updated_at = timezone('utc', now())
     WHERE id = $1 AND organization_id = $2 AND school_id = $3
     RETURNING *`,
    [invoiceId, organizationId, schoolId, invoiceDate, dueDate],
  );
  const invoice = rows[0]!;
  await generateInstallmentSchedule(
    db,
    organizationId,
    schoolId,
    invoice.id,
    invoiceDate,
    Number(invoice.total_amount ?? existing.total_amount),
  );
  return invoice;
}

export async function cancelInvoice(
  db: TenantQueryClient,
  organizationId: string,
  schoolId: string,
  invoiceId: string,
): Promise<FinanceInvoiceRow> {
  const existing = await getInvoice(db, organizationId, schoolId, invoiceId);
  if (!existing) {
    throw new InvoiceNotFoundError(invoiceId);
  }
  if (existing.invoice_status === "paid" || existing.invoice_status === "cancelled") {
    throw new InvalidInvoiceTransitionError(existing.invoice_status, "cancel");
  }

  // Claim the cancel with a status-GUARDED terminal write. The read above is a
  // TOCTOU check only; without this guard two concurrent cancels would both
  // proceed and each release the account delta below — double-crediting the
  // student. The loser gets 0 rows and throws, rolling back its transaction.
  const rows = await db.queryObject<FinanceInvoiceRow>(
    `UPDATE finance_invoices
     SET invoice_status = 'cancelled', updated_at = timezone('utc', now())
     WHERE id = $1 AND organization_id = $2 AND school_id = $3
       AND invoice_status NOT IN ('paid', 'cancelled')
     RETURNING *`,
    [invoiceId, organizationId, schoolId],
  );
  if (rows.length === 0) {
    throw new InvalidInvoiceTransitionError(existing.invoice_status, "cancel");
  }
  const cancelled = rows[0]!;

  // LOCKSTEP with the student account (mirrors approveFeeReduction / waiveLateFee).
  // finance_student_accounts.{total_fee,outstanding_amount} are STORED aggregates
  // that assignFeeStructure incremented when this invoice was raised — nothing
  // re-derives them. Cancelling only the invoice therefore left the unpaid
  // remainder owing on the account: the student stayed a false defaulter and their
  // no-dues / TC gate stayed blocked. Release exactly the still-unpaid remainder
  // (RETURNING carries the PRE-cancel outstanding, since only status moved), which
  // preserves outstanding == total_fee - amount_paid and leaves real payments intact.
  const released = Math.max(0, Math.round(parseFloat(cancelled.outstanding_amount) * 100) / 100);
  if (Number.isFinite(released) && released > 0) {
    await db.queryObject(
      `UPDATE finance_student_accounts SET
         total_fee = GREATEST(0, total_fee - $1),
         outstanding_amount = GREATEST(0, outstanding_amount - $1),
         updated_at = timezone('utc', now())
       WHERE student_id = $2 AND academic_year = $3
         AND organization_id = $4 AND school_id = $5`,
      [
        released.toFixed(2),
        cancelled.student_id,
        cancelled.academic_year,
        organizationId,
        schoolId,
      ],
    );
  }
  return cancelled;
}

export async function getInvoiceByAssignmentId(
  db: TenantQueryClient,
  organizationId: string,
  schoolId: string,
  feeAssignmentId: string,
): Promise<FinanceInvoiceRow | null> {
  const rows = await db.queryObject<FinanceInvoiceRow>(
    `SELECT * FROM finance_invoices
     WHERE fee_assignment_id = $1 AND organization_id = $2 AND school_id = $3`,
    [feeAssignmentId, organizationId, schoolId],
  );
  return rows[0] ?? null;
}
