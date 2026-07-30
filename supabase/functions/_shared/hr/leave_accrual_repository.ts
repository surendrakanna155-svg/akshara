// PRA-P1-34 (Owner decision #10, FINAL) — leave accrual persistence (hr-owned).
//
// The thin DB layer over the PURE engine in `leave_accrual.ts`. It:
//   • reads the config-driven accrual policies from `leave_accrual_policies`
//     (the accrual RULES are DATA, never hardcoded in code);
//   • runs the accrual for an employee + policy by computing the intended ledger
//     (pure) and upserting each entry with INSERT … ON CONFLICT DO NOTHING —
//     idempotent on (org, school, employee, leave_type, entry_type, period_key),
//     so a re-run in the same period writes NO new row (no double-accrue);
//   • reads the derivable balance as SUM(amount) over the append-only ledger.
//
// Everything with real arithmetic lives in the pure module; here we only move
// rows. The idempotency GUARANTEE is the DB UNIQUE constraint + ON CONFLICT DO
// NOTHING — the same guard pattern proven for payroll_finance_postings.

import type { TenantQueryClient } from "../tenant_db.ts";
import {
  type AccrualPeriod,
  computeAccrual,
  type LeaveAccrualPolicy,
  type PlannedLedgerEntry,
} from "./leave_accrual.ts";

/** Coerce a NUMERIC/text DB value to a finite number (0 when absent/non-numeric). */
function num(value: unknown): number {
  const n = Number(value);
  return Number.isFinite(n) ? n : 0;
}

/** Coerce a nullable NUMERIC cap to `number | null` (NULL = unlimited). */
function nullableNum(value: unknown): number | null {
  if (value == null) return null;
  const n = Number(value);
  return Number.isFinite(n) ? n : null;
}

/** Maps a `leave_accrual_policies` row to the pure-engine policy shape. */
export function rowToPolicy(row: Record<string, unknown>): LeaveAccrualPolicy {
  return {
    leaveType: String(row.leave_type ?? ""),
    accrualRate: num(row.accrual_rate),
    accrualPeriod: (String(row.accrual_period ?? "monthly") as AccrualPeriod),
    openingBalance: num(row.opening_balance),
    carryForwardCap: nullableNum(row.carry_forward_cap),
    maxBalance: nullableNum(row.max_balance),
    lapses: row.lapses === true || row.lapses === "true" || row.lapses === "t",
  };
}

/**
 * Reads all ACTIVE accrual policies configured for this school. The engine's
 * behaviour is driven entirely by what this returns — no leave-type vocabulary
 * and no accrual rule is baked into code.
 */
export async function listAccrualPolicies(
  db: TenantQueryClient,
  organizationId: string,
  schoolId: string,
): Promise<LeaveAccrualPolicy[]> {
  const rows = await db.queryObject<Record<string, unknown>>(
    `SELECT leave_type, accrual_rate, accrual_period, opening_balance,
            carry_forward_cap, max_balance, lapses
       FROM leave_accrual_policies
      WHERE organization_id = $1
        AND school_id = $2
        AND active = true
      ORDER BY leave_type`,
    [organizationId, schoolId],
  );
  return rows.map(rowToPolicy);
}

/** Reads one active accrual policy by leave-type, or null when none is configured. */
export async function getAccrualPolicy(
  db: TenantQueryClient,
  organizationId: string,
  schoolId: string,
  leaveType: string,
): Promise<LeaveAccrualPolicy | null> {
  const rows = await db.queryObject<Record<string, unknown>>(
    `SELECT leave_type, accrual_rate, accrual_period, opening_balance,
            carry_forward_cap, max_balance, lapses
       FROM leave_accrual_policies
      WHERE organization_id = $1
        AND school_id = $2
        AND leave_type = $3
        AND active = true`,
    [organizationId, schoolId, leaveType],
  );
  return rows[0] ? rowToPolicy(rows[0]) : null;
}

/**
 * Upserts a single planned ledger entry idempotently. Returns whether a NEW row
 * was written (`inserted:false` means the period was already accrued — the
 * ON CONFLICT DO NOTHING guard fired, so no double-accrue).
 */
