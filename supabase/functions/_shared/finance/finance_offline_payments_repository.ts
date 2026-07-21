import type { TenantQueryClient } from "../tenant_db.ts";
// PRA-P1-09 (S1): the register now posts a collection on successful
// reconciliation (Option 1) — it is the single cheque/DD/PDC entry path.
import { createCollection } from "./finance_collections_repository.ts";

// FIN-R7 (amended PRA-P1-09, S1 — owner-approved Option 1): this register is the
// SINGLE entry path for cheque/DD/PDC (post-dated cheque) — direct instrument
// entry through createCollection is rejected. An instrument is recorded here as
// 'pending_reconciliation' with NO money movement; the money is posted to
// finance_collections ONLY on successful reconciliation (clearance), at which
// point revenue is recognised. Because a bounce can only happen from the
// pending (pre-clearance) state, a bounce reverses nothing — nothing was posted.
// Finance remains the sole payment engine: the posted collection is a normal
// finance_collections row created via the standard collection path.
export type OfflinePaymentMethod = "cash" | "cheque" | "dd" | "pdc";
export type OfflinePaymentStatus =
  | "pending_reconciliation"
  | "reconciled"
  | "bounced";

const METHODS: readonly OfflinePaymentMethod[] = ["cash", "cheque", "dd", "pdc"];

export interface FinanceOfflinePaymentRow {
  id: string;
  organization_id: string;
  school_id: string;
  invoice_id: string | null;
  student_name: string;
  amount: string;
  payment_method: OfflinePaymentMethod;
  reference_number: string;
  instrument_date: string | null;
  bank_name: string | null;
  recorded_at: string;
  status: OfflinePaymentStatus;
  collection_id: string | null;
  reconciled_at: string | null;
  reconciled_by: string | null;
  bounced_at: string | null;
  bounced_reason: string | null;
  bounced_by: string | null;
  notes: string | null;
  recorded_by: string | null;
  created_at: string;
  updated_at: string;
}

export interface CreateOfflinePaymentInput {
  invoiceId?: string;
  studentName: string;
  amount: number;
  method: OfflinePaymentMethod;
  referenceNumber: string;
  instrumentDate?: string;
  bankName?: string;
  recordedAt?: string;
  recordedBy: string;
}

export interface ReconcileOfflinePaymentInput {
  reconciledAt?: string;
  notes?: string;
  reconciledBy: string;
}

export interface BounceOfflinePaymentInput {
  bouncedAt?: string;
  reason?: string;
  bouncedBy: string;
}

export class OfflinePaymentNotFoundError extends Error {
  constructor(id: string) {
    super(`Offline payment not found: ${id}`);
    this.name = "OfflinePaymentNotFoundError";
  }
}

/** A reconciled (cleared) instrument cannot be bounced. */
export class OfflinePaymentReconciledError extends Error {
  constructor(id: string) {
    super(`Offline payment already reconciled, cannot bounce: ${id}`);
    this.name = "OfflinePaymentReconciledError";
  }
}

/** A bounced (dishonoured) instrument cannot be reconciled. */
export class OfflinePaymentBouncedError extends Error {
  constructor(id: string) {
    super(`Offline payment already bounced, cannot reconcile: ${id}`);
    this.name = "OfflinePaymentBouncedError";
  }
}

/**
 * PRA-P1-09 (S1): raised when an instrument with no linked invoice is reconciled.
 * Reconciliation posts a real collection against the invoice, so an instrument
 * recorded without an invoice cannot be cleared into the ledger. Maps to 422.
 */
export class OfflinePaymentNotInvoicedError extends Error {
  constructor(id: string) {
    super(
      `Offline instrument ${id} has no linked invoice; it cannot be reconciled into a collection.`,
    );
    this.name = "OfflinePaymentNotInvoicedError";
  }
}

