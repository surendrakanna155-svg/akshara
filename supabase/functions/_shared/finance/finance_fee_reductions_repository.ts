// STEP-5 — fee reductions (scholarships + discounts) that ACTUALLY reduce a
// student's payable, but ONLY through a two-person maker-checker.
//
// This mirrors the certified money-reduction references in this codebase:
//   * FIN-D4 fee concessions + refunds — the maker-checker where the approver
//     must NOT be the requester (finance_refunds_repository.approveRefund's
//     `requested_by !== approvedBy` guard), the approver id is server-set (never
//     client-supplied), and the money mutation lives in FINANCE.
//   * waiveLateFee / createCollection / applyProcessedRefund — the invoice ↔
//     student-account LOCKSTEP: the invoice outstanding and the account
//     outstanding always move by the SAME delta, under a `FOR UPDATE OF fi`
//     row lock, with the account side floored at 0 defensively.
//
// A reduction is born `pending` and changes NO money. Only `approveFeeReduction`
// (by someone other than the proposer) applies it — reducing the invoice AND the
// account outstanding by the exact same, clamped, `applied_amount`, so the
// payable can never go negative and can never be double-applied. `reverse`
// undoes it by the same amount in lockstep.

import type { TenantQueryClient } from "../tenant_db.ts";
import { computeInvoiceStatus } from "./finance_collections_repository.ts";
import {
  reduceHeadTotals,
  restoreHeadTotals,
} from "./finance_head_allocations_repository.ts";

export type FeeReductionSourceKind = "scholarship" | "discount";
export type FeeReductionKind = "percent" | "fixed";
export type FeeReductionStatus = "pending" | "approved" | "rejected" | "reversed";

export interface FinanceFeeReductionRow {
  id: string;
  organization_id: string;
  school_id: string;
  source_kind: FeeReductionSourceKind;
  scholarship_id: string | null;
  discount_rule_id: string | null;
  student_id: string;
  invoice_id: string;
  student_account_id: string;
  reduction_kind: FeeReductionKind;
  percent: string | null;
  fixed_amount: string | null;
  applied_amount: string;
  status: FeeReductionStatus;
  reason: string;
  created_by: string;
  approved_by: string | null;
  reversed_by: string | null;
  applied_at: string | null;
  reversed_at: string | null;
  created_at: string;
  updated_at: string;
}

export interface ProposeFeeReductionInput {
  sourceKind: FeeReductionSourceKind;
  /** scholarship id (sourceKind='scholarship') OR discount rule id ('discount'). */
  sourceId: string;
  invoiceId: string;
  reductionKind: FeeReductionKind;
  /** percent 0<..<=100 when reductionKind='percent'. */
  percent?: number | null;
  /** fixed amount > 0 when reductionKind='fixed'. */
  fixedAmount?: number | null;
  reason: string;
  createdBy: string;
}

export class FeeReductionNotFoundError extends Error {
  constructor(id: string) {
    super(`Fee reduction not found: ${id}`);
    this.name = "FeeReductionNotFoundError";
  }
}

export class FeeReductionValidationError extends Error {
  constructor(message: string) {
    super(message);
    this.name = "FeeReductionValidationError";
  }
}

export class FeeReductionInvalidStateError extends Error {
  constructor(
    public readonly id: string,
    public readonly currentStatus: string,
    public readonly action: string,
  ) {
    super(`Cannot ${action} fee reduction ${id} (status=${currentStatus})`);
    this.name = "FeeReductionInvalidStateError";
  }
}

/**
 * Maker-checker: a fee reduction cannot be approved by the same user who
 * proposed it. Mirrors RefundSelfApprovalError — enforced server-side, before
 * any money mutation, and cannot be bypassed by holding both manage + approve.
 */
export class FeeReductionSelfApprovalError extends Error {
  constructor(
    message = "A fee reduction cannot be approved by the person who proposed it",
  ) {
    super(message);
    this.name = "FeeReductionSelfApprovalError";
  }
}

function parseAmount(value: string | number | null | undefined): number {
  if (value == null) return 0;
  const num = typeof value === "number" ? value : parseFloat(value);
  return Number.isFinite(num) ? num : 0;
}

function round2(n: number): number {
  return Math.round((n + Number.EPSILON) * 100) / 100;
}

function formatNumeric(value: number): string {
  const rounded = round2(value);
  return Number.isInteger(rounded) ? String(rounded) : rounded.toFixed(2);
}

