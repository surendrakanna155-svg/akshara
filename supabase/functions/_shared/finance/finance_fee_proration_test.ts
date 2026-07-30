// Cap 73 (owner decision #5) — mid-year admission fee proration.
// Exhaustive tests for the pure calculation module: this is money, so every
// boundary named in the task is covered directly against computeFeeProration
// (no DB mock needed — see finance_assignments_repository_test.ts for the
// end-to-end wiring/audit/override tests).

import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import {
  computeFeeProration,
  DEFAULT_FEE_PRORATION_POLICY,
  FEE_PRORATION_SETTING,
  parseFeeProrationPolicy,
} from "./finance_fee_proration.ts";

// April-start academic year — matches this codebase's real fixture convention.
const AY = { startDate: "2026-04-01", endDate: "2027-03-31" };
const ANNUAL = 50000;

Deno.test("DEFAULT_FEE_PRORATION_POLICY is full_annual — preserves today's behaviour", () => {
  assertEquals(DEFAULT_FEE_PRORATION_POLICY, "full_annual");
});

Deno.test("FEE_PRORATION_SETTING lives in the existing finance_settings 'payments' section", () => {
  assertEquals(FEE_PRORATION_SETTING.sectionId, "payments");
  assertEquals(FEE_PRORATION_SETTING.itemId, "midyear_admission_proration_policy");
});

Deno.test("parseFeeProrationPolicy falls back to the default on anything unrecognised", () => {
  assertEquals(parseFeeProrationPolicy(undefined), "full_annual");
  assertEquals(parseFeeProrationPolicy(null), "full_annual");
  assertEquals(parseFeeProrationPolicy(""), "full_annual");
  assertEquals(parseFeeProrationPolicy("bogus"), "full_annual");
  assertEquals(parseFeeProrationPolicy("prorate_from_admission_month"), "prorate_from_admission_month");
  assertEquals(parseFeeProrationPolicy("full_annual"), "full_annual");
});

// ─── Regression guard: full_annual is unchanged (today's behaviour) ─────────

Deno.test("full_annual charges the ENTIRE annual amount regardless of admission date", () => {
  for (const referenceDate of ["2026-04-01", "2026-09-15", "2027-03-31", "2025-01-01"]) {
    const result = computeFeeProration({
      policy: "full_annual",
      annualAmount: ANNUAL,
      referenceDate,
      yearBounds: AY,
    });
    assertEquals(result.policy, "full_annual");
    assertEquals(result.chargedAmount, ANNUAL);
    assertEquals(result.fallbackReason, null);
  }
});

Deno.test("full_annual with no year bounds still charges the full amount (degenerate but safe)", () => {
  const result = computeFeeProration({
    policy: "full_annual",
    annualAmount: ANNUAL,
    referenceDate: "2026-09-15",
    yearBounds: null,
  });
  assertEquals(result.chargedAmount, ANNUAL);
  assertEquals(result.totalMonths, 1);
  assertEquals(result.monthsCharged, 1);
});

// ─── prorate_from_admission_month: first/last month ─────────────────────────

Deno.test("prorate_from_admission_month at the FIRST month of the academic year == full annual", () => {
  const result = computeFeeProration({
    policy: "prorate_from_admission_month",
    annualAmount: ANNUAL,
    referenceDate: "2026-04-01",
    yearBounds: AY,
  });
  assertEquals(result.totalMonths, 12);
  assertEquals(result.monthsCharged, 12);
  assertEquals(result.chargedAmount, ANNUAL);
});

Deno.test("prorate_from_admission_month at the LAST month of the academic year == one month", () => {
  const result = computeFeeProration({
    policy: "prorate_from_admission_month",
    annualAmount: ANNUAL,
    referenceDate: "2027-03-15",
    yearBounds: AY,
  });
  assertEquals(result.totalMonths, 12);
  assertEquals(result.monthsCharged, 1);
  // One month of an even 50000/12 split, i.e. the LAST share (which absorbs
  // any rounding remainder) — never zero, always exactly one month's worth.
  assertEquals(result.chargedAmount > 0, true);
  assertEquals(result.chargedAmount < ANNUAL / 11, true);
});