/**
 * ICA-A2 (P0): raised when the terminal reconcile UPDATE — the atomic
 * money-integrity guard `AND status = 'pending_reconciliation'` — matches 0 rows,
 * i.e. the instrument left the pending state after our locked read passed its
 * checks. Under the row lock this is a "should never happen" invariant violation
 * (the FOR UPDATE lock serializes concurrent reconciles, so the loser returns the
 * idempotent no-op before it ever posts a collection); throwing here FAILS CLOSED
 * — the enclosing transaction rolls back the collection just posted, so an
 * instrument can never be double-credited. Fail-closed 500 (rollback) by design.
 */
export class OfflinePaymentStateError extends Error {
  constructor(id: string) {
    super(
      `Offline instrument ${id} was no longer pending_reconciliation at the terminal write; reconcile rolled back to prevent a double credit.`,
    );
    this.name = "OfflinePaymentStateError";
  }
}

export function isOfflinePaymentMethod(value: string): value is OfflinePaymentMethod {
  return (METHODS as readonly string[]).includes(value);
}

function formatAmount(value: number | string): string {
  const num = typeof value === "string" ? parseFloat(value) : value;
  if (!Number.isFinite(num)) return "0";
  return Number.isInteger(num) ? String(num) : num.toFixed(2);
}

/** Map a DB row to the camelCase API shape expected by the Flutter mapper. */
export function offlinePaymentToApi(row: FinanceOfflinePaymentRow): Record<string, unknown> {
  return {
    id: row.id,
    invoiceId: row.invoice_id ?? "",
    studentName: row.student_name,
    amount: formatAmount(row.amount),
    method: row.payment_method,
    referenceNumber: row.reference_number,
    instrumentDate: row.instrument_date,
    bankName: row.bank_name,
    recordedAt: row.recorded_at,
    status: row.status,
    collectionId: row.collection_id,
    bouncedAt: row.bounced_at,
    bouncedReason: row.bounced_reason,
  };
}

export async function createOfflinePayment(
  db: TenantQueryClient,
  organizationId: string,
  schoolId: string,
  input: CreateOfflinePaymentInput,
): Promise<FinanceOfflinePaymentRow> {
  const rows = await db.queryObject<FinanceOfflinePaymentRow>(
    `INSERT INTO finance_offline_payments (
      organization_id, school_id, invoice_id, student_name, amount,
      payment_method, reference_number, instrument_date, bank_name,
      recorded_at, status, recorded_by
    ) VALUES (
      $1, $2, $3, $4, $5, $6, $7, $8::date, $9,
      COALESCE($10::timestamptz, timezone('utc', now())),
      'pending_reconciliation', $11
    )
    RETURNING *`,
    [
      organizationId,
      schoolId,
      input.invoiceId ?? null,
      input.studentName,
      input.amount,
      input.method,
      input.referenceNumber,
      input.instrumentDate ?? null,
      input.bankName ?? null,
      input.recordedAt ?? null,
      input.recordedBy,
    ],
  );
  return rows[0]!;
}

export async function listOfflinePayments(
  db: TenantQueryClient,
  organizationId: string,
  schoolId: string,
  pagination: { page: number; pageSize: number },
): Promise<{
  items: FinanceOfflinePaymentRow[];
  total: number;
  page: number;
  pageSize: number;
  hasMore: boolean;
}> {
  const limit = Math.min(Math.max(pagination.pageSize, 1), 100);
  const offset = (Math.max(pagination.page, 1) - 1) * limit;

  const total = await db.queryCount(
    `SELECT count(*)::text AS count FROM finance_offline_payments
     WHERE organization_id = $1 AND school_id = $2`,
    [organizationId, schoolId],
  );

  const items = await db.queryObject<FinanceOfflinePaymentRow>(
    `SELECT * FROM finance_offline_payments
     WHERE organization_id = $1 AND school_id = $2
     ORDER BY recorded_at DESC, created_at DESC
     LIMIT $3 OFFSET $4`,
    [organizationId, schoolId, limit, offset],
  );

  return {
    items,
    total,
    page: Math.max(pagination.page, 1),
    pageSize: limit,
    hasMore: offset + items.length < total,
  };
}

