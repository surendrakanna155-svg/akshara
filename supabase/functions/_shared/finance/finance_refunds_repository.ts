import type { TenantQueryClient } from "../tenant_db.ts";
import type { FinanceCollectionRow } from "./finance_collections_repository.ts";
import { computeInvoiceStatus } from "./finance_collections_repository.ts";
import type { FinanceInvoiceRow } from "./finance_invoices_repository.ts";
import type { PaginationParams, PaginationResult } from "./finance_structures_repository.ts";

export type RefundStatus = "pending" | "approved" | "rejected" | "processed";

export interface FinanceRefundRow {
  id: string;
  organization_id: string;
  school_id: string;
  invoice_id: string;
  collection_id: string;
  student_account_id: string;
  refund_amount: string;
  refund_reason: string;
  refund_status: RefundStatus;
  approved_by: string | null;
  requested_by: string;
  approved_at: string | null;
  created_at: string;
  updated_at: string;
}

export interface RefundListRow extends FinanceRefundRow {
  student_name?: string;
  admission_number?: string;
  class_label?: string;
  receipt_number?: string;
}

export interface CreateRefundInput {
  collectionId?: string;
  studentAccountId?: string;
  originalReceipt?: string;
  refundAmount: number;
  refundReason: string;
  requestedBy: string;
}

export class RefundNotFoundError extends Error {
  constructor(id: string) {
    super(`Refund not found: ${id}`);
    this.name = "RefundNotFoundError";
  }
}

export class RefundAmountError extends Error {
  constructor(message: string) {
    super(message);
    this.name = "RefundAmountError";
  }
}

export class RefundNotCollectibleError extends Error {
  constructor(message: string) {
    super(message);
    this.name = "RefundNotCollectibleError";
  }
}

export class InvalidRefundTransitionError extends Error {
  constructor(message: string) {
    super(message);
    this.name = "InvalidRefundTransitionError";
  }
}

export class RefundSelfApprovalError extends Error {
  constructor(message = "A refund cannot be approved by its requester") {
    super(message);
    this.name = "RefundSelfApprovalError";
  }
}

function offsetFor(page: number, pageSize: number): number {
  return Math.max(0, (page - 1) * pageSize);
}

function parseAmount(value: string | number): number {
  const num = typeof value === "number" ? value : parseFloat(value);
  return Number.isFinite(num) ? num : 0;
}

function formatNumeric(value: number): string {
  return Number.isInteger(value) ? String(value) : value.toFixed(2);
}

async function loadCollectionForRefund(
  db: TenantQueryClient,
  organizationId: string,
  schoolId: string,
  input: CreateRefundInput,
): Promise<FinanceCollectionRow> {
  if (input.collectionId) {
    const rows = await db.queryObject<FinanceCollectionRow>(
      `SELECT * FROM finance_collections
       WHERE id = $1 AND organization_id = $2 AND school_id = $3`,
      [input.collectionId, organizationId, schoolId],
    );
    const collection = rows[0];
    if (!collection) {
      throw new RefundNotCollectibleError(`Collection not found: ${input.collectionId}`);
    }
    return collection;
  }

  const receipt = input.originalReceipt?.trim();
  const accountId = input.studentAccountId?.trim();
  if (!receipt || !accountId) {
    throw new RefundNotCollectibleError(
      "collectionId or (studentAccountId + originalReceipt) is required",
    );
  }

  const rows = await db.queryObject<FinanceCollectionRow>(
    `SELECT * FROM finance_collections
     WHERE receipt_number = $1
       AND student_account_id = $2
       AND organization_id = $3
       AND school_id = $4
     ORDER BY created_at DESC
     LIMIT 1`,
    [receipt, accountId, organizationId, schoolId],
  );
  const collection = rows[0];
  if (!collection) {
    throw new RefundNotCollectibleError(
      `Collection not found for receipt ${receipt} and account ${accountId}`,
    );
  }
  return collection;
}