/**
 * The intended reduction BEFORE clamping:
 *   - fixed  → the fixed amount as-is.
 *   - percent → percent of the invoice SUBTOTAL (the gross fee — a stable base
 *     that a prior discount does NOT shrink, so "50%" always means 50% of the
 *     original fee, and two awards never compound off each other's output).
 * Never negative.
 */
export function computeIntendedReduction(
  reduction: Pick<FinanceFeeReductionRow, "reduction_kind" | "percent" | "fixed_amount">,
  subtotal: number,
): number {
  if (reduction.reduction_kind === "fixed") {
    return Math.max(0, round2(parseAmount(reduction.fixed_amount)));
  }
  const pct = parseAmount(reduction.percent);
  return Math.max(0, round2((subtotal * pct) / 100));
}

/**
 * Clamp the intended reduction so the payable can NEVER go negative and the
 * invoice total can NEVER drop below zero:
 *   applied = min(intended, current outstanding, current total).
 * Because SUM(head_remaining) == outstanding and account.outstanding >=
 * invoice.outstanding, this same `applied` is absorbable by the head ledger AND
 * the account without either going negative.
 */
export function clampApplied(
  intended: number,
  outstanding: number,
  total: number,
): number {
  const capped = Math.min(
    Math.max(0, round2(intended)),
    Math.max(0, round2(outstanding)),
    Math.max(0, round2(total)),
  );
  return Math.max(0, round2(capped));
}

interface InvoiceLockRow {
  id: string;
  student_id: string;
  fee_assignment_id: string;
  subtotal_amount: string;
  discount_amount: string;
  total_amount: string;
  outstanding_amount: string;
  invoice_status: string;
  student_account_id: string;
}

/**
 * Load + row-lock the invoice and its student account together (mirrors
 * waiveLateFee): the account is resolved via fee_assignment_id, NOT trusted from
 * the client, so the reduction can only touch the invoice's own account.
 * `FOR UPDATE OF fi` serialises against a concurrent collection/refund on the
 * same invoice.
 */
async function loadInvoiceForReduction(
  db: TenantQueryClient,
  organizationId: string,
  schoolId: string,
  invoiceId: string,
): Promise<InvoiceLockRow | null> {
  const rows = await db.queryObject<InvoiceLockRow>(
    `SELECT fi.id, fi.student_id, fi.fee_assignment_id,
            fi.subtotal_amount, fi.discount_amount, fi.total_amount,
            fi.outstanding_amount, fi.invoice_status,
            fsa.id AS student_account_id
       FROM finance_invoices fi
       JOIN finance_student_accounts fsa
         ON fsa.fee_assignment_id = fi.fee_assignment_id
        AND fsa.organization_id = fi.organization_id
        AND fsa.school_id = fi.school_id
      WHERE fi.id = $1 AND fi.organization_id = $2 AND fi.school_id = $3
      FOR UPDATE OF fi`,
    [invoiceId, organizationId, schoolId],
  );
  return rows[0] ?? null;
}

async function getReductionForUpdate(
  db: TenantQueryClient,
  organizationId: string,
  schoolId: string,
  id: string,
): Promise<FinanceFeeReductionRow | null> {
  const rows = await db.queryObject<FinanceFeeReductionRow>(
    `SELECT * FROM finance_fee_reductions
      WHERE id = $1 AND organization_id = $2 AND school_id = $3
      FOR UPDATE`,
    [id, organizationId, schoolId],
  );
  return rows[0] ?? null;
}

export async function getFeeReduction(
  db: TenantQueryClient,
  organizationId: string,
  schoolId: string,
  id: string,
): Promise<FinanceFeeReductionRow | null> {
  const rows = await db.queryObject<FinanceFeeReductionRow>(
    `SELECT * FROM finance_fee_reductions
      WHERE id = $1 AND organization_id = $2 AND school_id = $3`,
    [id, organizationId, schoolId],
  );
  return rows[0] ?? null;
}

/**
 * Propose a fee reduction (the MAKER step). Validates the source (scholarship /
 * discount rule) and the target invoice, resolves the student + account FROM the
 * invoice (authoritative), and inserts a `pending` row that reduces NOTHING.
 */
