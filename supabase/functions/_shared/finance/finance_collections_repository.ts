import type { TenantQueryClient } from "../tenant_db.ts";
import type { FinanceInvoiceRow } from "./finance_invoices_repository.ts";
import type { PaginationParams, PaginationResult } from "./finance_structures_repository.ts";
import { isDateLocked } from "./finance_day_close_repository.ts";
import {
  allocateCollectionToHeads,
  reverseCollectionFromHeads,
} from "./finance_head_allocations_repository.ts";

export type CollectionStatus =
  | "draft"
  | "completed"
  | "cancelled"
  | "partially_refunded"
  | "refunded";

export interface FinanceCollectionRow {
  id: string;
  organization_id: string;
  school_id: string;
  student_id: string;
  invoice_id: string;
  student_account_id: string;
  receipt_number: string;
  collection_date: string;
  payment_method: string;
  reference_number: string | null;
  amount_collected: string;
  notes: string | null;
  collection_status: CollectionStatus;
  collected_by: string;
  // FIN-D3: cancellation trail (null until the collection is cancelled).
  cancellation_reason: string | null;
  cancelled_by: string | null;
  cancelled_at: string | null;
  // ENG-1: optimistic-lock version, auto-incremented by the bump_row_version
  // trigger (migration 20260817000000). Guarded on cancel to prevent a stale
  // client from overwriting a newer state (money lost-update).
  row_version: number;
  created_at: string;
  updated_at: string;
}

export interface FinanceReceiptRow {
  id: string;
  organization_id: string;
  school_id: string;
  collection_id: string;
  receipt_number: string;
  receipt_date: string;
  amount: string;
  generated_by: string;
  created_at: string;
}

export interface CollectionWithReceipt {
  collection: FinanceCollectionRow;
  receipt: FinanceReceiptRow;
  invoice: FinanceInvoiceRow;
}

export interface CollectionListRow extends FinanceCollectionRow {
  student_name?: string;
  admission_number?: string;
  class_label?: string;
}

export interface CreateCollectionInput {
  invoiceId: string;
  amountCollected: number;
  paymentMethod: string;
  referenceNumber?: string;
  notes?: string;
  collectionDate?: string;
  collectedBy: string;
  /**
   * RT-01: optional client-supplied idempotency key (from the `Idempotency-Key`
   * header). When present, a repeated/double-submitted request with the same key
   * replays the original collection instead of creating a second one.
   */
  idempotencyKey?: string;
}

export class InvoiceNotCollectibleError extends Error {
  constructor(message: string) {
    super(message);
    this.name = "InvoiceNotCollectibleError";
  }
}

export class CollectionAmountError extends Error {
  constructor(message: string) {
    super(message);
    this.name = "CollectionAmountError";
  }
}

export class CollectionNotFoundError extends Error {
  constructor(id: string) {
    super(`Collection not found: ${id}`);
    this.name = "CollectionNotFoundError";
  }
}

export class ReceiptNotFoundError extends Error {
  constructor(id: string) {
    super(`Receipt not found: ${id}`);
    this.name = "ReceiptNotFoundError";
  }
}

export class DuplicateReceiptError extends Error {
  constructor() {
    super("Receipt number already exists");
    this.name = "DuplicateReceiptError";
  }
}

export class InvalidCollectionTransitionError extends Error {
  constructor(message: string) {
    super(message);
    this.name = "InvalidCollectionTransitionError";
  }
}

/**
 * ENG-1: raised when a money-mutating collection write is rejected because the
 * caller's `expectedVersion` no longer matches the row's current `row_version`
 * — i.e. the collection was modified since the caller read it. Carries the
 * current server row so the client (Data Reliability Platform) can resolve the
 * conflict and re-submit with the correct version. Maps to 409 CONFLICT.
 */
export class CollectionConflictError extends Error {
  constructor(
    readonly collectionId: string,
    readonly currentRow: FinanceCollectionRow,
  ) {
    super(
      `Collection ${collectionId} was modified by another operation; refresh and retry.`,
    );
    this.name = "CollectionConflictError";
  }
}

/**
 * FIN-D1: raised when a collection (or cancellation) is dated on/before the
 * latest closed day — a back-dated money movement into a reconciled day is
 * rejected before any row is written.
 */
