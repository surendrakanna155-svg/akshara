// PRA-P1-35 (Owner decision #9, FINAL) — statutory payroll deductions: the PURE
// computation core. NO database, NO I/O. Given an employee's monthly wage (basic +
// allowances) and the applicable CONFIG (rates, ceilings, employee/employer split,
// jurisdiction) it computes each statutory deduction — PF, ESI, PT, TDS — with the
// correct base + ceiling rules, and returns both the employee share (withheld from
// net) and the employer contribution (a liability, never deducted from the employee).
//
// ── Config is DATA, formulas are code ────────────────────────────────────────
// EVERY rate, ceiling, threshold and slab is read from config (a DB row) — NOTHING
// is a hardcoded compliance number. What lives in code is only the SHAPE of each
// statutory rule (PF caps its base; ESI is eligibility-gated; PT is a per-state
// slab; TDS is a configurable flat rate), exactly as `leave_accrual.ts` keeps the
// accrual cadence in code while every day-rate is config. A component with a rate
// of 0 (the schema DEFAULT) deducts NOTHING — an unconfigured tenant is deploy-safe.
//
// ── The four statutory rules ─────────────────────────────────────────────────
//   • PF  (Provident Fund, EPF Act) — employee_rate × min(pf_wage, base_cap) and
//     employer_rate × the same capped base. The `base_cap` (statutory PF wage
//     ceiling) CAPS the wage the rate is applied to; earnings above it accrue no
//     extra PF. Employee + employer are both returned.
//   • ESI (Employees' State Insurance) — an ELIGIBILITY gate: when the wage exceeds
//     `eligibility_ceiling` the component does NOT apply at all (0 employee, 0
//     employer). At/under the ceiling the rate applies to the FULL wage (the
//     ceiling gates eligibility, it does NOT cap the base). Both shares returned,
//     each rounded UP to the next rupee (statutory ESI rounding) when configured.
//   • PT  (Professional Tax) — a per-STATE flat-amount SLAB on monthly gross:
//     find the slab whose [lower, upper] band contains the gross and deduct its
//     flat `amount`. Fully employee-borne (no employer share). Slabs are per-state
//     config rows; a `month` override models states with a special month (e.g. the
//     higher February slab) as DATA, not code.
//   • TDS (Tax Deducted at Source) — MODEL CHOSEN: a configurable FLAT-RATE monthly
//     withholding (employee_rate × wage, or a flat_employee amount). This is the
//     simple, deploy-safe default (rate 0 → 0 TDS). The richer projected-annual/12
//     progressive-slab model is provided as `projectedAnnualTds()` (pure + tested)
//     for a follow-up to wire in once per-regime income-tax slabs are configured;
//     it is NOT in the default monthly path so no tax number is ever guessed.
//
// All amounts are money in rupees. Employer shares are captured but NEVER netted
// against the employee — the payroll integration subtracts only `employeeTotal`.

export type StatutoryComponent = "pf" | "esi" | "pt" | "tds";

/** Which wage a rate is applied to. PF is on the (capped) PF-wage; ESI/PT/TDS on gross. */
export type WageBase = "gross" | "basic";

/** How each computed share is rounded. ESI rounds UP to the next rupee statutorily. */
export type RoundingMode = "none" | "nearest" | "up";

/**
 * A config-driven statutory-component rule — one row of `statutory_component_config`.
 * Read from the DB (see statutory_payroll_repository.ts); never hardcoded in code.
 */
export interface StatutoryComponentConfig {
  component: StatutoryComponent;
  /** Jurisdiction key. "" = central/all (PF, ESI, TDS); a state code (e.g. "KA") scopes PT. */
  state: string;
  /** Employee contribution rate as a FRACTION (0.12 = 12%). 0 = no employee deduction. */
  employeeRate: number;
  /** Employer contribution rate as a FRACTION. 0 = no employer contribution. */
  employerRate: number;
  /** Which wage the rate applies to. */
  wageBase: WageBase;
  /** Caps the wage the rate is applied to (PF ceiling). null = no cap. */
  baseCap: number | null;
  /** Eligibility ceiling — above it the component does NOT apply at all (ESI). null = always eligible. */
  eligibilityCeiling: number | null;
  /** Eligibility floor — below it the component does NOT apply. null = no floor. */
  eligibilityFloor: number | null;
  /** Flat monthly employee amount, overriding the rate (e.g. flat TDS/PT). null = use the rate. */
  flatEmployee: number | null;
  /** Flat monthly employer amount, overriding the rate. null = use the rate. */
  flatEmployer: number | null;
  rounding: RoundingMode;
  active: boolean;
}

