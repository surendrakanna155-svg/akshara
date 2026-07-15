// Cap 73 (owner decision #5) — mid-year admission fee proration.
//
// Pure, deterministic calculation. No DB access here on purpose: the caller
// (finance_assignments_repository.ts) resolves the configured policy (via
// finance_settings_repository.getFinanceSettingValue) and the academic year's
// [start_date, end_date] bounds (via academic_years_repository.getAcademicYear),
// then hands both in as plain values. That keeps this module trivially unit
// testable and keeps every DB round-trip in one place.
//
// ─── Policy ──────────────────────────────────────────────────────────────
//   full_annual                 — bill the whole year (TODAY'S BEHAVIOUR).
//                                  DEFAULT — a school that never configures
//                                  this setting sees NO change in billing.
//   prorate_from_admission_month — bill only the months from the admission
//                                  month through the academic year's last
//                                  month (inclusive).
//
// ─── Basis: MONTH, not day ───────────────────────────────────────────────
// A day-based basis would have to answer "how many days is a month worth" —
// which forces either a 30/360 convention (never matches a real calendar) or
// exact calendar-day counting (which makes Feb 28/29 and 30- vs 31-day months
// charge different amounts for admissions that are, in every school's actual
// billing practice, "the same month"). A MONTH-based basis sidesteps all of
// that: an admission on the 1st and the 28th of the same month charge
// IDENTICALLY, the policy is trivially explainable to a non-technical school
// admin ("8 of 12 months charged"), and it is what every real fee-proration
// convention we could find (see the QP direction research) actually uses.
// The tradeoff — no sub-month precision — is exactly what a fee policy needs;
// nobody expects to be billed for "3.2 months".
//
// ─── No paise drift ──────────────────────────────────────────────────────
// `splitEvenly` mirrors `buildInstallmentPlan` in
// finance_installments_repository.ts EXACTLY (same "round every share, let
// the LAST share absorb the remainder" idiom already certified in this
// codebase for splitting a NUMERIC(12,2) total across N periods). Because the
// charged amount and the skipped amount are two contiguous slices of the SAME
// share array, `charged + skipped === annualAmount` HOLDS EXACTLY for every
// possible split point — not just at the boundaries — with no separate
// reconciliation step required.

export type FeeProrationPolicy = "full_annual" | "prorate_from_admission_month";

export const DEFAULT_FEE_PRORATION_POLICY: FeeProrationPolicy = "full_annual";

/** Where the policy lives — finance_settings, reusing FIN-6's home exactly. */
export const FEE_PRORATION_SETTING = {
  sectionId: "payments",
  itemId: "midyear_admission_proration_policy",
} as const;

const KNOWN_POLICIES: ReadonlySet<string> = new Set<FeeProrationPolicy>([
  "full_annual",
  "prorate_from_admission_month",
]);

/**
 * Parses a stored/override policy value, falling back to the safe default on
 * anything unrecognised (typo'd setting, stale value, etc.) rather than
 * throwing — a malformed config must never block a fee assignment, and must
 * never silently invent a NEW, unreviewed billing behaviour.
 */
export function parseFeeProrationPolicy(
  value: string | null | undefined,
): FeeProrationPolicy {
  const trimmed = (value ?? "").trim();
  return KNOWN_POLICIES.has(trimmed)
    ? (trimmed as FeeProrationPolicy)
    : DEFAULT_FEE_PRORATION_POLICY;
}

export class FeeProrationOverrideReasonRequiredError extends Error {
  constructor() {
    super(
      "A reason is required when overriding the mid-year admission fee proration policy",
    );
    this.name = "FeeProrationOverrideReasonRequiredError";
  }
}

export interface FeeProrationYearBounds {
  /** 'YYYY-MM-DD' (or any ISO string — only the first 7 chars are read). */
  startDate: string;
  endDate: string;
}

export interface FeeProrationInput {
  /** The policy to apply — already resolved by the caller (override ?? configured). */
  policy: FeeProrationPolicy;
  /** The fee structure's full annual total (NUMERIC(12,2)-valid number). */
  annualAmount: number;
  /** The admission/assignment reference date, 'YYYY-MM-DD'. */
  referenceDate: string;
  /** Null when the structure's academic year can't be resolved to real dates. */
  yearBounds: FeeProrationYearBounds | null;
  /** True when an authorized user explicitly chose a policy for this one assignment. */
  isOverride?: boolean;
  /** Required (enforced by the caller) whenever isOverride is true. */
  overrideReason?: string | null;
}