export class DayLockedError extends Error {
  constructor(collectionDate: string) {
    super(
      `The day ${collectionDate} is closed. Reopen it before recording or cancelling entries dated on/before it.`,
    );
    this.name = "DayLockedError";
  }
}

/** FIN-D3: raised when a cancellation is attempted without a reason. */
export class CancellationReasonRequiredError extends Error {
  constructor() {
    super("A cancellation reason is required");
    this.name = "CancellationReasonRequiredError";
  }
}

function offsetFor(page: number, pageSize: number): number {
  return Math.max(0, (page - 1) * pageSize);
}

function buildReceiptNumber(): string {
  const year = new Date().getUTCFullYear();
  const suffix = crypto.randomUUID().split("-")[0]!.toUpperCase();
  return `RCPT-${year}-${suffix}`;
}

function parseAmount(value: string | number): number {
  const num = typeof value === "number" ? value : parseFloat(value);
  return Number.isFinite(num) ? num : 0;
}

function formatNumeric(value: number): string {
  return Number.isInteger(value) ? String(value) : value.toFixed(2);
}

export function computeInvoiceStatus(
  outstanding: number,
  total: number,
): "issued" | "partially_paid" | "paid" {
  if (outstanding <= 0) return "paid";
  if (outstanding < total) return "partially_paid";
  return "issued";
}

async function loadInvoiceForCollection(
  db: TenantQueryClient,
  organizationId: string,
  schoolId: string,
  invoiceId: string,
): Promise<FinanceInvoiceRow & { student_account_id: string }> {
  // RT-01: lock the invoice row for the duration of the transaction. Without
  // this, two concurrent collections both read the same outstanding_amount,
  // both pass the "amount <= outstanding" check, and both decrement — producing
  // a double payment and a negative outstanding. FOR UPDATE OF fi serializes
  // them: the second waits, then re-reads the already-decremented outstanding
  // and is correctly rejected (or applied against the remainder).
  const rows = await db.queryObject<FinanceInvoiceRow & { student_account_id: string }>(
    `SELECT fi.*, fsa.id AS student_account_id
     FROM finance_invoices fi
     JOIN finance_student_accounts fsa
       ON fsa.student_id = fi.student_id
      AND fsa.academic_year = fi.academic_year
      AND fsa.organization_id = fi.organization_id
      AND fsa.school_id = fi.school_id
     WHERE fi.id = $1 AND fi.organization_id = $2 AND fi.school_id = $3
     FOR UPDATE OF fi`,
    [invoiceId, organizationId, schoolId],
  );
  const invoice = rows[0];
  if (!invoice) {
    throw new InvoiceNotCollectibleError(`Invoice not found: ${invoiceId}`);
  }
  if (invoice.invoice_status === "cancelled") {
    throw new InvoiceNotCollectibleError("Cannot collect against a cancelled invoice");
  }
  if (invoice.invoice_status === "draft") {
    throw new InvoiceNotCollectibleError("Cannot collect against a draft invoice");
  }
  return invoice;
}

/**
 * RT-01: rebuild the full {collection, receipt, invoice} result for an existing
 * collection — used to replay a request that carried an already-seen
 * idempotency key, so a double-submit returns the original collection rather
 * than creating a second one.
 */
async function loadCollectionWithReceipt(
  db: TenantQueryClient,
  organizationId: string,
  schoolId: string,
  collectionId: string,
): Promise<CollectionWithReceipt | null> {
  const collectionRows = await db.queryObject<FinanceCollectionRow>(
    `SELECT * FROM finance_collections
     WHERE id = $1 AND organization_id = $2 AND school_id = $3`,
    [collectionId, organizationId, schoolId],
  );
  const collection = collectionRows[0];
  if (!collection) return null;

  const receiptRows = await db.queryObject<FinanceReceiptRow>(
    `SELECT * FROM finance_receipts
     WHERE collection_id = $1 AND organization_id = $2 AND school_id = $3`,
    [collectionId, organizationId, schoolId],
  );
  const invoiceRows = await db.queryObject<FinanceInvoiceRow>(
    `SELECT * FROM finance_invoices WHERE id = $1`,
    [collection.invoice_id],
  );
  if (!receiptRows[0] || !invoiceRows[0]) return null;
  return { collection, receipt: receiptRows[0], invoice: invoiceRows[0] };
}