/** A per-state Professional-Tax slab — one row of `statutory_pt_slabs`. */
export interface PtSlab {
  state: string;
  /** Monthly gross ≥ lowerBound. */
  lowerBound: number;
  /** Monthly gross ≤ upperBound; null = no upper bound (top slab). */
  upperBound: number | null;
  /** Flat PT amount for the band (per month). */
  amount: number;
  /** Month override 1..12 for a state's special month; null = every month. */
  month: number | null;
}

/** The employee's monthly wage components (from the salary structure). */
export interface StatutoryWage {
  basic: number;
  allowances: number;
}

/** The computed deduction for ONE statutory component. */
export interface ComponentDeduction {
  component: StatutoryComponent;
  state: string;
  /** The wage base the rate was applied to (after any cap); 0 when not eligible. */
  base: number;
  /** Employee share — WITHHELD from net pay. */
  employee: number;
  /** Employer share — a LIABILITY; never deducted from the employee. */
  employer: number;
  /** Whether the component applied to this employee. */
  eligible: boolean;
}

/** The full statutory result for one employee. */
export interface StatutoryResult {
  components: ComponentDeduction[];
  /** Σ employee shares — the ONLY figure subtracted from gross to reach net. */
  employeeTotal: number;
  /** Σ employer shares — captured as a liability, never netted. */
  employerTotal: number;
  /** The gross (basic + allowances) the computation saw. */
  gross: number;
}

/** Rounds to 2 decimals (money is NUMERIC(_,2)); avoids float drift. */
export function round2(n: number): number {
  return Math.round((n + Number.EPSILON) * 100) / 100;
}

/** Applies a statutory rounding mode to a single (non-negative) share. */
export function roundShare(value: number, mode: RoundingMode): number {
  if (!(value > 0)) return 0;
  switch (mode) {
    case "up":
      return Math.ceil(value);
    case "none":
      return round2(value);
    case "nearest":
    default:
      return Math.round(value);
  }
}

const ZERO = (component: StatutoryComponent, state: string): ComponentDeduction => ({
  component,
  state,
  base: 0,
  employee: 0,
  employer: 0,
  eligible: false,
});

/** The wage a component's rate applies to, honouring its configured base. */
export function resolveWageBase(cfg: StatutoryComponentConfig, wage: StatutoryWage): number {
  const basic = Math.max(0, wage.basic);
  const gross = round2(basic + Math.max(0, wage.allowances));
  return cfg.wageBase === "basic" ? round2(basic) : gross;
}

/**
 * Rate/flat component (PF, ESI, and the default flat-rate TDS). Applies the
 * eligibility gate (floor/ceiling) first, then either the flat override or
 * rate × capped-base, rounding each share by the config's rounding mode.
 */
export function computeRateComponent(
  cfg: StatutoryComponentConfig,
  wage: StatutoryWage,
): ComponentDeduction {
  if (!cfg.active) return ZERO(cfg.component, cfg.state);
  const rawBase = resolveWageBase(cfg, wage);

  // Eligibility gate — ESI over the ceiling (or under a floor) does not apply AT ALL.
  const overCeiling = cfg.eligibilityCeiling != null && rawBase > cfg.eligibilityCeiling;
  const underFloor = cfg.eligibilityFloor != null && rawBase < cfg.eligibilityFloor;
  if (overCeiling || underFloor) return ZERO(cfg.component, cfg.state);

  // Flat override wins over the rate (configurable flat TDS / flat PT).
  if (cfg.flatEmployee != null || cfg.flatEmployer != null) {
    const employee = roundShare(Math.max(0, cfg.flatEmployee ?? 0), cfg.rounding);
    const employer = roundShare(Math.max(0, cfg.flatEmployer ?? 0), cfg.rounding);
    return { component: cfg.component, state: cfg.state, base: rawBase, employee, employer, eligible: true };
  }

  // base_cap CAPS the wage the rate is applied to (PF statutory ceiling).
  const cappedBase = cfg.baseCap != null ? Math.min(rawBase, cfg.baseCap) : rawBase;
  const employee = roundShare(Math.max(0, cfg.employeeRate) * cappedBase, cfg.rounding);
  const employer = roundShare(Math.max(0, cfg.employerRate) * cappedBase, cfg.rounding);
  return { component: cfg.component, state: cfg.state, base: cappedBase, employee, employer, eligible: true };
}

/**
 * Professional Tax from the per-state flat-amount slabs. Finds the slab whose
 * [lower, upper] band contains the monthly gross; a `month`-specific slab in the
 * same band wins over the month-agnostic (month = null) default (special-month
 * states). Fully employee-borne. Falls back to a configured flat_employee when no
 * slab is configured for the state (a flat-PT tenant). Returns 0 when neither.
 */
