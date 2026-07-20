// W4 (Owner decision #4, FINAL) — canonical Expense Ledger repository.
//
// The single source-of-truth writer + aggregation reads over the append-only
// `expense_ledger_entries` table (migration 20260900000026). Source modules do
// NOT write here directly — they hand their already-recorded expense rows to the
// per-source adapters in `expense_ledger_adapters.ts`, which normalise them into
// {@link ExpenseLedgerInput} and call {@link postExpense}.
//
// Amounts are finance-standard NUMERIC rupees — the SAME unit every source stores
// — so no scaling is applied anywhere in this module.

import type { TenantQueryClient } from "../tenant_db.ts";

/**
 * The modules an expense may originate from. `payroll`, `inventory` and
 * `transport` have live adapters today; `maintenance`, `utilities` and `other`
 * are declared for future adapters (the DB CHECK matches this list exactly).
 */
export type ExpenseSourceModule =
  | "payroll"
  | "inventory"
  | "transport"
  | "maintenance"
  | "utilities"
  | "other";

export const EXPENSE_SOURCE_MODULES: readonly ExpenseSourceModule[] = [
  "payroll",
  "inventory",
  "transport",
  "maintenance",
  "utilities",
  "other",
];

/** A normalised expense ready to post to the ledger (source-agnostic). */
export interface ExpenseLedgerInput {
  organizationId: string;
  schoolId: string;
  sourceModule: ExpenseSourceModule;
  /** Id of the originating record in the source module (the idempotency ref). */
  sourceRef: string;
  /** Analytics/human expense category for the by-category breakdown. */
  category: string;
  /** Rupees (>= 0). Finance-standard NUMERIC unit — never minor units. */
  amount: number;
  /** ISO date (YYYY-MM-DD) the expense was incurred on. */
  incurredOn: string;
  description: string | null;
}

/** A raw ledger row as stored (NUMERIC comes back as a string, like transport). */
export interface ExpenseLedgerRow {
  id: string;
  organization_id: string;
  school_id: string;
  source_module: string;
  source_ref: string;
  category: string;
  amount: string;
  incurred_on: string;
  description: string | null;
  created_at: string;
}

/** Thrown when an expense with a non-finite / negative amount is posted. */
export class InvalidExpenseAmountError extends Error {
  constructor(amount: unknown) {
    super(`Expense amount must be a finite number >= 0, got: ${String(amount)}`);
    this.name = "InvalidExpenseAmountError";
  }
}

/** Thrown when a required posting field is missing/blank. */
export class InvalidExpenseInputError extends Error {
  constructor(field: string) {
    super(`Expense ledger input is missing required field: ${field}`);
    this.name = "InvalidExpenseInputError";
  }
}

/**
 * Post one normalised expense to the canonical ledger.
 *
 * Idempotent per `(organization_id, school_id, source_module, source_ref)` via the
 * table's UNIQUE constraint + `ON CONFLICT DO NOTHING`, so re-posting the same
 * source expense (a payroll replay, a nightly backfill, a ret/at-least-once wire)
 * can NEVER double-count. Returns `{ posted: true, entryId }` when a NEW row was
 * written, or `{ posted: false, entryId: null }` when the idempotency guard fired.
 *
 * Refuses (throws) an invalid amount rather than writing junk into a money ledger.
 */
export async function postExpense(
  db: TenantQueryClient,
  input: ExpenseLedgerInput,
): Promise<{ posted: boolean; entryId: string | null }> {
  if (!input.organizationId) throw new InvalidExpenseInputError("organizationId");
  if (!input.schoolId) throw new InvalidExpenseInputError("schoolId");
  if (!input.sourceRef) throw new InvalidExpenseInputError("sourceRef");
  if (!input.category || input.category.trim().length === 0) {
    throw new InvalidExpenseInputError("category");
  }
  if (!input.incurredOn) throw new InvalidExpenseInputError("incurredOn");
  if (!Number.isFinite(input.amount) || input.amount < 0) {
    throw new InvalidExpenseAmountError(input.amount);
  }

  const rows = await db.queryObject<{ id: string }>(
    `INSERT INTO expense_ledger_entries (
       organization_id, school_id, source_module, source_ref,
       category, amount, incurred_on, description
     ) VALUES ($1, $2, $3, $4, $5, $6, $7::date, $8)
     ON CONFLICT (organization_id, school_id, source_module, source_ref)
       DO NOTHING
     RETURNING id`,
    [
      input.organizationId,
      input.schoolId,
      input.sourceModule,
      input.sourceRef,
      input.category.trim(),
      input.amount,
      input.incurredOn,
      input.description,
    ],
  );
  const row = rows[0];
  return { posted: row != null, entryId: row?.id ?? null };
}