export async function appendLedgerEntry(
  db: TenantQueryClient,
  organizationId: string,
  schoolId: string,
  employeeId: string,
  entry: PlannedLedgerEntry,
  createdBy: string,
): Promise<{ inserted: boolean; id: string | null }> {
  const rows = await db.queryObject<{ id: string }>(
    `INSERT INTO leave_accrual_ledger (
       organization_id, school_id, employee_id, leave_type,
       entry_type, amount, period_key, as_of_date, note, created_by
     )
     VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10)
     ON CONFLICT (organization_id, school_id, employee_id, leave_type, entry_type, period_key)
       DO NOTHING
     RETURNING id`,
    [
      organizationId,
      schoolId,
      employeeId,
      entry.leaveType,
      entry.entryType,
      entry.amount,
      entry.periodKey,
      entry.asOfDate,
      entry.note,
      createdBy || null,
    ],
  );
  const row = rows[0];
  return { inserted: row != null, id: row?.id ?? null };
}

/** Sum of prior 'deduction' entries (approved leave taken) for an employee + leave-type. */
export async function readPriorDeductions(
  db: TenantQueryClient,
  organizationId: string,
  schoolId: string,
  employeeId: string,
  leaveType: string,
): Promise<number> {
  const rows = await db.queryObject<{ deducted: string | null }>(
    `SELECT COALESCE(-SUM(amount), 0)::text AS deducted
       FROM leave_accrual_ledger
      WHERE organization_id = $1
        AND school_id = $2
        AND employee_id = $3
        AND leave_type = $4
        AND entry_type = 'deduction'`,
    [organizationId, schoolId, employeeId, leaveType],
  );
  return Math.max(0, num(rows[0]?.deducted));
}

export interface RunAccrualResult {
  employeeId: string;
  leaveType: string;
  /** Planned ledger entries produced by the pure engine. */
  planned: number;
  /** How many of those were actually written this run (0 on a same-period re-run). */
  inserted: number;
  /** The derivable balance after the run (from the pure computation). */
  balance: number;
}

/**
 * Runs accrual for ONE employee against ONE policy. Computes the intended ledger
 * (pure) and upserts every entry idempotently. Running twice in the same period
 * inserts nothing the second time — the period-key UNIQUE guard makes it a no-op,
 * so accrual can never be double-applied.
 */
export async function runAccrualForEmployee(
  db: TenantQueryClient,
  organizationId: string,
  schoolId: string,
  employeeId: string,
  joinDate: string,
  asOfDate: string,
  policy: LeaveAccrualPolicy,
  createdBy: string,
): Promise<RunAccrualResult> {
  const priorDeductions = await readPriorDeductions(
    db,
    organizationId,
    schoolId,
    employeeId,
    policy.leaveType,
  );
  const result = computeAccrual(policy, joinDate, asOfDate, { priorDeductions });

  let inserted = 0;
  for (const entry of result.entries) {
    const { inserted: didInsert } = await appendLedgerEntry(
      db,
      organizationId,
      schoolId,
      employeeId,
      entry,
      createdBy,
    );
    if (didInsert) inserted++;
  }

  return {
    employeeId,
    leaveType: policy.leaveType,
    planned: result.entries.length,
    inserted,
    balance: result.balance,
  };
}

export interface AccrualBalance {
  employeeId: string;
  leaveType: string;
  balance: number;
}

/**
 * Reads the derivable accrual balances for an employee — SUM(amount) grouped by
 * leave-type over the append-only ledger. There is no stored balance column; the
 * ledger is the source of truth.
 */
export async function readAccrualBalances(
  db: TenantQueryClient,
  organizationId: string,
  schoolId: string,
  employeeId: string,
): Promise<AccrualBalance[]> {
  const rows = await db.queryObject<{ leave_type: string; balance: string | null }>(
    `SELECT leave_type, COALESCE(SUM(amount), 0)::text AS balance
       FROM leave_accrual_ledger
      WHERE organization_id = $1
        AND school_id = $2
        AND employee_id = $3
      GROUP BY leave_type
      ORDER BY leave_type`,
    [organizationId, schoolId, employeeId],
  );
  return rows.map((r) => ({
    employeeId,
    leaveType: String(r.leave_type),
    balance: num(r.balance),
  }));
}