async function findCollectionByIdempotencyKey(
  db: TenantQueryClient,
  organizationId: string,
  idempotencyKey: string,
): Promise<string | null> {
  const rows = await db.queryObject<{ id: string }>(
    `SELECT id FROM finance_collections
     WHERE organization_id = $1 AND idempotency_key = $2
     LIMIT 1`,
    [organizationId, idempotencyKey],
  );
  return rows[0]?.id ?? null;
}

export async function createCollection(
  db: TenantQueryClient,
  organizationId: string,
  schoolId: string,
  input: CreateCollectionInput,
): Promise<CollectionWithReceipt> {
  if (!Number.isFinite(input.amountCollected) || input.amountCollected <= 0) {
    throw new CollectionAmountError("Amount collected must be greater than zero");
  }

  const invoice = await loadInvoiceForCollection(
    db,
    organizationId,
    schoolId,
    input.invoiceId,
  );

  // RT-01: replay an already-processed request (same Idempotency-Key) without
  // re-decrementing. Checked AFTER acquiring the invoice lock so concurrent
  // same-key submits serialize: the second sees the first's committed row.
  if (input.idempotencyKey) {
    const existingId = await findCollectionByIdempotencyKey(
      db,
      organizationId,
      input.idempotencyKey,
    );
    if (existingId) {
      const replayed = await loadCollectionWithReceipt(
        db,
        organizationId,
        schoolId,
        existingId,
      );
      if (replayed) return replayed;
    }
  }

  const outstanding = parseAmount(invoice.outstanding_amount);
  if (input.amountCollected > outstanding) {
    throw new CollectionAmountError(
      `Amount collected (${input.amountCollected}) exceeds invoice outstanding (${outstanding})`,
    );
  }

  const receiptNumber = buildReceiptNumber();
  const collectionDate = input.collectionDate ?? new Date().toISOString().slice(0, 10);

  // FIN-D1: reject a collection dated on/before the latest closed day. Checked
  // before any row is written (and after the invoice lock so it serializes with
  // a concurrent day-close). Additive guard — does not alter the payment math.
  if (await isDateLocked(db, organizationId, schoolId, collectionDate)) {
    throw new DayLockedError(collectionDate);
  }

  const total = parseAmount(invoice.total_amount);
  const newOutstanding = outstanding - input.amountCollected;
  const newInvoiceStatus = computeInvoiceStatus(newOutstanding, total);

  let collectionRows: FinanceCollectionRow[];
  try {
    collectionRows = await db.queryObject<FinanceCollectionRow>(
      `INSERT INTO finance_collections (
        organization_id, school_id, student_id, invoice_id, student_account_id,
        receipt_number, collection_date, payment_method, reference_number,
        amount_collected, notes, collection_status, collected_by, idempotency_key
      ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, 'completed', $12, $13)
      RETURNING *`,
      [
        organizationId,
        schoolId,
        invoice.student_id,
        invoice.id,
        invoice.student_account_id,
        receiptNumber,
        collectionDate,
        input.paymentMethod,
        input.referenceNumber ?? null,
        input.amountCollected,
        input.notes ?? null,
        input.collectedBy,
        input.idempotencyKey ?? null,
      ],
    );
  } catch (error) {
    // RT-01: the partial-unique index on (organization_id, idempotency_key) is
    // the DB backstop for a same-key race that slips past the replay check
    // above — recover by replaying the row the winner just committed.
    if (
      input.idempotencyKey &&
      String(error).includes("duplicate key") &&
      String(error).includes("idempotency")
    ) {
      const existingId = await findCollectionByIdempotencyKey(
        db,
        organizationId,
        input.idempotencyKey,
      );
      const replayed = existingId
        ? await loadCollectionWithReceipt(db, organizationId, schoolId, existingId)
        : null;
      if (replayed) return replayed;
    }
    throw error;
  }
  const collection = collectionRows[0]!;

  let receiptRows: FinanceReceiptRow[];
  try {
    receiptRows = await db.queryObject<FinanceReceiptRow>(
      `INSERT INTO finance_receipts (
        organization_id, school_id, collection_id,
        receipt_number, receipt_date, amount, generated_by
      ) VALUES ($1, $2, $3, $4, $5, $6, $7)
      RETURNING *`,
      [
        organizationId,
        schoolId,
        collection.id,
        receiptNumber,
        collectionDate,
        input.amountCollected,
        input.collectedBy,
      ],
    );
  } catch (error) {
    if (error instanceof Error && error.message.includes("duplicate key")) {
      throw new DuplicateReceiptError();
    }
    throw error;
  }

  await db.queryObject(
    `UPDATE finance_invoices SET
      outstanding_amount = $1,
      invoice_status = $2,
      updated_at = timezone('utc', now())
     WHERE id = $3 AND organization_id = $4 AND school_id = $5`,
    [
      formatNumeric(newOutstanding),
      newInvoiceStatus,
      invoice.id,
      organizationId,
      schoolId,
    ],
  );

  await db.queryObject(
    `UPDATE finance_student_accounts SET
      amount_paid = amount_paid + $1,
      outstanding_amount = outstanding_amount - $1,
      updated_at = timezone('utc', now())
     WHERE id = $2 AND organization_id = $3 AND school_id = $4`,
    [
      input.amountCollected,
      invoice.student_account_id,
      organizationId,
      schoolId,
    ],
  );

  // FIN-D2: AFTER the (unchanged) outstanding reduction, allocate the collected
  // amount across the invoice's fee heads (tuition first, then sort_order). This
  // is a derived ledger — it does not read or write outstanding. Keeps the
  // invariant SUM(head_paid) == amount_paid.
  await allocateCollectionToHeads(
    db,
    organizationId,
    schoolId,
    invoice.id,
    input.amountCollected,
  );

  const updatedInvoiceRows = await db.queryObject<FinanceInvoiceRow>(
    `SELECT * FROM finance_invoices WHERE id = $1`,
    [invoice.id],
  );

  return {
    collection,
    receipt: receiptRows[0]!,
    invoice: updatedInvoiceRows[0]!,
  };
}