export async function proposeFeeReduction(
  db: TenantQueryClient,
  organizationId: string,
  schoolId: string,
  input: ProposeFeeReductionInput,
): Promise<FinanceFeeReductionRow> {
  // Value validation (mirrors the DB CHECK, surfaced as a 422 not a 500).
  if (input.reductionKind === "percent") {
    const pct = input.percent ?? 0;
    if (!(pct > 0 && pct <= 100)) {
      throw new FeeReductionValidationError("percent must be > 0 and <= 100");
    }
  } else {
    const amt = input.fixedAmount ?? 0;
    if (!(amt > 0)) {
      throw new FeeReductionValidationError("fixed amount must be greater than zero");
    }
  }

  // Target invoice must exist, be collectible (not cancelled), and expose its
  // account. student_id + account come from the invoice — never the client.
  const invoice = await loadInvoiceForReduction(db, organizationId, schoolId, input.invoiceId);
  if (!invoice) {
    throw new FeeReductionValidationError(`Invoice not found: ${input.invoiceId}`);
  }
  if (invoice.invoice_status === "cancelled") {
    throw new FeeReductionValidationError("Cannot reduce a cancelled invoice");
  }

  // Source must exist in THIS tenant/school.
  if (input.sourceKind === "scholarship") {
    const rows = await db.queryObject<{ id: string }>(
      `SELECT id FROM finance_scholarships
        WHERE id = $1 AND organization_id = $2 AND school_id = $3`,
      [input.sourceId, organizationId, schoolId],
    );
    if (!rows[0]) {
      throw new FeeReductionValidationError(`Scholarship not found: ${input.sourceId}`);
    }
  } else {
    const rows = await db.queryObject<{ id: string }>(
      `SELECT id FROM finance_discount_rules
        WHERE id = $1 AND organization_id = $2 AND school_id = $3`,
      [input.sourceId, organizationId, schoolId],
    );
    if (!rows[0]) {
      throw new FeeReductionValidationError(`Discount rule not found: ${input.sourceId}`);
    }
  }

  const scholarshipId = input.sourceKind === "scholarship" ? input.sourceId : null;
  const discountRuleId = input.sourceKind === "discount" ? input.sourceId : null;
  const percent = input.reductionKind === "percent" ? round2(input.percent ?? 0) : null;
  const fixedAmount = input.reductionKind === "fixed" ? round2(input.fixedAmount ?? 0) : null;

  const rows = await db.queryObject<FinanceFeeReductionRow>(
    `INSERT INTO finance_fee_reductions (
       organization_id, school_id, source_kind, scholarship_id, discount_rule_id,
       student_id, invoice_id, student_account_id, reduction_kind, percent,
       fixed_amount, applied_amount, status, reason, created_by
     ) VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,0,'pending',$12,$13)
     RETURNING *`,
    [
      organizationId,
      schoolId,
      input.sourceKind,
      scholarshipId,
      discountRuleId,
      invoice.student_id,
      invoice.id,
      invoice.student_account_id,
      input.reductionKind,
      percent,
      fixedAmount,
      input.reason ?? "",
      input.createdBy,
    ],
  );
  return rows[0]!;
}

/**
 * Apply a pending reduction to the payable (the CHECKER step). The approver
 * (`approvedBy`, server-set to claims.sub) must NOT be the proposer.
 *
 * Money mutation (all inside the same tenant transaction):
 *   invoice:  discount_amount += applied, total_amount -= applied,
 *             outstanding_amount -= applied, invoice_status recomputed.
 *   account:  total_fee -= applied, outstanding_amount -= applied  (GREATEST 0).
 *   heads:    head_total_minor reduced by `applied` (keeps SUM == total).
 * `applied` is clamped so nothing goes negative, and stored on the row so the
 * reversal is exact. The final flip is GUARDED on `status='pending'` so a
 * concurrent double-approve applies the money exactly ONCE.
 */