export function computePtFromSlabs(
  cfg: StatutoryComponentConfig,
  gross: number,
  slabs: PtSlab[],
  month: number | null,
): ComponentDeduction {
  if (!cfg.active) return ZERO("pt", cfg.state);

  // PT honours a configured eligibility gate too (some states exempt below a floor).
  const overCeiling = cfg.eligibilityCeiling != null && gross > cfg.eligibilityCeiling;
  const underFloor = cfg.eligibilityFloor != null && gross < cfg.eligibilityFloor;
  if (overCeiling || underFloor) return ZERO("pt", cfg.state);

  const inBand = slabs.filter(
    (s) =>
      s.state === cfg.state &&
      gross >= s.lowerBound &&
      (s.upperBound == null || gross <= s.upperBound),
  );
  const monthSlab = month != null ? inBand.find((s) => s.month === month) : undefined;
  const defaultSlab = inBand.find((s) => s.month == null);
  const slab = monthSlab ?? defaultSlab;

  if (slab) {
    const employee = roundShare(Math.max(0, slab.amount), cfg.rounding);
    return { component: "pt", state: cfg.state, base: gross, employee, employer: 0, eligible: true };
  }
  // No slab configured for this state → optional flat-PT fallback.
  if (cfg.flatEmployee != null) {
    const employee = roundShare(Math.max(0, cfg.flatEmployee), cfg.rounding);
    return { component: "pt", state: cfg.state, base: gross, employee, employer: 0, eligible: employee > 0 };
  }
  return ZERO("pt", cfg.state);
}

/**
 * The top-level statutory computation. Given the wage + the applicable configs
 * (+ PT slabs), computes every eligible component and totals the employee /
 * employer shares. A config applies when it is central ("" state) OR matches the
 * target `state`. Zero configs → zero components → zero deduction (deploy-safe).
 */
export function computeStatutoryDeductions(
  wage: StatutoryWage,
  configs: StatutoryComponentConfig[],
  opts: { state?: string; ptSlabs?: PtSlab[]; month?: number | null } = {},
): StatutoryResult {
  const targetState = opts.state ?? "";
  const ptSlabs = opts.ptSlabs ?? [];
  const month = opts.month ?? null;
  const gross = round2(Math.max(0, wage.basic) + Math.max(0, wage.allowances));

  const components: ComponentDeduction[] = [];
  for (const cfg of configs) {
    if (!cfg.active) continue;
    // Central configs (state "") apply everywhere; state configs only in that state.
    if (cfg.state !== "" && cfg.state !== targetState) continue;

    const deduction = cfg.component === "pt"
      ? computePtFromSlabs(cfg, resolveWageBase(cfg, wage), ptSlabs, month)
      : computeRateComponent(cfg, wage);
    components.push(deduction);
  }

  const employeeTotal = round2(components.reduce((sum, c) => sum + c.employee, 0));
  const employerTotal = round2(components.reduce((sum, c) => sum + c.employer, 0));
  return { components, employeeTotal, employerTotal, gross };
}

/** The statutory fields folded onto a payroll entry by the run generator. */
export interface StatutoryEntryFields {
  /** Employee statutory total — subtracted from net pay. */
  statutoryEmployee: number;
  /** Employer statutory total — a liability, never netted. */
  statutoryEmployer: number;
  /** Per-component breakdown persisted on the entry (drives liability posting). */
  statutory: ComponentDeduction[];
}

/**
 * Convenience wrapper the payroll generator uses: computes statutory for one wage
 * and returns the itemised fields to fold onto the entry. Empty configs → zeros.
 */
export function statutoryFieldsFor(
  wage: StatutoryWage,
  configs: StatutoryComponentConfig[],
  opts: { state?: string; ptSlabs?: PtSlab[]; month?: number | null } = {},
): StatutoryEntryFields {
  const result = computeStatutoryDeductions(wage, configs, opts);
  return {
    statutoryEmployee: result.employeeTotal,
    statutoryEmployer: result.employerTotal,
    statutory: result.components,
  };
}

/** A per-component statutory liability aggregated across a payroll run's entries. */
export interface StatutoryLiability {
  component: StatutoryComponent;
  state: string;
  /** Σ employee withholding across the run. */
  employeeAmount: number;
  /** Σ employer contribution across the run. */
  employerAmount: number;
  /** The remittance liability = employee + employer (PT/TDS = employee only). */
  totalAmount: number;
  /** Number of employees for whom the component applied. */
  employeeCount: number;
}

function num(value: unknown): number {
  const n = Number(value);
  return Number.isFinite(n) ? n : 0;
}