export async function getOfflinePayment(
  db: TenantQueryClient,
  organizationId: string,
  schoolId: string,
  id: string,
  options: { forUpdate?: boolean } = {},
): Promise<FinanceOfflinePaymentRow | null> {
  // ICA-A2 (P0): `forUpdate` takes a row-level write lock so the reconcile path
  // can serialize concurrent reconciles of the SAME instrument. Because reconcile
  // runs inside withTenantContext (one BEGIN…COMMIT on one connection), the loser
  // blocks here until the winner commits, then re-reads the now-'reconciled'
  // status and returns the idempotent no-op BEFORE posting a second collection.
  const lockClause = options.forUpdate ? " FOR UPDATE" : "";
  const rows = await db.queryObject<FinanceOfflinePaymentRow>(
    `SELECT * FROM finance_offline_payments
     WHERE id = $1 AND organization_id = $2 AND school_id = $3${lockClause}`,
    [id, organizationId, schoolId],
  );
  return rows[0] ?? null;
}

export async function reconcileOfflinePayment(
  db: TenantQueryClient,
  organizationId: string,
  schoolId: string,
  id: string,
  input: ReconcileOfflinePaymentInput,
): Promise<FinanceOfflinePaymentRow> {
  // ICA-A2 (P0): lock the instrument row BEFORE the reconciled-check. Without the
  // lock two concurrent reconciles both read 'pending_reconciliation', both pass
  // the short-circuit below, both post a collection → a double credit. FOR UPDATE
  // serializes them: the loser blocks here, then re-reads 'reconciled' at the
  // short-circuit and returns the no-op. Lock order is instrument row first, then
  // the invoice row inside createCollection — a single consistent order, so
  // deadlock-free.
  const existing = await getOfflinePayment(db, organizationId, schoolId, id, {
    forUpdate: true,
  });
  if (!existing) {
    throw new OfflinePaymentNotFoundError(id);
  }
  // A dishonoured instrument is a terminal state — it cannot be reconciled.
  if (existing.status === "bounced") {
    throw new OfflinePaymentBouncedError(id);
  }
  // Idempotent: an already-reconciled instrument has already posted its
  // collection; re-reconciling is a no-op that must not post a second one.
  if (existing.status === "reconciled") {
    return existing;
  }

  // PRA-P1-09 (S1, Option 1): a cleared instrument posts its collection NOW. This
  // is the SINGLE point where a cheque/DD/PDC becomes booked revenue — money is
  // recognised only on clearance, so a pre-clearance bounce reverses nothing
  // (nothing was posted). `allowInstrument` lets this bypass the direct-entry
  // block in createCollection. Requires an invoice to post against.
  let collectionId = existing.collection_id;
  if (!collectionId) {
    if (!existing.invoice_id) {
      throw new OfflinePaymentNotInvoicedError(id);
    }
    const collectionDate = input.reconciledAt
      ? String(input.reconciledAt).slice(0, 10)
      : undefined;
    const posted = await createCollection(db, organizationId, schoolId, {
      invoiceId: existing.invoice_id,
      amountCollected: Number(existing.amount),
      paymentMethod: existing.payment_method,
      referenceNumber: existing.reference_number ?? undefined,
      notes:
        `Cleared ${existing.payment_method} reconciled from the Offline Instrument Register`,
      collectedBy: input.reconciledBy,
      collectionDate,
      allowInstrument: true,
      // ICA-A2 (P0): tie the posted collection to this instrument. The DB unique
      // index finance_collections_offline_payment_uq (migration 20260920000070)
      // then makes "≤ 1 collection per instrument" a hard, un-bypassable invariant.
      offlinePaymentId: existing.id,
      // ICA-A2 (P0): derive the idempotency key from the instrument id so any
      // residual same-instrument collision rides the existing
      // finance_collections_idempotency_key_uq index and REPLAYS the winner's
      // collection gracefully instead of raising a raw unique-violation 500.
      idempotencyKey: `offline-reconcile:${existing.id}`,
    });
    collectionId = posted.collection.id;
  }

  // ICA-A2 (P0): the terminal write is the ATOMIC money-integrity guard (project
  // race pattern: `AND status = '<pre>'` + throw-on-0-rows). The predicate is now
  // `AND status = 'pending_reconciliation'` (was the too-loose `<> 'bounced'`): it
  // flips exactly one still-pending instrument and matches 0 rows otherwise. This
  // is belt-and-suspenders behind the FOR UPDATE lock above — mirrors
  // bounceOfflinePayment's guarded terminal write.
  const rows = await db.queryObject<FinanceOfflinePaymentRow>(
    `UPDATE finance_offline_payments
     SET status = 'reconciled',
         reconciled_at = COALESCE($4::timestamptz, timezone('utc', now())),
         reconciled_by = $5,
         notes = COALESCE($6, notes),
         collection_id = COALESCE($7, collection_id),
         updated_at = timezone('utc', now())
     WHERE id = $1 AND organization_id = $2 AND school_id = $3
       AND status = 'pending_reconciliation'
     RETURNING *`,
    [
      id,
      organizationId,
      schoolId,
      input.reconciledAt ?? null,
      input.reconciledBy,
      input.notes ?? null,
      collectionId,
    ],
  );
  // 0 rows means the instrument left 'pending_reconciliation' between our locked
  // read and this write — impossible while we hold the row lock, so it signals a
  // broken invariant. THROW so the enclosing transaction rolls back the collection
  // we just posted: an instrument is never double-credited (fail-closed).
  if (rows.length === 0) {
    throw new OfflinePaymentStateError(id);
  }
  return rows[0]!;
}