export async function approveFeeReduction(
  db: TenantQueryClient,
  organizationId: string,
  schoolId: string,
  id: string,
  approvedBy: string,
): Promise<FinanceFeeReductionRow> {
  const reduction = await getReductionForUpdate(db, organizationId, schoolId, id);
  if (!reduction) {
    throw new FeeReductionNotFoundError(id);
  }
  if (reduction.status !== "pending") {
    throw new FeeReductionInvalidStateError(id, reduction.status, "approve");
  }
  // Separation of duties: proposer may not approve their own reduction. Only
  // enforced when created_by is known (never null in practice — it is NOT NULL).
  if (reduction.created_by && reduction.created_by === approvedBy) {
    throw new FeeReductionSelfApprovalError();
  }

  const invoice = await loadInvoiceForReduction(
    db,
    organizationId,
    schoolId,
    reduction.invoice_id,
  );
  if (!invoice) {
    throw new FeeReductionValidationError(`Invoice not found: ${reduction.invoice_id}`);
  }
  if (invoice.invoice_status === "cancelled") {
    throw new FeeReductionValidationError("Cannot reduce a cancelled invoice");
  }

  const subtotal = parseAmount(invoice.subtotal_amount);
  const total = parseAmount(invoice.total_amount);
  const outstanding = parseAmount(invoice.outstanding_amount);

  const intended = computeIntendedReduction(reduction, subtotal);
  const applied = clampApplied(intended, outstanding, total);

  const newDiscount = round2(parseAmount(invoice.discount_amount) + applied);
  const newTotal = Math.max(0, round2(total - applied));
  const newOutstanding = Math.max(0, round2(outstanding - applied));
  const newInvoiceStatus = computeInvoiceStatus(newOutstanding, newTotal);

  await db.queryObject(
    `UPDATE finance_invoices SET
       discount_amount = $1,
       total_amount = $2,
       outstanding_amount = $3,
       invoice_status = $4,
       updated_at = timezone('utc', now())
     WHERE id = $5 AND organization_id = $6 AND school_id = $7`,
    [
      formatNumeric(newDiscount),
      formatNumeric(newTotal),
      formatNumeric(newOutstanding),
      newInvoiceStatus,
      invoice.id,
      organizationId,
      schoolId,
    ],
  );

  // LOCKSTEP: the account moves by the SAME `applied` delta as the invoice.
  await db.queryObject(
    `UPDATE finance_student_accounts SET
       total_fee = GREATEST(0, total_fee - $1),
       outstanding_amount = GREATEST(0, outstanding_amount - $1),
       updated_at = timezone('utc', now())
     WHERE id = $2 AND organization_id = $3 AND school_id = $4`,
    [formatNumeric(applied), invoice.student_account_id, organizationId, schoolId],
  );

  // Keep the derived head ledger reconciled: SUM(head_total) == invoice total.
  if (applied > 0) {
    await reduceHeadTotals(db, organizationId, schoolId, invoice.id, applied);
  }

  const updated = await db.queryObject<FinanceFeeReductionRow>(
    `UPDATE finance_fee_reductions SET
       status = 'approved',
       applied_amount = $1,
       approved_by = $2,
       applied_at = timezone('utc', now()),
       student_account_id = $3,
       updated_at = timezone('utc', now())
     WHERE id = $4 AND organization_id = $5 AND school_id = $6 AND status = 'pending'
     RETURNING *`,
    [
      formatNumeric(applied),
      approvedBy,
      invoice.student_account_id,
      id,
      organizationId,
      schoolId,
    ],
  );
  if (updated.length === 0) {
    // A concurrent approve won the race (row no longer pending). The enclosing
    // transaction rolls back the money mutation above — never double-applied.
    throw new FeeReductionInvalidStateError(id, reduction.status, "approve");
  }
  return updated[0]!;
}

/**
 * Reject a pending reduction (CHECKER). No money moves. Guarded on `pending`.
 */
export async function rejectFeeReduction(
  db: TenantQueryClient,
  organizationId: string,
  schoolId: string,
  id: string,
  rejectedBy: string,
): Promise<FinanceFeeReductionRow> {
  const reduction = await getReductionForUpdate(db, organizationId, schoolId, id);
  if (!reduction) {
    throw new FeeReductionNotFoundError(id);
  }
  if (reduction.status !== "pending") {
    throw new FeeReductionInvalidStateError(id, reduction.status, "reject");
  }
  const updated = await db.queryObject<FinanceFeeReductionRow>(
    `UPDATE finance_fee_reductions SET
       status = 'rejected',
       approved_by = $1,
       updated_at = timezone('utc', now())
     WHERE id = $2 AND organization_id = $3 AND school_id = $4 AND status = 'pending'
     RETURNING *`,
    [rejectedBy, id, organizationId, schoolId],
  );
  if (updated.length === 0) {
    throw new FeeReductionInvalidStateError(id, reduction.status, "reject");
  }
  return updated[0]!;
}

/**
 * Reverse an approved reduction — add the EXACT `applied_amount` back to the
 * invoice + account in lockstep (and restore the head totals), then flip to
 * `reversed`. Guarded on `status='approved'` so it can only ever add the money
 * back ONCE.
 */