export interface FeeProrationResult {
  /** The policy actually applied (may differ from `policy` on fallback — see fallbackReason). */
  policy: FeeProrationPolicy;
  basis: "month";
  totalMonths: number;
  monthsCharged: number;
  referenceDate: string;
  annualAmount: number;
  chargedAmount: number;
  isOverride: boolean;
  overrideReason: string | null;
  /** Non-null only when prorate was requested but couldn't be computed (no year bounds). */
  fallbackReason: "academic_year_bounds_unavailable" | null;
}

/** Round to 2 decimals to keep NUMERIC(12,2) exact (same idiom as every other finance_*.ts file). */
function round2(n: number): number {
  return Math.round((n + Number.EPSILON) * 100) / 100;
}

function yearMonthOf(dateStr: string): { year: number; month: number } {
  const [y, m] = dateStr.slice(0, 7).split("-").map((v) => parseInt(v, 10));
  return { year: y, month: m };
}

/**
 * 1-based index of the calendar month containing `dateStr` within the
 * academic year starting in the month of `startStr` (e.g. an April-start year:
 * April → 1, May → 2, ..., the following March → 12). Pure calendar-month
 * arithmetic — deliberately ignores day-of-month (see module header).
 */
function monthIndexWithin(dateStr: string, startStr: string): number {
  const d = yearMonthOf(dateStr);
  const s = yearMonthOf(startStr);
  return (d.year - s.year) * 12 + (d.month - s.month) + 1;
}

function totalMonthsBetween(bounds: FeeProrationYearBounds): number {
  return Math.max(1, monthIndexWithin(bounds.endDate, bounds.startDate));
}

/**
 * Splits `total` into `count` equal monthly shares whose SUM is EXACTLY
 * `total` (the last share absorbs the rounding remainder). Mirrors
 * `buildInstallmentPlan` in finance_installments_repository.ts.
 */
function splitEvenly(total: number, count: number): number[] {
  const per = round2(total / count);
  const shares: number[] = [];
  let allocated = 0;
  for (let i = 0; i < count; i++) {
    const isLast = i === count - 1;
    const amount = isLast ? round2(total - allocated) : per;
    allocated = round2(allocated + amount);
    shares.push(amount);
  }
  return shares;
}

function sumShares(shares: number[]): number {
  let sum = 0;
  for (const share of shares) sum = round2(sum + share);
  return sum;
}

/**
 * Computes the mid-year admission proration for one fee assignment.
 *
 * Fail-safe by construction: `prorate_from_admission_month` can only be
 * applied when `yearBounds` is known (the fee structure resolved a real
 * academic year). Without it, this NEVER guesses a window — it falls back to
 * `full_annual` (today's behaviour) and reports why via `fallbackReason`, so
 * a data gap can only ever make a bill MORE generous to the school's own
 * default, never silently under- or over-charge a family.
 */
export function computeFeeProration(
  input: FeeProrationInput,
): FeeProrationResult {
  const annualAmount = round2(input.annualAmount);
  const isOverride = input.isOverride ?? false;
  const overrideReason = isOverride ? (input.overrideReason ?? "") : null;

  const wantsProration = input.policy === "prorate_from_admission_month";
  const canProrate = wantsProration && input.yearBounds != null;
  const fallbackReason = wantsProration && !canProrate
    ? "academic_year_bounds_unavailable" as const
    : null;

  if (!canProrate) {
    // full_annual (explicit) or a forced fallback — bill the whole year.
    const totalMonths = input.yearBounds
      ? totalMonthsBetween(input.yearBounds)
      : 1;
    return {
      policy: "full_annual",
      basis: "month",
      totalMonths,
      monthsCharged: totalMonths,
      referenceDate: input.referenceDate,
      annualAmount,
      chargedAmount: annualAmount,
      isOverride,
      overrideReason,
      fallbackReason,
    };
  }

  const bounds = input.yearBounds!;
  const totalMonths = totalMonthsBetween(bounds);
  const rawIndex = monthIndexWithin(input.referenceDate, bounds.startDate);
  // Clamp: an admission dated before the year starts still gets the FULL
  // year (index floors at 1); one dated after the year already ended still
  // gets a minimum of one month charged (index caps at totalMonths) — a
  // degenerate/likely-mis-keyed date must never produce a zero-rupee invoice.
  const clampedIndex = Math.min(Math.max(rawIndex, 1), totalMonths);
  const monthsCharged = totalMonths - clampedIndex + 1;

  const shares = splitEvenly(annualAmount, totalMonths);
  const skippedCount = totalMonths - monthsCharged;
  const chargedAmount = sumShares(shares.slice(skippedCount));

  return {
    policy: "prorate_from_admission_month",
    basis: "month",
    totalMonths,
    monthsCharged,
    referenceDate: input.referenceDate,
    annualAmount,
    chargedAmount,
    isOverride,
    overrideReason,
    fallbackReason: null,
  };
}