export async function listCollections(
  db: TenantQueryClient,
  organizationId: string,
  schoolId: string,
  pagination: PaginationParams,
): Promise<PaginationResult<CollectionListRow>> {
  const limit = Math.min(Math.max(pagination.pageSize, 1), 100);
  const offset = offsetFor(pagination.page, limit);

  const total = await db.queryCount(
    `SELECT count(*)::text AS count FROM finance_collections
     WHERE organization_id = $1 AND school_id = $2`,
    [organizationId, schoolId],
  );

  const items = await db.queryObject<CollectionListRow>(
    `SELECT fc.*,
       COALESCE(s.display_name, afh.student_name) AS student_name,
       afh.admission_number,
       afh.class_label
     FROM finance_collections fc
     LEFT JOIN students s
       ON s.id = fc.student_id AND s.organization_id = fc.organization_id AND s.school_id = fc.school_id
     LEFT JOIN LATERAL (
       SELECT student_name, admission_number, class_label
       FROM admissions_fee_handoffs
       WHERE student_id = fc.student_id
         AND organization_id = fc.organization_id
         AND school_id = fc.school_id
       ORDER BY created_at DESC
       LIMIT 1
     ) afh ON true
     WHERE fc.organization_id = $1 AND fc.school_id = $2
     ORDER BY fc.collection_date DESC, fc.created_at DESC
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

export async function getCollection(
  db: TenantQueryClient,
  organizationId: string,
  schoolId: string,
  collectionId: string,
): Promise<CollectionListRow | null> {
  const rows = await db.queryObject<CollectionListRow>(
    `SELECT fc.*,
       COALESCE(s.display_name, afh.student_name) AS student_name,
       afh.admission_number,
       afh.class_label
     FROM finance_collections fc
     LEFT JOIN students s
       ON s.id = fc.student_id AND s.organization_id = fc.organization_id AND s.school_id = fc.school_id
     LEFT JOIN LATERAL (
       SELECT student_name, admission_number, class_label
       FROM admissions_fee_handoffs
       WHERE student_id = fc.student_id
         AND organization_id = fc.organization_id
         AND school_id = fc.school_id
       ORDER BY created_at DESC
       LIMIT 1
     ) afh ON true
     WHERE fc.id = $1 AND fc.organization_id = $2 AND fc.school_id = $3`,
    [collectionId, organizationId, schoolId],
  );
  return rows[0] ?? null;
}

// FIN-D3 — cancelled register row (joins actor name + student name).
export interface CancelledCollectionRow extends CollectionListRow {
  cancelled_by_name?: string;
}

/**
 * FIN-D3: the cancelled register — every cancelled collection with student name,
 * receipt, amount, date, reason, the user who cancelled it (name) and when.
 * Ordered by cancellation time (most recent first).
 */
export async function listCancelledCollections(
  db: TenantQueryClient,
  organizationId: string,
  schoolId: string,
): Promise<CancelledCollectionRow[]> {
  return await db.queryObject<CancelledCollectionRow>(
    `SELECT fc.*,
       COALESCE(s.display_name, afh.student_name) AS student_name,
       afh.admission_number,
       afh.class_label,
       cu.display_name AS cancelled_by_name
     FROM finance_collections fc
     LEFT JOIN students s
       ON s.id = fc.student_id AND s.organization_id = fc.organization_id AND s.school_id = fc.school_id
     LEFT JOIN users cu ON cu.id = fc.cancelled_by
     LEFT JOIN LATERAL (
       SELECT student_name, admission_number, class_label
       FROM admissions_fee_handoffs
       WHERE student_id = fc.student_id
         AND organization_id = fc.organization_id
         AND school_id = fc.school_id
       ORDER BY created_at DESC
       LIMIT 1
     ) afh ON true
     WHERE fc.organization_id = $1 AND fc.school_id = $2
       AND fc.collection_status = 'cancelled'
     ORDER BY fc.cancelled_at DESC NULLS LAST, fc.updated_at DESC`,
    [organizationId, schoolId],
  );
}

export async function getReceipt(
  db: TenantQueryClient,
  organizationId: string,
  schoolId: string,
  receiptId: string,
): Promise<{ receipt: FinanceReceiptRow; collection: FinanceCollectionRow } | null> {
  const receiptRows = await db.queryObject<FinanceReceiptRow>(
    `SELECT * FROM finance_receipts
     WHERE id = $1 AND organization_id = $2 AND school_id = $3`,
    [receiptId, organizationId, schoolId],
  );
  const receipt = receiptRows[0];
  if (!receipt) return null;

  const collectionRows = await db.queryObject<FinanceCollectionRow>(
    `SELECT * FROM finance_collections
     WHERE id = $1 AND organization_id = $2 AND school_id = $3`,
    [receipt.collection_id, organizationId, schoolId],
  );
  const collection = collectionRows[0];
  if (!collection) return null;

  return { receipt, collection };
}

export interface CancelCollectionInput {
  /** FIN-D3: mandatory, non-empty cancellation reason. */
  reason: string;
  /** FIN-D3: the acting user (claims.sub). */
  cancelledBy: string;
  /**
   * ENG-1: optional optimistic-lock version. When provided, the cancel is
   * rejected (409 CONFLICT) if the collection's current `row_version` differs —
   * preventing a stale/queued client from reversing money against an outdated
   * view of the record. When omitted, behaviour is unchanged (back-compatible).
   */
  expectedVersion?: number | null;
}

export async function cancelCollection(
  db: TenantQueryClient,
  organizationId: string,
  schoolId: string,
  collectionId: string,
  input: CancelCollectionInput,
): Promise<CollectionWithReceipt> {
  const reason = input.reason?.trim() ?? "";
  if (reason === "") {
    throw new CancellationReasonRequiredError();
  }

  const collection = await getCollection(db, organizationId, schoolId, collectionId);
  if (!collection) {
    throw new CollectionNotFoundError(collectionId);
  }
  if (collection.collection_status === "cancelled") {
    throw new InvalidCollectionTransitionError("Collection is already cancelled");
  }

  // ENG-1: optimistic-lock guard. Reject a stale cancel (the collection changed
  // since the caller read it) BEFORE any money is reversed, mirroring the
  // exam-marks conflict guard. The atomic `row_version` predicate on the UPDATE
  // below is the belt-and-suspenders against a read→write race inside the txn.
  const expectedVersion = input.expectedVersion;
  if (
    expectedVersion != null &&
    Number(collection.row_version) !== Number(expectedVersion)
  ) {
    throw new CollectionConflictError(collectionId, collection);
  }

  // FIN-D1: a collection whose date sits on/before the latest closed day cannot
  // be cancelled — the money movement it reverses belongs to a reconciled day.
  if (await isDateLocked(db, organizationId, schoolId, collection.collection_date)) {
    throw new DayLockedError(collection.collection_date);
  }

  const receiptRows = await db.queryObject<FinanceReceiptRow>(
    `SELECT * FROM finance_receipts
     WHERE collection_id = $1 AND organization_id = $2 AND school_id = $3`,
    [collectionId, organizationId, schoolId],
  );
  const receipt = receiptRows[0];
  if (!receipt) {
    throw new ReceiptNotFoundError(collectionId);
  }

  if (collection.collection_status === "completed") {
    const amount = parseAmount(collection.amount_collected);
    const invoiceRows = await db.queryObject<FinanceInvoiceRow>(
      `SELECT * FROM finance_invoices WHERE id = $1 AND organization_id = $2 AND school_id = $3`,
      [collection.invoice_id, organizationId, schoolId],
    );
    const invoice = invoiceRows[0]!;
    const total = parseAmount(invoice.total_amount);
    const newOutstanding = parseAmount(invoice.outstanding_amount) + amount;
    const newStatus = computeInvoiceStatus(newOutstanding, total);

    await db.queryObject(
      `UPDATE finance_invoices SET
        outstanding_amount = $1,
        invoice_status = $2,
        updated_at = timezone('utc', now())
       WHERE id = $3 AND organization_id = $4 AND school_id = $5`,
      [formatNumeric(newOutstanding), newStatus, invoice.id, organizationId, schoolId],
    );

    await db.queryObject(
      `UPDATE finance_student_accounts SET
        amount_paid = amount_paid - $1,
        outstanding_amount = outstanding_amount + $1,
        updated_at = timezone('utc', now())
       WHERE id = $2 AND organization_id = $3 AND school_id = $4`,
      [amount, collection.student_account_id, organizationId, schoolId],
    );

    // FIN-D2: reverse the head allocation in REVERSE priority order, exactly
    // undoing the amount this collection had allocated. Runs AFTER the unchanged
    // outstanding reversal; preserves SUM(head_paid) == amount_paid.
    await reverseCollectionFromHeads(
      db,
      organizationId,
      schoolId,
      collection.invoice_id,
      amount,
    );
  }

  const updatedCollectionRows = await db.queryObject<FinanceCollectionRow>(
    `UPDATE finance_collections SET
      collection_status = 'cancelled',
      cancellation_reason = $4,
      cancelled_by = $5,
      cancelled_at = timezone('utc', now()),
      updated_at = timezone('utc', now())
     WHERE id = $1 AND organization_id = $2 AND school_id = $3
       AND collection_status <> 'cancelled'
       AND ($6::int IS NULL OR row_version = $6)
     RETURNING *`,
    [collectionId, organizationId, schoolId, reason, input.cancelledBy, expectedVersion ?? null],
  );
  if (updatedCollectionRows.length === 0) {
    // ENG-1: the version changed between our read and this write (a concurrent
    // modification committed after we read), or the row vanished. The enclosing
    // transaction rolls back the reversal above; surface the current row.
    const current = await getCollection(db, organizationId, schoolId, collectionId);
    throw new CollectionConflictError(collectionId, current ?? collection);
  }

  const updatedInvoiceRows = await db.queryObject<FinanceInvoiceRow>(
    `SELECT * FROM finance_invoices WHERE id = $1`,
    [collection.invoice_id],
  );

  return {
    collection: updatedCollectionRows[0]!,
    receipt,
    invoice: updatedInvoiceRows[0]!,
  };
}

export async function listCollectionsForAccount(
  db: TenantQueryClient,
  organizationId: string,
  schoolId: string,
  studentAccountId: string,
): Promise<FinanceCollectionRow[]> {
  return await listAllCollectionsForAccount(db, organizationId, schoolId, studentAccountId, "completed");
}

export async function listAllCollectionsForAccount(
  db: TenantQueryClient,
  organizationId: string,
  schoolId: string,
  studentAccountId: string,
  statusFilter?: CollectionStatus,
): Promise<FinanceCollectionRow[]> {
  if (statusFilter) {
    return await db.queryObject<FinanceCollectionRow>(
      `SELECT * FROM finance_collections
       WHERE student_account_id = $1 AND organization_id = $2 AND school_id = $3
         AND collection_status = $4
       ORDER BY collection_date DESC, created_at DESC`,
      [studentAccountId, organizationId, schoolId, statusFilter],
    );
  }
  return await db.queryObject<FinanceCollectionRow>(
    `SELECT * FROM finance_collections
     WHERE student_account_id = $1 AND organization_id = $2 AND school_id = $3
     ORDER BY collection_date DESC, created_at DESC`,
    [studentAccountId, organizationId, schoolId],
  );
}

export interface StudentAccountSnapshot {
  id: string;
  total_fee: string;
  amount_paid: string;
  outstanding_amount: string;
  status: string;
}

export async function getStudentAccountById(
  db: TenantQueryClient,
  organizationId: string,
  schoolId: string,
  studentAccountId: string,
): Promise<StudentAccountSnapshot | null> {
  const rows = await db.queryObject<StudentAccountSnapshot>(
    `SELECT id, total_fee, amount_paid, outstanding_amount, status
     FROM finance_student_accounts
     WHERE id = $1 AND organization_id = $2 AND school_id = $3`,
    [studentAccountId, organizationId, schoolId],
  );
  return rows[0] ?? null;
}

export interface DailySummaryData {
  dateLabel: string;
  todayCollections: number;
  todayCollectionCount: number;
  cashAmount: number;
  upiAmount: number;
  draftCollectionsToday: number;
  pendingInvoices: number;
  paidInvoices: number;
  partiallyPaidInvoices: number;
  outstandingAmount: number;
}

export async function getDailySummary(
  db: TenantQueryClient,
  organizationId: string,
  schoolId: string,
): Promise<DailySummaryData> {
  const todayRows = await db.queryObject<{
    total: string;
    count: string;
    cash: string;
    upi: string;
    drafts: string;
  }>(
    `SELECT
       COALESCE(SUM(amount_collected) FILTER (WHERE collection_status = 'completed'), 0)::text AS total,
       COUNT(*) FILTER (WHERE collection_status = 'completed')::text AS count,
       COALESCE(SUM(amount_collected) FILTER (
         WHERE collection_status = 'completed' AND LOWER(payment_method) = 'cash'
       ), 0)::text AS cash,
       COALESCE(SUM(amount_collected) FILTER (
         WHERE collection_status = 'completed' AND LOWER(payment_method) = 'upi'
       ), 0)::text AS upi,
       COUNT(*) FILTER (WHERE collection_status = 'draft')::text AS drafts
     FROM finance_collections
     WHERE organization_id = $1 AND school_id = $2
       AND collection_date = CURRENT_DATE`,
    [organizationId, schoolId],
  );

  const invoiceRows = await db.queryObject<{
    pending: string;
    paid: string;
    partial: string;
    outstanding: string;
  }>(
    `SELECT
       COUNT(*) FILTER (WHERE invoice_status = 'issued')::text AS pending,
       COUNT(*) FILTER (WHERE invoice_status = 'paid')::text AS paid,
       COUNT(*) FILTER (WHERE invoice_status = 'partially_paid')::text AS partial,
       COALESCE(SUM(outstanding_amount) FILTER (
         WHERE invoice_status IN ('issued', 'partially_paid')
       ), 0)::text AS outstanding
     FROM finance_invoices
     WHERE organization_id = $1 AND school_id = $2
       AND invoice_status NOT IN ('cancelled', 'draft')`,
    [organizationId, schoolId],
  );

  const today = todayRows[0]!;
  const inv = invoiceRows[0]!;
  const now = new Date();
  const dateLabel = now.toISOString().slice(0, 10);

  return {
    dateLabel,
    todayCollections: parseFloat(today.total),
    todayCollectionCount: parseInt(today.count, 10),
    cashAmount: parseFloat(today.cash),
    upiAmount: parseFloat(today.upi),
    draftCollectionsToday: parseInt(today.drafts, 10),
    pendingInvoices: parseInt(inv.pending, 10),
    paidInvoices: parseInt(inv.paid, 10),
    partiallyPaidInvoices: parseInt(inv.partial, 10),
    outstandingAmount: parseFloat(inv.outstanding),
  };
}

export async function listReceiptsForAccount(
  db: TenantQueryClient,
  organizationId: string,
  schoolId: string,
  studentAccountId: string,
): Promise<FinanceReceiptRow[]> {
  return await db.queryObject<FinanceReceiptRow>(
    `SELECT fr.* FROM finance_receipts fr
     JOIN finance_collections fc ON fc.id = fr.collection_id
     WHERE fc.student_account_id = $1
       AND fc.organization_id = $2 AND fc.school_id = $3
     ORDER BY fr.receipt_date DESC, fr.created_at DESC`,
    [studentAccountId, organizationId, schoolId],
  );
}