async function sumRefundedForCollection(
  db: TenantQueryClient,
  organizationId: string,
  schoolId: string,
  collectionId: string,
  excludeRefundId?: string,
): Promise<number> {
  const rows = await db.queryObject<{ total: string }>(
    `SELECT COALESCE(SUM(refund_amount), 0)::text AS total
     FROM finance_refunds
     WHERE collection_id = $1
       AND organization_id = $2
       AND school_id = $3
       AND refund_status IN ('pending', 'approved', 'processed')
       ${excludeRefundId ? "AND id <> $4" : ""}`,
    excludeRefundId
      ? [collectionId, organizationId, schoolId, excludeRefundId]
      : [collectionId, organizationId, schoolId],
  );
  return parseAmount(rows[0]?.total ?? "0");
}

function assertRefundableCollection(collection: FinanceCollectionRow): void {
  if (collection.collection_status === "cancelled") {
    throw new RefundNotCollectibleError("Cannot refund a cancelled collection");
  }
  if (collection.collection_status === "draft") {
    throw new RefundNotCollectibleError("Cannot refund a draft collection");
  }
}

function collectionStatusAfterRefund(
  collectionAmount: number,
  totalRefunded: number,
): "partially_refunded" | "refunded" | "completed" {
  if (totalRefunded <= 0) return "completed";
  if (totalRefunded >= collectionAmount) return "refunded";
  return "partially_refunded";
}

export async function createRefund(
  db: TenantQueryClient,
  organizationId: string,
  schoolId: string,
  input: CreateRefundInput,
): Promise<RefundListRow> {
  if (!Number.isFinite(input.refundAmount) || input.refundAmount <= 0) {
    throw new RefundAmountError("Refund amount must be greater than zero");
  }
  if (!input.refundReason.trim()) {
    throw new RefundAmountError("Refund reason is required");
  }

  const collection = await loadCollectionForRefund(db, organizationId, schoolId, input);
  assertRefundableCollection(collection);

  const collectionAmount = parseAmount(collection.amount_collected);
  const alreadyRefunded = await sumRefundedForCollection(
    db,
    organizationId,
    schoolId,
    collection.id,
  );
  if (alreadyRefunded + input.refundAmount > collectionAmount) {
    throw new RefundAmountError(
      `Refund amount exceeds remaining refundable amount for collection (${collectionAmount - alreadyRefunded})`,
    );
  }

  const rows = await db.queryObject<FinanceRefundRow>(
    `INSERT INTO finance_refunds (
      organization_id, school_id, invoice_id, collection_id, student_account_id,
      refund_amount, refund_reason, refund_status, requested_by
    ) VALUES ($1, $2, $3, $4, $5, $6, $7, 'pending', $8)
    RETURNING *`,
    [
      organizationId,
      schoolId,
      collection.invoice_id,
      collection.id,
      collection.student_account_id,
      input.refundAmount,
      input.refundReason.trim(),
      input.requestedBy,
    ],
  );

  return (await getRefund(db, organizationId, schoolId, rows[0]!.id))!;
}

