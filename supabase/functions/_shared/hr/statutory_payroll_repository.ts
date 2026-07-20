// PRA-P1-35 (Owner decision #9, FINAL) — statutory payroll persistence (hr-owned).
//
// The thin DB layer over the PURE engine in `statutory_payroll.ts`. It:
//   • reads the config-driven component rules from `statutory_component_config`
//     and the per-state PT slabs from `statutory_pt_slabs` — the rates/ceilings/
//     slabs are DATA, never hardcoded in code;
//   • upserts config + slabs (admin configuration);
//   • posts the per-run per-component statutory LIABILITIES idempotently with
//     INSERT … ON CONFLICT DO NOTHING (the UNIQUE (org, school, run, component,
//     state) guard makes a re-process a no-op — the same guarantee proven for
//     payroll_finance_postings).
//
// Everything with real arithmetic lives in the pure module; here we only move rows.

import type { TenantQueryClient } from "../tenant_db.ts";
import {
  type PtSlab,
  type RoundingMode,
  type StatutoryComponent,
  type StatutoryComponentConfig,
  type StatutoryLiability,
  type WageBase,
} from "./statutory_payroll.ts";

/** Coerce a NUMERIC/text DB value to a finite number (0 when absent/non-numeric). */
function num(value: unknown): number {
  const n = Number(value);
  return Number.isFinite(n) ? n : 0;
}

/** Coerce a nullable NUMERIC to `number | null` (NULL = unlimited / not set). */
function nullableNum(value: unknown): number | null {
  if (value == null) return null;
  const n = Number(value);
  return Number.isFinite(n) ? n : null;
}

function asBool(value: unknown): boolean {
  return value === true || value === "true" || value === "t";
}

/** Maps a `statutory_component_config` row to the pure-engine config shape. */
export function rowToComponentConfig(row: Record<string, unknown>): StatutoryComponentConfig {
  return {
    component: String(row.component ?? "") as StatutoryComponent,
    state: String(row.state ?? ""),
    employeeRate: num(row.employee_rate),
    employerRate: num(row.employer_rate),
    wageBase: (String(row.wage_base ?? "gross") as WageBase),
    baseCap: nullableNum(row.base_cap),
    eligibilityCeiling: nullableNum(row.eligibility_ceiling),
    eligibilityFloor: nullableNum(row.eligibility_floor),
    flatEmployee: nullableNum(row.flat_employee),
    flatEmployer: nullableNum(row.flat_employer),
    rounding: (String(row.rounding ?? "nearest") as RoundingMode),
    active: asBool(row.active),
  };
}

/** Maps a `statutory_pt_slabs` row to the pure-engine slab shape. */
export function rowToPtSlab(row: Record<string, unknown>): PtSlab {
  return {
    state: String(row.state ?? ""),
    lowerBound: num(row.lower_bound),
    upperBound: nullableNum(row.upper_bound),
    amount: num(row.amount),
    month: row.month == null ? null : num(row.month),
  };
}

/**
 * Reads the ACTIVE statutory component rules that apply to `state`: the central
 * ("" state) rules PLUS the state-specific ones. The engine's behaviour is driven
 * entirely by what this returns — no rate is baked into code.
 */
export async function listStatutoryConfigs(
  db: TenantQueryClient,
  organizationId: string,
  schoolId: string,
  state: string,
): Promise<StatutoryComponentConfig[]> {
  const rows = await db.queryObject<Record<string, unknown>>(
    `SELECT component, state, employee_rate, employer_rate, wage_base,
            base_cap, eligibility_ceiling, eligibility_floor,
            flat_employee, flat_employer, rounding, active
       FROM statutory_component_config
      WHERE organization_id = $1
        AND school_id = $2
        AND active = true
        AND (state = '' OR state = $3)
      ORDER BY component, state`,
    [organizationId, schoolId, state],
  );
  return rows.map(rowToComponentConfig);
}

/** Reads the ACTIVE PT slabs configured for a state (empty when none). */
export async function listPtSlabs(
  db: TenantQueryClient,
  organizationId: string,
  schoolId: string,
  state: string,
): Promise<PtSlab[]> {
  if (state === "") return [];
  const rows = await db.queryObject<Record<string, unknown>>(
    `SELECT state, lower_bound, upper_bound, amount, month
       FROM statutory_pt_slabs
      WHERE organization_id = $1
        AND school_id = $2
        AND state = $3
        AND active = true
      ORDER BY lower_bound, month NULLS FIRST`,
    [organizationId, schoolId, state],
  );
  return rows.map(rowToPtSlab);
}

/**
 * Upserts one component rule (INSERT … ON CONFLICT (org, school, component, state)
 * DO UPDATE). Configuring the same component + jurisdiction again replaces the
 * numbers in place — a school has exactly one active rule per (component, state).
 */
