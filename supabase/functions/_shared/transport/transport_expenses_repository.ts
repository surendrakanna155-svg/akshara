// PRC-A Batch 8 (slice 1) — transport expense ledger + live cost recompute.
//
// The cost side of transport, off a real relational ledger. Pairs recorded
// expenses with the EXISTING transport income seam (finance_invoice_head_allocations
// where fee_head LIKE 'transport:%') for a real income-vs-expense figure — no more
// static ₹84K placeholder.

import type { TenantQueryClient } from "../tenant_db.ts";

export type TransportExpenseCategory =
  | "fuel"
  | "maintenance"
  | "insurance"
  | "salary"
  | "permit"
  | "toll"
  | "cleaning"
  | "other";

export const TRANSPORT_EXPENSE_CATEGORIES: readonly TransportExpenseCategory[] = [
  "fuel",
  "maintenance",
  "insurance",
  "salary",
  "permit",
  "toll",
  "cleaning",
  "other",
];

export interface TransportExpenseRow {
  id: string;
  organization_id: string;
  school_id: string;
  category: string;
  vehicle_id: string | null;
  route_id: string | null;
  amount: string;
  incurred_on: string;
  vendor: string | null;
  reference: string | null;
  notes: string | null;
  status: string;
  void_reason: string | null;
  voided_by: string | null;
  voided_at: string | null;
  recorded_by: string;
  created_at: string;
  updated_at: string;
}

/** Thrown when a void targets a non-existent or already-voided expense. */
export class TransportExpenseNotVoidableError extends Error {
  constructor(id: string) {
    super(`Transport expense not found or not voidable: ${id}`);
    this.name = "TransportExpenseNotVoidableError";
  }
}

export async function recordTransportExpense(
  db: TenantQueryClient,
  input: {
    organizationId: string;
    schoolId: string;
    category: TransportExpenseCategory;
    vehicleId: string | null;
    routeId: string | null;
    amount: string;
    incurredOn: string;
    vendor: string | null;
    reference: string | null;
    notes: string | null;
    recordedBy: string;
  },
): Promise<TransportExpenseRow> {
  const rows = await db.queryObject<TransportExpenseRow>(
    `INSERT INTO transport_expenses (
       organization_id, school_id, category, vehicle_id, route_id, amount,
       incurred_on, vendor, reference, notes, recorded_by
     ) VALUES ($1, $2, $3, $4, $5, $6, $7::date, $8, $9, $10, $11)
     RETURNING *`,
    [
      input.organizationId,
      input.schoolId,
      input.category,
      input.vehicleId,
      input.routeId,
      input.amount,
      input.incurredOn,
      input.vendor,
      input.reference,
      input.notes,
      input.recordedBy,
    ],
  );
  return rows[0]!;
}

/**
 * Void a recorded expense (soft, auditable). The `status = 'recorded'` guard on
 * the UPDATE + throw-on-zero-rows makes a concurrent double-void impossible and a
 * void of a missing/already-void row a clean 404 — mirroring the money-integrity
 * terminal-write-guard pattern used across finance.
 */
export async function voidTransportExpense(
  db: TenantQueryClient,
  orgId: string,
  schoolId: string,
  id: string,
  reason: string | null,
  actorId: string,
): Promise<TransportExpenseRow> {
  const rows = await db.queryObject<TransportExpenseRow>(
    `UPDATE transport_expenses
        SET status = 'void', void_reason = $4, voided_by = $5,
            voided_at = timezone('utc', now()), updated_at = timezone('utc', now())
      WHERE organization_id = $1 AND school_id = $2 AND id = $3::uuid
        AND status = 'recorded'
      RETURNING *`,
    [orgId, schoolId, id, reason, actorId],
  );
  if (rows.length === 0) throw new TransportExpenseNotVoidableError(id);
  return rows[0]!;
}

export async function listTransportExpenses(
  db: TenantQueryClient,
  orgId: string,
  schoolId: string,
  fromDate: string,
  toDate: string,
): Promise<TransportExpenseRow[]> {
  return await db.queryObject<TransportExpenseRow>(
    `SELECT * FROM transport_expenses
      WHERE organization_id = $1 AND school_id = $2
        AND incurred_on BETWEEN $3::date AND $4::date
      ORDER BY incurred_on DESC, created_at DESC`,
    [orgId, schoolId, fromDate, toDate],
  );
}