/**
 * Derives the per-component statutory liabilities from a processed run's entries.
 * Each entry carries its `statutory` breakdown (set at generation); this groups by
 * (component, state) and sums the employee + employer shares. Entries generated
 * WITHOUT statutory config carry no breakdown → no liabilities (deploy-safe). Only
 * non-zero liabilities are returned (nothing to remit → nothing posted).
 */
export function deriveStatutoryLiabilities(
  entries: Array<Record<string, unknown>>,
): StatutoryLiability[] {
  const map = new Map<string, StatutoryLiability>();
  for (const entry of entries) {
    const comps = Array.isArray(entry.statutory)
      ? entry.statutory as Array<Record<string, unknown>>
      : [];
    for (const c of comps) {
      const component = String(c.component ?? "") as StatutoryComponent;
      if (component !== "pf" && component !== "esi" && component !== "pt" && component !== "tds") {
        continue;
      }
      const state = String(c.state ?? "");
      const key = `${component}|${state}`;
      const employee = num(c.employee);
      const employer = num(c.employer);
      const cur = map.get(key) ?? {
        component,
        state,
        employeeAmount: 0,
        employerAmount: 0,
        totalAmount: 0,
        employeeCount: 0,
      };
      cur.employeeAmount = round2(cur.employeeAmount + employee);
      cur.employerAmount = round2(cur.employerAmount + employer);
      cur.totalAmount = round2(cur.employeeAmount + cur.employerAmount);
      // Count only employees who actually CONTRIBUTED to this liability — an
      // employee in an exempt slab or over the eligibility ceiling (0/0) is not a
      // payer, so they are not counted against the remittance.
      if (employee > 0 || employer > 0) cur.employeeCount += 1;
      map.set(key, cur);
    }
  }
  return [...map.values()].filter((l) => l.employeeAmount > 0 || l.employerAmount > 0);
}

/**
 * Parses a payroll period label ("2026-07" / "2026-07-01") to its month number
 * (1..12), or null when the label is not ISO-month-shaped (a free-form period, so
 * no special-month PT slab can be selected — the month-agnostic slab is used).
 */
export function monthFromPeriod(period: string): number | null {
  const m = period.match(/^\d{4}-(\d{2})/);
  if (!m) return null;
  const month = parseInt(m[1]!, 10);
  return month >= 1 && month <= 12 ? month : null;
}

// ── TDS follow-up model: projected-annual / 12 with progressive slabs ─────────
//
// NOT on the default monthly path (which uses the flat-rate model above). Provided
// pure + tested so a follow-up can wire it in once a tenant configures income-tax
// slabs for the chosen regime. It projects the annual taxable income as
// monthlyTaxable × months, applies the progressive slabs, subtracts a rebate, and
// spreads the annual tax across the remaining months. Every number (slab bounds,
// rates, rebate, months) is an argument — nothing is a hardcoded tax figure.

/** A progressive income-tax slab: `rate` (fraction) applies to income in (lower, upper]. */
export interface TaxSlab {
  lower: number;
  /** null = no upper bound (top slab). */
  upper: number | null;
  rate: number;
}

/** Progressive annual tax on `annualIncome` across `slabs` (only income within each band is taxed). */
export function annualTaxFromSlabs(annualIncome: number, slabs: TaxSlab[]): number {
  const income = Math.max(0, annualIncome);
  let tax = 0;
  for (const slab of slabs) {
    const upper = slab.upper == null ? Infinity : slab.upper;
    if (income <= slab.lower) continue;
    const taxable = Math.min(income, upper) - slab.lower;
    if (taxable > 0) tax += taxable * Math.max(0, slab.rate);
  }
  return round2(tax);
}

/**
 * Projected-annual/12 monthly TDS (follow-up model). `monthlyTaxable` is projected
 * over `monthsInYear` (default 12), taxed by the progressive `slabs`, reduced by an
 * optional `rebate` (floored at 0), then spread over `remainingMonths` (default 12).
 * Deploy-safe: no slabs → 0. All figures are arguments — no tax constant is baked in.
 */
export function projectedAnnualTds(
  monthlyTaxable: number,
  slabs: TaxSlab[],
  opts: { monthsInYear?: number; remainingMonths?: number; rebate?: number } = {},
): number {
  const monthsInYear = opts.monthsInYear ?? 12;
  const remainingMonths = opts.remainingMonths ?? 12;
  const rebate = Math.max(0, opts.rebate ?? 0);
  if (slabs.length === 0 || remainingMonths <= 0) return 0;

  const projectedAnnual = Math.max(0, monthlyTaxable) * monthsInYear;
  const annualTax = Math.max(0, annualTaxFromSlabs(projectedAnnual, slabs) - rebate);
  return round2(annualTax / remainingMonths);
}
