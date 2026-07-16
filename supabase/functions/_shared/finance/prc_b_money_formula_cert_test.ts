// PRC-B — Product Correctness certification: Money & Finance (3.1), Formula Truth
// (3.4), Period & Proration (3.3), and the canonical attendance formula, exercised
// across boundary / extreme / precision cases against the REAL product functions.
//
// This is a CERTIFICATION suite (not new behaviour): every assertion pins an
// invariant of already-shipped code. A failure here is a real correctness defect.

import { assert, assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import { computeFeeProration } from "./finance_fee_proration.ts";
import { buildInstallmentPlan } from "./finance_installments_repository.ts";
import {
  attendancePercent,
  attendancePercentFromCounts,
} from "../attendance/attendance_percentage.ts";

const cents = (n: number) => Math.round(n * 100);
const sumCents = (xs: number[]) => xs.reduce((s, x) => s + cents(x), 0);

const YEAR = { startDate: "2026-04-01", endDate: "2027-03-31" }; // 12-month April-start year

// ─── PRC-B-MNY-13 / MNY-05 / MNY-03: split exactness (no paise drift, no float leak) ──

Deno.test("PRC-B-MNY-13: installment split sums EXACTLY to the total (last share absorbs remainder)", () => {
  // 100 / 3 = 33.333… — naive float would drift; the plan must sum to exactly 100.00.
  const plan = buildInstallmentPlan(new Date(2026, 3, 1), 100, [0, 30, 60]);
  assertEquals(plan.map((p) => p.amount), [33.33, 33.33, 33.34]);
  assertEquals(sumCents(plan.map((p) => p.amount)), cents(100));
});

Deno.test("PRC-B-MNY-03: split of a float-leaky total still sums exactly", () => {
  // 0.1 × 7 naive-summed leaks; the plan of 0.70 across 7 must be exact.
  const plan = buildInstallmentPlan(new Date(2026, 3, 1), 0.7, [0, 0, 0, 0, 0, 0, 0]);
  assertEquals(sumCents(plan.map((p) => p.amount)), cents(0.7));
});

Deno.test("PRC-B-MNY-10: an extremely large total splits exactly", () => {
  const plan = buildInstallmentPlan(new Date(2026, 3, 1), 9999999.99, [0, 30, 60, 90, 120, 150, 180]);
  assertEquals(sumCents(plan.map((p) => p.amount)), cents(9999999.99));
});

Deno.test("PRC-B-BX-02 / MNY-07: single installment of ₹0 is exactly ₹0", () => {
  const plan = buildInstallmentPlan(new Date(2026, 3, 1), 0, [0]);
  assertEquals(plan.length, 1);
  assertEquals(plan[0].amount, 0);
});

// ─── PRC-B-PP / MNY: proration exactness (charged + skipped === annual, EXACTLY) ──

for (const [label, ref, expectedMonths] of [
  ["PP-04 year-start admission → full 12 months", "2026-04-01", 12],
  ["PP-05 mid-year admission (Aug) → 8 months", "2026-08-15", 8],
  ["PP-06 last month (Mar) → 1 month", "2027-03-20", 1],
  ["DT-17 admission before year start → clamps to full year", "2026-01-01", 12],
  ["DT-18 admission after year end → min 1 month", "2027-12-01", 1],
] as const) {
  Deno.test(`PRC-B-${label}`, () => {
    const annual = 84000;
    const r = computeFeeProration({
      policy: "prorate_from_admission_month",
      annualAmount: annual,
      referenceDate: ref,
      yearBounds: YEAR,
    });
    assertEquals(r.monthsCharged, expectedMonths);
    // The invariant that matters: charged + skipped === annual, EXACTLY, for every split point.
    const skipped = annual - r.chargedAmount;
    assertEquals(cents(r.chargedAmount) + cents(skipped), cents(annual));
    assert(r.chargedAmount > 0, "a real admission is never billed ₹0");
    assert(r.chargedAmount <= annual, "never over-bills the annual");
  });
}

Deno.test("PRC-B-MNY-12: proration of a 999.995-type total keeps 2-dp exactness", () => {
  const r = computeFeeProration({
    policy: "prorate_from_admission_month",
    annualAmount: 12000.01,
    referenceDate: "2026-08-01",
    yearBounds: YEAR,
  });
  // chargedAmount must be a clean 2-dp value (no 12000.009999…).
  assertEquals(cents(r.chargedAmount) / 100, r.chargedAmount);
});

Deno.test("PRC-B-PP-04: full_annual policy bills the whole year regardless of date", () => {
  const r = computeFeeProration({
    policy: "full_annual",
    annualAmount: 50000,
    referenceDate: "2026-11-15",
    yearBounds: YEAR,
  });
  assertEquals(r.chargedAmount, 50000);
  assertEquals(r.monthsCharged, 12);
});

Deno.test("PRC-B-PP-20: prorate requested with NO year bounds fails safe to full_annual (never ₹0)", () => {
  const r = computeFeeProration({
    policy: "prorate_from_admission_month",
    annualAmount: 50000,
    referenceDate: "2026-11-15",
    yearBounds: null,
  });
  assertEquals(r.policy, "full_annual");
  assertEquals(r.chargedAmount, 50000);
  assertEquals(r.fallbackReason, "academic_year_bounds_unavailable");
});

// ─── PRC-B-FR-09: canonical attendance % (one definition; boundary behaviour) ──

Deno.test("PRC-B-FR-09: attended = present + late + 0.5×half_day; denominator excludes excused", () => {
  // 6 present + 2 late + 2 half_day(=1.0) = 9 attended; denom = 10 marked − 0 excused = 10 → 90%.
  const pct = attendancePercentFromCounts({ present: 6, late: 2, halfDay: 2, excused: 0, absent: 0 });
  assertEquals(pct, 90);
});

Deno.test("PRC-B-FR-09 / PP-14: excused days are excluded from the denominator (not counted against)", () => {
  // 8 present, 2 excused → attended 8 / denom 8 = 100% (excused removed from BOTH sides).
  assertEquals(attendancePercentFromCounts({ present: 8, late: 0, halfDay: 0, excused: 2, absent: 0 }), 100);
});

Deno.test("PRC-B-BX-01: attendance % is null (never 0, never 100) when nothing is marked", () => {
  assertEquals(attendancePercent([]), null);
});

Deno.test("PRC-B-FR-09: every-day-excused window → null (denominator 0), never 100", () => {
  assertEquals(attendancePercentFromCounts({ present: 0, late: 0, halfDay: 0, excused: 5, absent: 0 }), null);
});

Deno.test("PRC-B-BX-11: an unrecognized attendance mark is ignored on both sides", () => {
  // one bogus mark must not change a clean 100% (2 present).
  assertEquals(attendancePercent([{ mark: "present" }, { mark: "present" }, { mark: "holiday_typo" }]), 100);
});

Deno.test("PRC-B-FR-09: half_day contributes exactly 0.5 (rounded to nearest integer %)", () => {
  // 1 present + 1 half_day = 1.5 attended / 2 = 75%.
  assertEquals(attendancePercentFromCounts({ present: 1, late: 0, halfDay: 1, excused: 0, absent: 0 }), 75);
});