export async function reverseFeeReduction(
  db: TenantQueryClient,
  organizationId: string,
  schoolId: string,
  id: string,
  reversedBy: string,
): Promise<FinanceFeeReductionRow> {
  const reduction = await getReductionForUpdate(db, organizationId, schoolId, id);
  if (!reduction) {
    throw new FeeReductionNotFoundError(id);
  }
  if (reduction.status !== "approved") {
    throw new FeeReductionInvalidStateError(id, reduction.status, "reverse");
  }

  const applied = round2(parseAmount(reduction.applied_amount));

  const invoice = await loadInvoiceForReduction(
    db,
    organizationId,
    schoolId,
    reduction.invoice_id,
  );
  if (!invoice) {
    throw new FeeReductionValidationError(`Invoice not found: ${reduction.invoice_id}`);
  }

  if (applied > 0) {
    const total = parseAmount(invoice.total_amount);
    const outstanding = parseAmount(invoice.outstanding_amount);
    const newDiscount = Math.max(0, round2(parseAmount(invoice.discount_amount) - applied));
    const newTotal = round2(total + applied);
    const newOutstanding = round2(outstanding + applied);
    const newInvoiceStatus = computeInvoiceStatus(newOutstanding, newTotal);

    await db.queryObject(
      `UPDATE finance_invoices SET
         discount_amount = $1,
         total_amount = $2,
         outstanding_amount = $3,
         invoice_status = $4,
         updated_at = timezone('utc', now())
       WHERE id = $5 AND organization_id = $6 AND school_id = $7`,
      [
        formatNumeric(newDiscount),
        formatNumeric(newTotal),
        formatNumeric(newOutstanding),
        newInvoiceStatus,
        invoice.id,
        organizationId,
        schoolId,
      ],
    );

    await db.queryObject(
      `UPDATE finance_student_accounts SET
         total_fee = total_fee + $1,
         outstanding_amount = outstanding_amount + $1,
         updated_at = timezone('utc', now())
       WHERE id = $2 AND organization_id = $3 AND school_id = $4`,
      [formatNumeric(applied), invoice.student_account_id, organizationId, schoolId],
    );

    await restoreHeadTotals(db, organizationId, schoolId, invoice.id, applied);
  }

  const updated = await db.queryObject<FinanceFeeReductionRow>(
    `UPDATE finance_fee_reductions SET
       status = 'reversed',
       reversed_by = $1,
       reversed_at = timezone('utc', now()),
       updated_at = timezone('utc', now())
     WHERE id = $2 AND organization_id = $3 AND school_id = $4 AND status = 'approved'
     RETURNING *`,
    [reversedBy, id, organizationId, schoolId],
  );
  if (updated.length === 0) {
    // Lost the race to a concurrent reverse — the add-back is rolled back with
    // the enclosing transaction, so the money is restored exactly once.
    throw new FeeReductionInvalidStateError(id, reduction.status, "reverse");
  }
  return updated[0]!;
}

export interface FeeReductionListFilter {
  status?: FeeReductionStatus;
  invoiceId?: string;
  studentId?: string;
  sourceKind?: FeeReductionSourceKind;
}

export async function listFeeReductions(
  db: TenantQueryClient,
  organizationId: string,
  schoolId: string,
  filter: FeeReductionListFilter = {},
): Promise<FinanceFeeReductionRow[]> {
  const clauses = ["organization_id = $1", "school_id = $2"];
  const args: unknown[] = [organizationId, schoolId];
  let idx = 3;
  if (filter.status) {
    clauses.push(`status = $${idx++}`);
    args.push(filter.status);
  }
  if (filter.invoiceId) {
    clauses.push(`invoice_id = $${idx++}`);
    args.push(filter.invoiceId);
  }
  if (filter.studentId) {
    clauses.push(`student_id = $${idx++}`);
    args.push(filter.studentId);
  }
  if (filter.sourceKind) {
    clauses.push(`source_kind = $${idx++}`);
    args.push(filter.sourceKind);
  }
  return await db.queryObject<FinanceFeeReductionRow>(
    `SELECT * FROM finance_fee_reductions
      WHERE ${clauses.join(" AND ")}
      ORDER BY created_at DESC`,
    args,
  );
}

/** Map a DB row to the camelCase API shape. */
export function feeReductionToApi(row: FinanceFeeReductionRow): Record<string, unknown> {
  return {
    id: row.id,
    sourceKind: row.source_kind,
    scholarshipId: row.scholarship_id,
    discountRuleId: row.discount_rule_id,
    studentId: row.student_id,
    invoiceId: row.invoice_id,
    studentAccountId: row.student_account_id,
    reductionKind: row.reduction_kind,
    percent: row.percent != null ? String(row.percent) : null,
    fixedAmount: row.fixed_amount != null ? String(row.fixed_amount) : null,
    appliedAmount: String(row.applied_amount),
    status: row.status,
    reason: row.reason,
    createdBy: row.created_by,
    approvedBy: row.approved_by,
    reversedBy: row.reversed_by,
    appliedAt: row.applied_at,
    reversedAt: row.reversed_at,
    createdAt: row.created_at,
    updatedAt: row.updated_at,
  };
}
