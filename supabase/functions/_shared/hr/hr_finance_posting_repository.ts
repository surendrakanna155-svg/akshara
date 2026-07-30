import type { TenantQueryClient } from "../tenant_db.ts";

/**
 * PRA-P0-24 — payroll → Finance expense posting (hr-owned).
 *
 * When a payroll run is PROCESSED (disbursed), its totals are written to the
 * `payroll_finance_postings` table as a per-school payroll EXPENSE / DEMAND
 * record. This is a demand/expense record only — NO cash movement, and the
 * student-fee finance ledger is never touched.
 *
 * The insert is idempotent on `(organization_id, school_id, payroll_run_id)` via
 * `ON CONFLICT DO NOTHING`, so a re-process (already refused upstream by the 409
 * re-process guard in `applyPayrollRun`) can never double-post.
 *
 * The amount transforms are PURE (see {@link buildPayrollFinancePosting}) so the
 * "honest amounts" property is unit-testable DB-free; only the thin INSERT wrapper
 * touches Postgres.
 */

/** Coerces a JSONB numeric field to a finite number (0 when absent/non-numeric). */
function money(entry: Record<string, unknown>, ...keys: string[]): number {
  for (const key of keys) {
    if (key in entry && entry[key] != null) {
      const n = Number(entry[key]);
      if (Number.isFinite(n)) return n;
    }
  }
  return 0;
}

/**
 * Selects the entries belonging to `runId`: those tagged with the run, plus any
 * legacy untagged entries (the single-run snapshot shape). Mirrors the entry
 * selection in `buildSalaryRegister` so the posted totals equal the salary
 * register's totals for the same run.
 */
export function selectRunEntries(
  snapshot: Record<string, unknown>,
  runId: string,
): Array<Record<string, unknown>> {
  const entries = Array.isArray(snapshot.entries)
    ? snapshot.entries as Array<Record<string, unknown>>
    : [];
  return entries.filter((e) => {
    const entryRun = String(
      e.runId ?? e.run_id ?? e.payrollRunId ?? e.payroll_run_id ?? "",
    );
    return entryRun === "" || entryRun === runId;
  });
}

/** The finance posting derived from a processed payroll run + its salary lines. */
export interface PayrollFinancePosting {
  payrollRunId: string;
  period: string;
  /** Σ over entries of (basicPay + allowances) — the gross payroll cost. */
  grossAmount: number;
  /** Σ over entries of netPay — the amount actually disbursed. */
  netAmount: number;
  employeeCount: number;
}

/**
 * Pure: derive the finance posting totals from a processed run + its per-employee
 * entries. Amounts are summed from the SAME money columns the processor validates
 * (netPay === basic + allowances − deductions), so the posted gross/net are the
 * honest run totals — never a fabricated headline number.
 */
export function buildPayrollFinancePosting(
  run: Record<string, unknown>,
  entries: Array<Record<string, unknown>>,
): PayrollFinancePosting {
  let grossAmount = 0;
  let netAmount = 0;
  for (const e of entries) {
    grossAmount += money(e, "basicPay", "basic_pay") + money(e, "allowances");
    netAmount += money(e, "netPay", "net_pay");
  }
  return {
    payrollRunId: String(run.id ?? ""),
    period: String(run.period ?? ""),
    grossAmount,
    netAmount,
    employeeCount: entries.length,
  };
}

/**
 * Persist a payroll run's finance posting. Runs inside the caller's tenant
 * transaction, so the posting commits (or rolls back) atomically with the run
 * being marked processed.
 *
 * Returns `{ posted: true, postingId }` when a NEW posting row was written, or
 * `{ posted: false, postingId: null }` when a posting for this run already
 * existed (the `ON CONFLICT DO NOTHING` idempotency guard fired — no double-post).
 */
export async function postPayrollRunToFinance(
  db: TenantQueryClient,
  organizationId: string,
  schoolId: string,
  posting: PayrollFinancePosting,
  postedBy: string,
): Promise<{ posted: boolean; postingId: string | null }> {
  const rows = await db.queryObject<{ id: string }>(
    `INSERT INTO payroll_finance_postings (
       organization_id, school_id, payroll_run_id, period,
       gross_amount, net_amount, employee_count, status, posted_by
     )
     VALUES ($1, $2, $3, $4, $5, $6, $7, 'posted', $8)
     ON CONFLICT (organization_id, school_id, payroll_run_id) DO NOTHING
     RETURNING id`,
    [
      organizationId,
      schoolId,
      posting.payrollRunId,
      posting.period,
      posting.grossAmount,
      posting.netAmount,
      posting.employeeCount,
      postedBy || null,
    ],
  );
  const row = rows[0];
  return { posted: row != null, postingId: row?.id ?? null };
}
