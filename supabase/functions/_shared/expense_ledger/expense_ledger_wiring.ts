// W4 — LIVE wiring of the canonical Expense Ledger at each source's commit point.
//
// A ledger entry is a REPORTING PROJECTION of a money move, never the source of
// truth for it. Every source (transport / payroll / inventory) already persists its
// expense INSIDE the caller's tenant transaction (withTenantContext → BEGIN..COMMIT).
// We post the projection ADDITIVELY, on the SAME `db`, right after the source write,
// with two guarantees:
//
//   1. FAILURE-ISOLATED. A raw failure of the ledger INSERT (e.g. the ledger table
//      is absent because its migration has not been applied yet) would otherwise
//      poison the OPEN transaction, so the enclosing COMMIT fails and the SOURCE
//      write is rolled back — the exact disaster the "ledger must never break the
//      money move" rule forbids. A plain try/catch cannot prevent this: catching the
//      JS error does NOT un-poison the Postgres transaction. So we fence the post in
//      a SAVEPOINT — a failure rolls back ONLY the projection (leaving the source
//      write intact for COMMIT) — and swallow+log the error so nothing can propagate
//      out of the source handler. If the savepoint itself cannot be established, the
//      post is skipped rather than put the source transaction at any risk.
//
//   2. IDEMPOTENT / NO DOUBLE-COUNT. postExpense is INSERT ... ON CONFLICT DO NOTHING
//      on (organization_id, school_id, source_module, source_ref), so each source
//      event posts EXACTLY ONE entry — a retry, a replay, or a nightly backfill after
//      a swallowed failure re-posts nothing.
//
// These helpers are the ONLY surface the source handlers call: the pure row→entry
// mapping lives in expense_ledger_adapters.ts and the idempotent write in
// expense_ledger_repository.ts. Nothing here mutates a source module.

import type { TenantQueryClient } from "../tenant_db.ts";
import type { TransportExpenseRow } from "../transport/transport_expenses_repository.ts";
import type { PayrollFinancePosting } from "../hr/hr_finance_posting_repository.ts";
import type { PurchaseOrderRow } from "../inventory_finance/inventory_finance_repository.ts";
import {
  postInventoryPurchaseExpense,
  postPayrollExpense,
  postTransportExpense,
} from "./expense_ledger_adapters.ts";

/** The savepoint name that fences a single ledger projection post. */
export const LEDGER_WIRE_SAVEPOINT = "expense_ledger_wire";

/**
 * Result of a fenced ledger post.
 *  - `posted`          — a NEW ledger row was written (false on an idempotent replay).
 *  - `entryId`         — its id, or null when nothing new was written.
 *  - `isolatedFailure` — the post errored but the savepoint contained it; the SOURCE
 *                        write is guaranteed unaffected.
 */
export interface LedgerWireResult {
  posted: boolean;
  entryId: string | null;
  isolatedFailure: boolean;
}

/**
 * Run `post` inside a SAVEPOINT on the source write's own transaction. On success the
 * savepoint is released (the entry persists atomically with the source write). On ANY
 * error the savepoint is rolled back — undoing only the projection — and the error is
 * logged and swallowed so the source write commits untouched. If the savepoint cannot
 * even be opened, the post is skipped entirely (the source transaction is never risked).
 */
async function fencedPost(
  db: TenantQueryClient,
  label: string,
  post: () => Promise<{ posted: boolean; entryId: string | null }>,
): Promise<LedgerWireResult> {
  try {
    await db.queryObject(`SAVEPOINT ${LEDGER_WIRE_SAVEPOINT}`);
  } catch (error) {
    console.error(
      `[expense_ledger] ${label}: could not open savepoint; projection skipped (source write unaffected):`,
      error,
    );
    return { posted: false, entryId: null, isolatedFailure: true };
  }

  try {
    const res = await post();
    await db.queryObject(`RELEASE SAVEPOINT ${LEDGER_WIRE_SAVEPOINT}`);
    return { posted: res.posted, entryId: res.entryId, isolatedFailure: false };
  } catch (error) {
    try {
      await db.queryObject(`ROLLBACK TO SAVEPOINT ${LEDGER_WIRE_SAVEPOINT}`);
      await db.queryObject(`RELEASE SAVEPOINT ${LEDGER_WIRE_SAVEPOINT}`);
    } catch (cleanupError) {
      console.error(`[expense_ledger] ${label}: savepoint cleanup failed:`, cleanupError);
    }
    console.error(
      `[expense_ledger] ${label}: projection post failed and was isolated (source write unaffected):`,
      error,
    );
    return { posted: false, entryId: null, isolatedFailure: true };
  }
}

/**
 * Transport: post a just-recorded `transport_expenses` row to the ledger. A voided
 * row maps to null and posts nothing (handled by the adapter). Idempotent on the
 * row id — a re-record/replay of the same expense posts exactly one entry.
 */
export function wireTransportExpenseToLedger(
  db: TenantQueryClient,
  row: TransportExpenseRow,
): Promise<LedgerWireResult> {
  return fencedPost(db, `transport:${row.id}`, () => postTransportExpense(db, row));
}

/**
 * Payroll: post a processed run's finance posting to the ledger. `incurredOn` is the
 * run's disbursement date. Idempotent on the payroll run id — a re-process (already
 * blocked upstream by the 409 guard) could never double-count anyway.
 */
export function wirePayrollExpenseToLedger(
  db: TenantQueryClient,
  organizationId: string,
  schoolId: string,
  posting: PayrollFinancePosting,
  incurredOn: string,
): Promise<LedgerWireResult> {
  return fencedPost(
    db,
    `payroll:${posting.payrollRunId}`,
    () => postPayrollExpense(db, organizationId, schoolId, posting, incurredOn),
  );
}

/**
 * Inventory: post an approved purchase order to the ledger, ADDITIVELY alongside the
 * PO's AP-commitment / finance posting (a separate accounts-payable sink — no double
 * count in the expense ledger). A draft/rejected PO maps to null and posts nothing.
 * Idempotent on the PO id — one procurement expense entry per approval.
 */
export function wireInventoryPurchaseToLedger(
  db: TenantQueryClient,
  organizationId: string,
  schoolId: string,
  po: PurchaseOrderRow,
  incurredOn?: string,
): Promise<LedgerWireResult> {
  return fencedPost(
    db,
    `inventory:${po.id}`,
    () => postInventoryPurchaseExpense(db, organizationId, schoolId, po, incurredOn),
  );
}