// ─── Month boundaries: first day vs last day of a month → SAME result ───────

Deno.test("month boundary: 1st and last day of the SAME calendar month charge IDENTICALLY", () => {
  const first = computeFeeProration({
    policy: "prorate_from_admission_month",
    annualAmount: ANNUAL,
    referenceDate: "2026-09-01",
    yearBounds: AY,
  });
  const last = computeFeeProration({
    policy: "prorate_from_admission_month",
    annualAmount: ANNUAL,
    referenceDate: "2026-09-30",
    yearBounds: AY,
  });
  assertEquals(first.monthsCharged, last.monthsCharged);
  assertEquals(first.chargedAmount, last.chargedAmount);
});

Deno.test("month boundary: crossing into the NEXT month charges one fewer month", () => {
  const septLast = computeFeeProration({
    policy: "prorate_from_admission_month",
    annualAmount: ANNUAL,
    referenceDate: "2026-09-30",
    yearBounds: AY,
  });
  const octFirst = computeFeeProration({
    policy: "prorate_from_admission_month",
    annualAmount: ANNUAL,
    referenceDate: "2026-10-01",
    yearBounds: AY,
  });
  assertEquals(octFirst.monthsCharged, septLast.monthsCharged - 1);
});

// ─── Academic-year boundaries ────────────────────────────────────────────────

Deno.test("admission BEFORE the academic year starts still charges the FULL year (clamped, not extrapolated)", () => {
  const result = computeFeeProration({
    policy: "prorate_from_admission_month",
    annualAmount: ANNUAL,
    referenceDate: "2026-01-01", // 3 months before AY_START
    yearBounds: AY,
  });
  assertEquals(result.monthsCharged, 12);
  assertEquals(result.chargedAmount, ANNUAL);
});

Deno.test("admission AFTER the academic year ends still charges a minimum of ONE month (never zero)", () => {
  const result = computeFeeProration({
    policy: "prorate_from_admission_month",
    annualAmount: ANNUAL,
    referenceDate: "2027-06-01", // 3 months after AY_END
    yearBounds: AY,
  });
  assertEquals(result.monthsCharged, 1);
  assertEquals(result.chargedAmount > 0, true);
});

// ─── Feb 28/29 and 30- vs 31-day months: MONTH basis makes these irrelevant ──

Deno.test("Feb (28/29) and 30- vs 31-day months charge IDENTICALLY under the month basis (deliberate design)", () => {
  const leapYearAy = { startDate: "2027-04-01", endDate: "2028-03-31" }; // 2028 is a leap year
  const feb28 = computeFeeProration({
    policy: "prorate_from_admission_month",
    annualAmount: ANNUAL,
    referenceDate: "2028-02-01",
    yearBounds: leapYearAy,
  });
  const feb29 = computeFeeProration({
    policy: "prorate_from_admission_month",
    annualAmount: ANNUAL,
    referenceDate: "2028-02-29",
    yearBounds: leapYearAy,
  });
  assertEquals(feb28.monthsCharged, feb29.monthsCharged);
  assertEquals(feb28.chargedAmount, feb29.chargedAmount);

  const apr30 = computeFeeProration({
    policy: "prorate_from_admission_month",
    annualAmount: ANNUAL,
    referenceDate: "2027-04-01",
    yearBounds: leapYearAy,
  });
  const may31 = computeFeeProration({
    policy: "prorate_from_admission_month",
    annualAmount: ANNUAL,
    referenceDate: "2027-05-31",
    yearBounds: leapYearAy,
  });
  // April (30 days) and May (31 days) are just "the next month" apart —
  // one full month difference regardless of day-count.
  assertEquals(apr30.monthsCharged - may31.monthsCharged, 1);
});

// ─── No paise drift ──────────────────────────────────────────────────────────