export async function upsertComponentConfig(
  db: TenantQueryClient,
  organizationId: string,
  schoolId: string,
  cfg: StatutoryComponentConfig,
): Promise<{ id: string }> {
  const rows = await db.queryObject<{ id: string }>(
    `INSERT INTO statutory_component_config (
       organization_id, school_id, component, state,
       employee_rate, employer_rate, wage_base, base_cap,
       eligibility_ceiling, eligibility_floor, flat_employee, flat_employer,
       rounding, active
     )
     VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14)
     ON CONFLICT (organization_id, school_id, component, state) DO UPDATE SET
       employee_rate = EXCLUDED.employee_rate,
       employer_rate = EXCLUDED.employer_rate,
       wage_base = EXCLUDED.wage_base,
       base_cap = EXCLUDED.base_cap,
       eligibility_ceiling = EXCLUDED.eligibility_ceiling,
       eligibility_floor = EXCLUDED.eligibility_floor,
       flat_employee = EXCLUDED.flat_employee,
       flat_employer = EXCLUDED.flat_employer,
       rounding = EXCLUDED.rounding,
       active = EXCLUDED.active,
       updated_at = timezone('utc', now())
     RETURNING id`,
    [
      organizationId,
      schoolId,
      cfg.component,
      cfg.state,
      cfg.employeeRate,
      cfg.employerRate,
      cfg.wageBase,
      cfg.baseCap,
      cfg.eligibilityCeiling,
      cfg.eligibilityFloor,
      cfg.flatEmployee,
      cfg.flatEmployer,
      cfg.rounding,
      cfg.active,
    ],
  );
  return { id: rows[0]?.id ?? "" };
}

/**
 * Upserts one PT slab (INSERT … ON CONFLICT on the (org, school, state,
 * lower_bound, COALESCE(month,0)) band index DO UPDATE). Re-posting the same band
 * replaces its amount in place.
 */
export async function upsertPtSlab(
  db: TenantQueryClient,
  organizationId: string,
  schoolId: string,
  slab: PtSlab,
): Promise<{ id: string }> {
  const rows = await db.queryObject<{ id: string }>(
    `INSERT INTO statutory_pt_slabs (
       organization_id, school_id, state, lower_bound, upper_bound, amount, month
     )
     VALUES ($1, $2, $3, $4, $5, $6, $7)
     ON CONFLICT (organization_id, school_id, state, lower_bound, COALESCE(month, 0)) DO UPDATE SET
       upper_bound = EXCLUDED.upper_bound,
       amount = EXCLUDED.amount,
       active = true,
       updated_at = timezone('utc', now())
     RETURNING id`,
    [
      organizationId,
      schoolId,
      slab.state,
      slab.lowerBound,
      slab.upperBound,
      slab.amount,
      slab.month,
    ],
  );
  return { id: rows[0]?.id ?? "" };
}

/**
 * Posts one statutory liability idempotently. Returns whether a NEW row was
 * written (`posted:false` means the run+component was already posted — the ON
 * CONFLICT DO NOTHING guard fired, so no double-post).
 */
export async function postStatutoryLiability(
  db: TenantQueryClient,
  organizationId: string,
  schoolId: string,
  payrollRunId: string,
  period: string,
  liability: StatutoryLiability,
  postedBy: string,
): Promise<{ posted: boolean; id: string | null }> {
  const rows = await db.queryObject<{ id: string }>(
    `INSERT INTO payroll_statutory_liabilities (
       organization_id, school_id, payroll_run_id, period,
       component, state, employee_amount, employer_amount, total_amount,
       employee_count, status, posted_by
     )
     VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, 'posted', $11)
     ON CONFLICT (organization_id, school_id, payroll_run_id, component, state) DO NOTHING
     RETURNING id`,
    [
      organizationId,
      schoolId,
      payrollRunId,
      period,
      liability.component,
      liability.state,
      liability.employeeAmount,
      liability.employerAmount,
      liability.totalAmount,
      liability.employeeCount,
      postedBy || null,
    ],
  );
  const row = rows[0];
  return { posted: row != null, id: row?.id ?? null };
}

/**
 * Posts every per-component liability for a processed run. Idempotent per
 * (run, component, state): a re-process posts no second row. Returns how many
 * NEW rows were written this call.
 */
export async function postStatutoryLiabilities(
  db: TenantQueryClient,
  organizationId: string,
  schoolId: string,
  payrollRunId: string,
  period: string,
  liabilities: StatutoryLiability[],
  postedBy: string,
): Promise<{ posted: number }> {
  let posted = 0;
  for (const liability of liabilities) {
    const { posted: didPost } = await postStatutoryLiability(
      db,
      organizationId,
      schoolId,
      payrollRunId,
      period,
      liability,
      postedBy,
    );
    if (didPost) posted++;
  }
  return { posted };
}

/** Reads the posted statutory liabilities for a run (for a read/report path). */
export async function readStatutoryLiabilities(
  db: TenantQueryClient,
  organizationId: string,
  schoolId: string,
  payrollRunId: string,
): Promise<Array<Record<string, unknown>>> {
  return await db.queryObject<Record<string, unknown>>(
    `SELECT component, state, employee_amount, employer_amount, total_amount,
            employee_count, status, period
       FROM payroll_statutory_liabilities
      WHERE organization_id = $1
        AND school_id = $2
        AND payroll_run_id = $3
      ORDER BY component, state`,
    [organizationId, schoolId, payrollRunId],
  );
}