/**
 * The raw ledger entries for a school over a period, newest first. This is what
 * feeds the pure {@link buildExpenseBreakdown} when management wires the ledger.
 */
export async function listExpenseEntries(
  db: TenantQueryClient,
  orgId: string,
  schoolId: string,
  fromDate: string,
  toDate: string,
): Promise<ExpenseLedgerRow[]> {
  return await db.queryObject<ExpenseLedgerRow>(
    `SELECT * FROM expense_ledger_entries
      WHERE organization_id = $1 AND school_id = $2
        AND incurred_on BETWEEN $3::date AND $4::date
      ORDER BY incurred_on DESC, created_at DESC`,
    [orgId, schoolId, fromDate, toDate],
  );
}

/** Expense totals grouped by category for a period (+ grand total), rupees text. */
export async function getExpenseByCategory(
  db: TenantQueryClient,
  orgId: string,
  schoolId: string,
  fromDate: string,
  toDate: string,
): Promise<{ byCategory: Array<{ category: string; total: string }>; total: string }> {
  const rows = await db.queryObject<{ category: string; total: string }>(
    `SELECT category, COALESCE(SUM(amount), 0)::text AS total
       FROM expense_ledger_entries
      WHERE organization_id = $1 AND school_id = $2
        AND incurred_on BETWEEN $3::date AND $4::date
      GROUP BY category
      ORDER BY SUM(amount) DESC, category ASC`,
    [orgId, schoolId, fromDate, toDate],
  );
  let total = 0;
  for (const r of rows) total += Number(r.total);
  return {
    byCategory: rows.map((r) => ({ category: r.category, total: r.total })),
    total: total.toFixed(2),
  };
}

/** Expense totals grouped by source module for a period (+ grand total). */
export async function getExpenseBySource(
  db: TenantQueryClient,
  orgId: string,
  schoolId: string,
  fromDate: string,
  toDate: string,
): Promise<{ bySource: Array<{ sourceModule: string; total: string }>; total: string }> {
  const rows = await db.queryObject<{ source_module: string; total: string }>(
    `SELECT source_module, COALESCE(SUM(amount), 0)::text AS total
       FROM expense_ledger_entries
      WHERE organization_id = $1 AND school_id = $2
        AND incurred_on BETWEEN $3::date AND $4::date
      GROUP BY source_module
      ORDER BY SUM(amount) DESC, source_module ASC`,
    [orgId, schoolId, fromDate, toDate],
  );
  let total = 0;
  for (const r of rows) total += Number(r.total);
  return {
    bySource: rows.map((r) => ({ sourceModule: r.source_module, total: r.total })),
    total: total.toFixed(2),
  };
}

/** Combined summary — grand total + by-category + by-source, in one read pass. */
export interface ExpenseSummary {
  total: string;
  byCategory: Array<{ category: string; total: string }>;
  bySource: Array<{ sourceModule: string; total: string }>;
}

export async function getExpenseSummary(
  db: TenantQueryClient,
  orgId: string,
  schoolId: string,
  fromDate: string,
  toDate: string,
): Promise<ExpenseSummary> {
  const byCategory = await getExpenseByCategory(db, orgId, schoolId, fromDate, toDate);
  const bySource = await getExpenseBySource(db, orgId, schoolId, fromDate, toDate);
  return {
    total: byCategory.total,
    byCategory: byCategory.byCategory,
    bySource: bySource.bySource,
  };
}