/** Recorded expense totals by category (+ grand total) for a period. */
export async function getTransportExpenseByCategory(
  db: TenantQueryClient,
  orgId: string,
  schoolId: string,
  fromDate: string,
  toDate: string,
): Promise<{ byCategory: Record<string, string>; total: string }> {
  const rows = await db.queryObject<{ category: string; total: string }>(
    `SELECT category, COALESCE(SUM(amount), 0)::text AS total
       FROM transport_expenses
      WHERE organization_id = $1 AND school_id = $2 AND status = 'recorded'
        AND incurred_on BETWEEN $3::date AND $4::date
      GROUP BY category
      ORDER BY category`,
    [orgId, schoolId, fromDate, toDate],
  );
  const byCategory: Record<string, string> = {};
  let total = 0;
  for (const r of rows) {
    byCategory[r.category] = r.total;
    total += Number(r.total);
  }
  return { byCategory, total: total.toFixed(2) };
}

/**
 * Transport income for invoices dated in the period, off the EXISTING
 * finance_invoice_head_allocations (fee_head LIKE 'transport:%'). Amounts are the
 * finance-standard NUMERIC (rupees), same unit as expenses — no scaling.
 */
export async function getTransportIncome(
  db: TenantQueryClient,
  orgId: string,
  schoolId: string,
  fromDate: string,
  toDate: string,
): Promise<{ billed: string; collected: string }> {
  const rows = await db.queryObject<{ billed: string; collected: string }>(
    `SELECT COALESCE(SUM(ha.head_total_minor), 0)::text AS billed,
            COALESCE(SUM(ha.head_paid_minor), 0)::text AS collected
       FROM finance_invoice_head_allocations ha
       JOIN finance_invoices fi ON fi.id = ha.invoice_id
      WHERE ha.organization_id = $1 AND ha.school_id = $2
        AND ha.fee_head LIKE 'transport:%'
        AND fi.invoice_date BETWEEN $3::date AND $4::date`,
    [orgId, schoolId, fromDate, toDate],
  );
  return { billed: rows[0]?.billed ?? "0", collected: rows[0]?.collected ?? "0" };
}

/**
 * Batch 8 slice 2: monthly recorded fuel spend for the last `months` months,
 * as the live replacement for snapshot_reports.fuelTrend (a static seed array).
 * Amounts are returned in lakhs to match the existing trend shape; `targetLakhs`
 * is null because there is no configured target to fabricate. Months with no fuel
 * are simply absent (an honest sparse trend, never fabricated zeros).
 */
export async function getMonthlyFuelTrend(
  db: TenantQueryClient,
  orgId: string,
  schoolId: string,
  months = 6,
): Promise<{ label: string; amountLakhs: number; targetLakhs: null }[]> {
  const rows = await db.queryObject<{ label: string; total: string }>(
    `SELECT to_char(date_trunc('month', incurred_on), 'Mon YYYY') AS label,
            COALESCE(SUM(amount), 0)::text AS total
       FROM transport_expenses
      WHERE organization_id = $1 AND school_id = $2 AND status = 'recorded'
        AND category = 'fuel'
        AND incurred_on >= (date_trunc('month', timezone('utc', now()))
              - (($3 || ' months')::interval))::date
      GROUP BY date_trunc('month', incurred_on)
      ORDER BY date_trunc('month', incurred_on)`,
    [orgId, schoolId, String(months)],
  );
  return rows.map((r) => ({
    label: r.label,
    amountLakhs: Number((Number(r.total) / 100000).toFixed(2)),
    targetLakhs: null,
  }));
}

/** Month-to-date recorded fuel spend — the live value for the dashboard KPI that
 * used to be the hardcoded "₹84K" placeholder. */
export async function getMonthToDateFuel(
  db: TenantQueryClient,
  orgId: string,
  schoolId: string,
): Promise<number> {
  const rows = await db.queryObject<{ total: string }>(
    `SELECT COALESCE(SUM(amount), 0)::text AS total
       FROM transport_expenses
      WHERE organization_id = $1 AND school_id = $2 AND status = 'recorded'
        AND category = 'fuel'
        AND incurred_on >= date_trunc('month', timezone('utc', now()))::date`,
    [orgId, schoolId],
  );
  return Number(rows[0]?.total ?? 0);
}