export async function listRefunds(
  db: TenantQueryClient,
  organizationId: string,
  schoolId: string,
  pagination: PaginationParams,
): Promise<PaginationResult<RefundListRow>> {
  const limit = Math.min(Math.max(pagination.pageSize, 1), 100);
  const offset = offsetFor(pagination.page, limit);

  const total = await db.queryCount(
    `SELECT count(*)::text AS count FROM finance_refunds
     WHERE organization_id = $1 AND school_id = $2`,
    [organizationId, schoolId],
  );

  const items = await db.queryObject<RefundListRow>(
    `SELECT fr.*,
       COALESCE(s.display_name, afh.student_name) AS student_name,
       afh.admission_number,
       afh.class_label,
       fc.receipt_number
     FROM finance_refunds fr
     JOIN finance_collections fc ON fc.id = fr.collection_id
     LEFT JOIN students s
       ON s.id = fc.student_id
      AND s.organization_id = fr.organization_id
      AND s.school_id = fr.school_id
     LEFT JOIN LATERAL (
       SELECT student_name, admission_number, class_label
       FROM admissions_fee_handoffs
       WHERE student_id = fc.student_id
         AND organization_id = fr.organization_id
         AND school_id = fr.school_id
       ORDER BY created_at DESC
       LIMIT 1
     ) afh ON true
     WHERE fr.organization_id = $1 AND fr.school_id = $2
     ORDER BY fr.created_at DESC
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

export async function getRefund(
  db: TenantQueryClient,
  organizationId: string,
  schoolId: string,
  refundId: string,
): Promise<RefundListRow | null> {
  const rows = await db.queryObject<RefundListRow>(
    `SELECT fr.*,
       COALESCE(s.display_name, afh.student_name) AS student_name,
       afh.admission_number,
       afh.class_label,
       fc.receipt_number
     FROM finance_refunds fr
     JOIN finance_collections fc ON fc.id = fr.collection_id
     LEFT JOIN students s
       ON s.id = fc.student_id
      AND s.organization_id = fr.organization_id
      AND s.school_id = fr.school_id
     LEFT JOIN LATERAL (
       SELECT student_name, admission_number, class_label
       FROM admissions_fee_handoffs
       WHERE student_id = fc.student_id
         AND organization_id = fr.organization_id
         AND school_id = fr.school_id
       ORDER BY created_at DESC
       LIMIT 1
     ) afh ON true
     WHERE fr.id = $1 AND fr.organization_id = $2 AND fr.school_id = $3`,
    [refundId, organizationId, schoolId],
  );
  return rows[0] ?? null;
}

async function applyProcessedRefund(
  db: TenantQueryClient,
  organizationId: string,
  schoolId: string,
  refund: FinanceRefundRow,
  collection: FinanceCollectionRow,
  approvedBy: string,
): Promise<RefundListRow> {
  const refundAmount = parseAmount(refund.refund_amount);

  const invoiceRows = await db.queryObject<FinanceInvoiceRow>(
    `SELECT * FROM finance_invoices
     WHERE id = $1 AND organization_id = $2 AND school_id = $3`,
    [refund.invoice_id, organizationId, schoolId],
  );
  const invoice = invoiceRows[0];
  if (!invoice) {
    throw new RefundNotCollectibleError(`Invoice not found: ${refund.invoice_id}`);
  }

  const total = parseAmount(invoice.total_amount);
  const newOutstanding = parseAmount(invoice.outstanding_amount) + refundAmount;
  const newInvoiceStatus = computeInvoiceStatus(newOutstanding, total);

  await db.queryObject(
    `UPDATE finance_invoices SET
      outstanding_amount = $1,
      invoice_status = $2,
      updated_at = timezone('utc', now())
     WHERE id = $3 AND organization_id = $4 AND school_id = $5`,
    [formatNumeric(newOutstanding), newInvoiceStatus, invoice.id, organizationId, schoolId],
  );

  await db.queryObject(
    `UPDATE finance_student_accounts SET
      amount_paid = amount_paid - $1,
      outstanding_amount = outstanding_amount + $1,
      updated_at = timezone('utc', now())
     WHERE id = $2 AND organization_id = $3 AND school_id = $4`,
    [refundAmount, refund.student_account_id, organizationId, schoolId],
  );

  const totalRefunded = await sumRefundedForCollection(
    db,
    organizationId,
    schoolId,
    collection.id,
    refund.id,
  ) + refundAmount;
  const newCollectionStatus = collectionStatusAfterRefund(
    parseAmount(collection.amount_collected),
    totalRefunded,
  );

  await db.queryObject(
    `UPDATE finance_collections SET
      collection_status = $1,
      updated_at = timezone('utc', now())
     WHERE id = $2 AND organization_id = $3 AND school_id = $4`,
    [newCollectionStatus, collection.id, organizationId, schoolId],
  );

  const updatedRows = await db.queryObject<FinanceRefundRow>(
    `UPDATE finance_refunds SET
      refund_status = 'processed',
      approved_by = $1,
      approved_at = timezone('utc', now()),
      updated_at = timezone('utc', now())
     WHERE id = $2 AND organization_id = $3 AND school_id = $4
       AND refund_status = 'pending'
     RETURNING *`,
    [approvedBy, refund.id, organizationId, schoolId],
  );
  if (updatedRows.length === 0) {
    // A concurrent approval won the race (the row is no longer pending) — its
    // status guard let it through while ours must not double-apply. The
    // unconditional `AND refund_status = 'pending'` terminal predicate mirrors
    // the certified fee-reduction path; the enclosing transaction rolls back the
    // invoice/account/collection mutations above, so the money moves exactly once.
    throw new InvalidRefundTransitionError(
      `Cannot approve refund in status: ${refund.refund_status} (concurrent transition)`,
    );
  }

  return (await getRefund(db, organizationId, schoolId, updatedRows[0]!.id))!;
}

export async function approveRefund(
  db: TenantQueryClient,
  organizationId: string,
  schoolId: string,
  refundId: string,
  approvedBy: string,
): Promise<RefundListRow> {
  const refund = await getRefund(db, organizationId, schoolId, refundId);
  if (!refund) {
    throw new RefundNotFoundError(refundId);
  }
  if (refund.refund_status !== "pending") {
    throw new InvalidRefundTransitionError(
      `Cannot approve refund in status: ${refund.refund_status}`,
    );
  }

  // Maker-checker: the approver must not be the requester. Only enforced when
  // the requester id is known (legacy rows with a null requester are skipped
  // rather than blocked). This runs before any state mutation below.
  if (refund.requested_by && refund.requested_by === approvedBy) {
    throw new RefundSelfApprovalError();
  }

  const collectionRows = await db.queryObject<FinanceCollectionRow>(
    `SELECT * FROM finance_collections
     WHERE id = $1 AND organization_id = $2 AND school_id = $3`,
    [refund.collection_id, organizationId, schoolId],
  );
  const collection = collectionRows[0];
  if (!collection) {
    throw new RefundNotCollectibleError(`Collection not found: ${refund.collection_id}`);
  }
  assertRefundableCollection(collection);

  const collectionAmount = parseAmount(collection.amount_collected);
  const alreadyRefunded = await sumRefundedForCollection(
    db,
    organizationId,
    schoolId,
    collection.id,
    refund.id,
  );
  const refundAmount = parseAmount(refund.refund_amount);
  if (alreadyRefunded + refundAmount > collectionAmount) {
    throw new RefundAmountError(
      "Refund amount exceeds remaining refundable amount for collection",
    );
  }

  return await applyProcessedRefund(
    db,
    organizationId,
    schoolId,
    refund,
    collection,
    approvedBy,
  );
}

export async function rejectRefund(
  db: TenantQueryClient,
  organizationId: string,
  schoolId: string,
  refundId: string,
): Promise<RefundListRow> {
  const refund = await getRefund(db, organizationId, schoolId, refundId);
  if (!refund) {
    throw new RefundNotFoundError(refundId);
  }
  if (refund.refund_status !== "pending") {
    throw new InvalidRefundTransitionError(
      `Cannot reject refund in status: ${refund.refund_status}`,
    );
  }

  const rejectedRows = await db.queryObject<FinanceRefundRow>(
    `UPDATE finance_refunds SET
      refund_status = 'rejected',
      updated_at = timezone('utc', now())
     WHERE id = $1 AND organization_id = $2 AND school_id = $3
       AND refund_status = 'pending'
     RETURNING id`,
    [refundId, organizationId, schoolId],
  );
  if (rejectedRows.length === 0) {
    // A concurrent approval/rejection already moved this refund out of pending;
    // never reject an already-processed refund (its money was moved) — fail closed.
    throw new InvalidRefundTransitionError(
      `Cannot reject refund in status: ${refund.refund_status} (concurrent transition)`,
    );
  }

  return (await getRefund(db, organizationId, schoolId, refundId))!;
}