/**
 * FIN-R7 (amended PRA-P1-09, S1): mark a pending instrument (cheque / DD / PDC)
 * as bounced/dishonoured. Terminal, match-once, money-safe: a bounce is only
 * reachable from 'pending_reconciliation' — BEFORE the money is posted (a
 * collection is posted only on reconciliation) — so a bounce reverses NO money;
 * it just records the failure. A reconciled (cleared) instrument cannot be
 * bounced; bouncing an already-bounced row is an idempotent
 * no-op. Any refund of money already collected against the instrument stays a
 * separate manual Finance action (Finance = sole payment engine).
 */
export async function bounceOfflinePayment(
  db: TenantQueryClient,
  organizationId: string,
  schoolId: string,
  id: string,
  input: BounceOfflinePaymentInput,
): Promise<FinanceOfflinePaymentRow> {
  const existing = await getOfflinePayment(db, organizationId, schoolId, id);
  if (!existing) {
    throw new OfflinePaymentNotFoundError(id);
  }
  if (existing.status === "reconciled") {
    throw new OfflinePaymentReconciledError(id);
  }

  const rows = await db.queryObject<FinanceOfflinePaymentRow>(
    `UPDATE finance_offline_payments
     SET status = 'bounced',
         bounced_at = COALESCE($4::timestamptz, timezone('utc', now())),
         bounced_by = $5,
         bounced_reason = COALESCE($6, bounced_reason),
         updated_at = timezone('utc', now())
     WHERE id = $1 AND organization_id = $2 AND school_id = $3
       AND status IN ('pending_reconciliation', 'bounced')
     RETURNING *`,
    [
      id,
      organizationId,
      schoolId,
      input.bouncedAt ?? null,
      input.bouncedBy,
      input.reason ?? null,
    ],
  );
  // Empty only on a concurrent reconcile between the read and the guarded write.
  if (rows.length === 0) {
    throw new OfflinePaymentReconciledError(id);
  }
  return rows[0]!;
}