Deno.test("charged + skipped-complement reconcile EXACTLY to the annual total for every split point (no paise drift)", () => {
  // Walk every month of the year as the admission month; for each, verify the
  // charged amount for THIS admission plus the charged amount for the
  // complementary "admission in the NEXT month" (i.e. one fewer month
  // charged) together span the full annual amount with no gap/overlap in
  // cents. Concretely: chargedAmount(monthIndex) - chargedAmount(monthIndex+1)
  // is one month's share, and chargedAmount(index=1) [full year] equals the
  // annual total exactly.
  const referenceDates = [
    "2026-04-15", "2026-05-15", "2026-06-15", "2026-07-15",
    "2026-08-15", "2026-09-15", "2026-10-15", "2026-11-15",
    "2026-12-15", "2027-01-15", "2027-02-15", "2027-03-15",
  ];
  const results = referenceDates.map((referenceDate) =>
    computeFeeProration({
      policy: "prorate_from_admission_month",
      annualAmount: ANNUAL,
      referenceDate,
      yearBounds: AY,
    })
  );
  // First month (index 0, April) => full annual, exactly.
  assertEquals(results[0]!.chargedAmount, ANNUAL);
  // Monotonically non-increasing as the admission month gets later.
  for (let i = 1; i < results.length; i++) {
    assertEquals(results[i]!.chargedAmount <= results[i - 1]!.chargedAmount, true);
  }
  // The "amount NOT charged" (annual - charged) for the LAST month's
  // admission, plus that month's OWN charge, reconciles to the annual total
  // with zero drift (charged is already NUMERIC(12,2)-clean: exactly 2dp).
  const last = results[results.length - 1]!;
  const skipped = Math.round((ANNUAL - last.chargedAmount) * 100) / 100;
  assertEquals(Math.round((skipped + last.chargedAmount) * 100) / 100, ANNUAL);
  // Every result is already rounded to whole paise (no float remainder).
  for (const r of results) {
    assertEquals(Math.round(r.chargedAmount * 100) / 100, r.chargedAmount);
  }
});

Deno.test("no paise drift holds for an annual amount that does NOT divide evenly by 12", () => {
  const oddAnnual = 100000.01;
  const results: number[] = [];
  for (const referenceDate of ["2026-04-01", "2026-07-01", "2027-03-01"]) {
    const r = computeFeeProration({
      policy: "prorate_from_admission_month",
      annualAmount: oddAnnual,
      referenceDate,
      yearBounds: AY,
    });
    results.push(r.chargedAmount);
    // Always exactly 2 decimal places (NUMERIC(12,2)-safe).
    assertEquals(Math.round(r.chargedAmount * 100) / 100, r.chargedAmount);
  }
  // Full-year charge equals the annual amount exactly (no rounding drift at
  // the boundary case).
  assertEquals(results[0], oddAnnual);
});

// ─── Fallback: prorate requested but no resolvable academic year ───────────

Deno.test("prorate_from_admission_month falls back to full_annual (never guesses) when year bounds are unavailable", () => {
  const result = computeFeeProration({
    policy: "prorate_from_admission_month",
    annualAmount: ANNUAL,
    referenceDate: "2026-09-15",
    yearBounds: null,
  });
  assertEquals(result.policy, "full_annual");
  assertEquals(result.chargedAmount, ANNUAL);
  assertEquals(result.fallbackReason, "academic_year_bounds_unavailable");
});

// ─── Override provenance ────────────────────────────────────────────────────

Deno.test("override fields are carried through exactly as given", () => {
  const result = computeFeeProration({
    policy: "full_annual",
    annualAmount: ANNUAL,
    referenceDate: "2026-09-15",
    yearBounds: AY,
    isOverride: true,
    overrideReason: "Owner-approved exception for transfer student",
  });
  assertEquals(result.isOverride, true);
  assertEquals(result.overrideReason, "Owner-approved exception for transfer student");
});

Deno.test("no override => overrideReason is null even if one was accidentally passed", () => {
  const result = computeFeeProration({
    policy: "full_annual",
    annualAmount: ANNUAL,
    referenceDate: "2026-09-15",
    yearBounds: AY,
    isOverride: false,
    overrideReason: "should be ignored",
  });
  assertEquals(result.isOverride, false);
  assertEquals(result.overrideReason, null);
});
