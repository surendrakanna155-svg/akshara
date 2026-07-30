// PRA-P1-35 (Owner decision #9, FINAL) — statutory payroll engine: PURE tests.
//
// The heart of the feature. Proves the arithmetic + ceilings + eligibility gates +
// per-state PT slabs DB-free, and that the config is DATA (a rate of 0 → 0
// deduction). Nothing here is a fabricated compliance number — every rate/ceiling/
// slab is passed in as config, exactly as the DB rows feed the engine at runtime.

import { assertAlmostEquals, assertEquals } from "jsr:@std/assert@1";
import {
  annualTaxFromSlabs,
  computePtFromSlabs,
  computeRateComponent,
  computeStatutoryDeductions,
  deriveStatutoryLiabilities,
  monthFromPeriod,
  projectedAnnualTds,
  type PtSlab,
  type StatutoryComponentConfig,
  type TaxSlab,
} from "./statutory_payroll.ts";
import { generatePayrollRun } from "./hr_write_handlers.ts";

// ── config builders (all numbers supplied — never hardcoded in the engine) ─────
function cfg(over: Partial<StatutoryComponentConfig> = {}): StatutoryComponentConfig {
  return {
    component: "pf",
    state: "",
    employeeRate: 0,
    employerRate: 0,
    wageBase: "gross",
    baseCap: null,
    eligibilityCeiling: null,
    eligibilityFloor: null,
    flatEmployee: null,
    flatEmployer: null,
    rounding: "nearest",
    active: true,
    ...over,
  };
}

const PF = (over: Partial<StatutoryComponentConfig> = {}) =>
  cfg({ component: "pf", wageBase: "basic", employeeRate: 0.12, employerRate: 0.12, baseCap: 15000, ...over });
const ESI = (over: Partial<StatutoryComponentConfig> = {}) =>
  cfg({ component: "esi", wageBase: "gross", employeeRate: 0.0075, employerRate: 0.0325, eligibilityCeiling: 21000, rounding: "up", ...over });
const PT = (over: Partial<StatutoryComponentConfig> = {}) =>
  cfg({ component: "pt", state: "KA", wageBase: "gross", ...over });
const TDS = (over: Partial<StatutoryComponentConfig> = {}) =>
  cfg({ component: "tds", wageBase: "gross", ...over });

// Karnataka-shaped PT slabs (values are config DATA supplied by the test, not the engine).
const KA_SLABS: PtSlab[] = [
  { state: "KA", lowerBound: 0, upperBound: 14999.99, amount: 0, month: null },
  { state: "KA", lowerBound: 15000, upperBound: null, amount: 200, month: null },
  { state: "KA", lowerBound: 15000, upperBound: null, amount: 300, month: 2 }, // special February slab
];

// ── PF — 12% on the PF-wage, capped at the base ceiling (employee + employer) ──

Deno.test("PF: below the base cap deducts rate × full basic (employee + employer)", () => {
  const r = computeRateComponent(PF(), { basic: 12000, allowances: 8000 });
  assertEquals(r.base, 12000); // PF is on basic, not gross
  assertEquals(r.employee, 1440); // 12% of 12000
  assertEquals(r.employer, 1440);
  assertEquals(r.eligible, true);
});

Deno.test("PF: above the base cap deducts rate × the CAP (₹15,000), not full basic", () => {
  const r = computeRateComponent(PF(), { basic: 30000, allowances: 10000 });
  assertEquals(r.base, 15000); // capped
  assertEquals(r.employee, 1800); // 12% of 15000
  assertEquals(r.employer, 1800);
});

Deno.test("PF: exactly at the cap uses the cap (boundary)", () => {
  const r = computeRateComponent(PF(), { basic: 15000, allowances: 0 });
  assertEquals(r.base, 15000);
  assertEquals(r.employee, 1800);
});

Deno.test("PF: zero rate config → zero deduction (deploy-safe)", () => {
  const r = computeRateComponent(PF({ employeeRate: 0, employerRate: 0 }), { basic: 30000, allowances: 0 });
  assertEquals(r.employee, 0);
  assertEquals(r.employer, 0);
  assertEquals(r.eligible, true); // eligible, but rate 0 → nothing deducted
});

// ── ESI — on gross up to the ELIGIBILITY ceiling; both shares; round UP ────────

Deno.test("ESI: eligible (gross ≤ ceiling) deducts rate × FULL gross (no base cap)", () => {
  const r = computeRateComponent(ESI(), { basic: 15000, allowances: 5000 }); // gross 20000
  assertEquals(r.base, 20000);
  assertEquals(r.employee, 150); // 0.75% of 20000 = 150
  assertEquals(r.employer, 650); // 3.25% of 20000 = 650
  assertEquals(r.eligible, true);
});

Deno.test("ESI: over the eligibility ceiling → the component does NOT apply at all", () => {
  const r = computeRateComponent(ESI(), { basic: 20000, allowances: 5000 }); // gross 25000 > 21000
  assertEquals(r.base, 0);
  assertEquals(r.employee, 0);
  assertEquals(r.employer, 0);
  assertEquals(r.eligible, false);
});

Deno.test("ESI: exactly at the ceiling is still eligible (boundary), rounded UP to the next rupee", () => {
  const r = computeRateComponent(ESI(), { basic: 21000, allowances: 0 }); // gross exactly 21000
  assertEquals(r.eligible, true);
  assertEquals(r.employee, 158); // 0.75% of 21000 = 157.5 → ceil 158
  assertEquals(r.employer, 683); // 3.25% of 21000 = 682.5 → ceil 683
});

Deno.test("ESI: round-up mode ceils a fractional share to the next rupee", () => {
  const r = computeRateComponent(ESI(), { basic: 17500, allowances: 0 }); // gross 17500
  assertEquals(r.employee, 132); // 0.75% of 17500 = 131.25 → ceil 132
});

// ── PT — per-state flat slab on gross (employee-only), boundaries + special month

Deno.test("PT: picks the slab whose band contains gross (employee-borne, no employer)", () => {
  const r = computePtFromSlabs(PT(), 20000, KA_SLABS, 7);
  assertEquals(r.employee, 200);
  assertEquals(r.employer, 0);
  assertEquals(r.eligible, true);
});

Deno.test("PT: below the taxable band → 0", () => {
  const r = computePtFromSlabs(PT(), 10000, KA_SLABS, 7);
  assertEquals(r.employee, 0);
});

Deno.test("PT: slab boundary — exactly at a slab's lower bound falls in that slab", () => {
  assertEquals(computePtFromSlabs(PT(), 15000, KA_SLABS, 7).employee, 200); // lower bound of 200 slab
  assertEquals(computePtFromSlabs(PT(), 14999, KA_SLABS, 7).employee, 0); // still in the 0 slab
});

Deno.test("PT: a special-month slab overrides the month-agnostic slab for that month only", () => {
  assertEquals(computePtFromSlabs(PT(), 20000, KA_SLABS, 2).employee, 300); // February special
  assertEquals(computePtFromSlabs(PT(), 20000, KA_SLABS, 3).employee, 200); // March → default
});

Deno.test("PT: no slab configured for the state → 0 (unless a flat fallback is set)", () => {
  assertEquals(computePtFromSlabs(PT({ state: "MH" }), 20000, KA_SLABS, 7).employee, 0);
  assertEquals(computePtFromSlabs(PT({ state: "MH", flatEmployee: 150 }), 20000, [], 7).employee, 150);
});

// ── TDS — configurable flat rate / flat amount (the chosen monthly model) ──────

Deno.test("TDS: flat-rate model deducts rate × gross (configurable)", () => {
  const r = computeRateComponent(TDS({ employeeRate: 0.1 }), { basic: 40000, allowances: 10000 }); // gross 50000
  assertEquals(r.employee, 5000); // 10% of 50000
  assertEquals(r.employer, 0);
});

Deno.test("TDS: flat AMOUNT override deducts the fixed monthly figure", () => {
  const r = computeRateComponent(TDS({ flatEmployee: 2500 }), { basic: 60000, allowances: 20000 });
  assertEquals(r.employee, 2500);
});

Deno.test("TDS: zero rate → zero (deploy-safe; no tax number guessed)", () => {
  assertEquals(computeRateComponent(TDS(), { basic: 40000, allowances: 10000 }).employee, 0);
});

// ── zero-config = zero deduction (the deploy-safe invariant) ───────────────────

Deno.test("computeStatutoryDeductions: NO config → zero components, zero totals", () => {
  const r = computeStatutoryDeductions({ basic: 40000, allowances: 10000 }, []);
  assertEquals(r.components.length, 0);
  assertEquals(r.employeeTotal, 0);
  assertEquals(r.employerTotal, 0);
  assertEquals(r.gross, 50000);
});

Deno.test("computeStatutoryDeductions: inactive config is skipped entirely", () => {
  const r = computeStatutoryDeductions({ basic: 30000, allowances: 0 }, [PF({ active: false })]);
  assertEquals(r.components.length, 0);
  assertEquals(r.employeeTotal, 0);
});

// ── jurisdiction matching — central applies everywhere, state only in-state ────

Deno.test("computeStatutoryDeductions: a state PT config does NOT apply in another state", () => {
  const r = computeStatutoryDeductions(
    { basic: 20000, allowances: 5000 },
    [PT({ state: "KA" })],
    { state: "MH", ptSlabs: KA_SLABS, month: 7 },
  );
  assertEquals(r.components.length, 0); // KA config filtered out for MH
});

Deno.test("computeStatutoryDeductions: central configs apply regardless of state", () => {
  const r = computeStatutoryDeductions(
    { basic: 12000, allowances: 3000 },
    [PF()],
    { state: "MH" },
  );
  assertEquals(r.components.length, 1);
  assertEquals(r.employeeTotal, 1440); // PF 12% of basic 12000
});

// ── full multi-component payslip totals ────────────────────────────────────────

Deno.test("computeStatutoryDeductions: PF + ESI + PT + TDS totals (mixed eligibility)", () => {
  // basic 18000, allowances 4000 → gross 22000. ESI ineligible (>21000);
  // PF on basic capped at 15000; PT slab (gross 22000 → 200); TDS flat 10% of gross.
  const r = computeStatutoryDeductions(
    { basic: 18000, allowances: 4000 },
    [PF(), ESI(), PT({ state: "KA" }), TDS({ employeeRate: 0.1 })],
    { state: "KA", ptSlabs: KA_SLABS, month: 7 },
  );
  const byComp = Object.fromEntries(r.components.map((c) => [c.component, c]));
  assertEquals(byComp.pf!.employee, 1800); // 12% of 15000 (capped)
  assertEquals(byComp.pf!.employer, 1800);
  assertEquals(byComp.esi!.eligible, false); // gross 22000 > 21000
  assertEquals(byComp.esi!.employee, 0);
  assertEquals(byComp.pt!.employee, 200);
  assertEquals(byComp.tds!.employee, 2200); // 10% of gross 22000
  assertEquals(r.employeeTotal, 1800 + 0 + 200 + 2200); // 4200
  assertEquals(r.employerTotal, 1800); // PF employer only
});

// ── deriveStatutoryLiabilities — aggregation for the remittance posting ─────────

Deno.test("deriveStatutoryLiabilities: sums employee + employer per component across entries", () => {
  const entries = [
    {
      statutory: [
        { component: "pf", state: "", employee: 1800, employer: 1800, eligible: true },
        { component: "pt", state: "KA", employee: 200, employer: 0, eligible: true },
      ],
    },
    {
      statutory: [
        { component: "pf", state: "", employee: 1200, employer: 1200, eligible: true },
        { component: "pt", state: "KA", employee: 200, employer: 0, eligible: true },
      ],
    },
  ];
  const liabilities = deriveStatutoryLiabilities(entries);
  const byComp = Object.fromEntries(liabilities.map((l) => [l.component, l]));
  assertEquals(byComp.pf!.employeeAmount, 3000);
  assertEquals(byComp.pf!.employerAmount, 3000);
  assertEquals(byComp.pf!.totalAmount, 6000); // both shares remitted to EPFO
  assertEquals(byComp.pf!.employeeCount, 2);
  assertEquals(byComp.pt!.employeeAmount, 400);
  assertEquals(byComp.pt!.employerAmount, 0);
  assertEquals(byComp.pt!.totalAmount, 400);
});

Deno.test("deriveStatutoryLiabilities: entries with no statutory breakdown → no liabilities", () => {
  assertEquals(deriveStatutoryLiabilities([{ netPay: 40000 }, { netPay: 30000 }]).length, 0);
});

Deno.test("deriveStatutoryLiabilities: all-zero components are not posted", () => {
  const entries = [{ statutory: [{ component: "tds", state: "", employee: 0, employer: 0, eligible: true }] }];
  assertEquals(deriveStatutoryLiabilities(entries).length, 0);
});

// ── monthFromPeriod ────────────────────────────────────────────────────────────

Deno.test("monthFromPeriod: parses ISO-month labels, null otherwise", () => {
  assertEquals(monthFromPeriod("2026-07"), 7);
  assertEquals(monthFromPeriod("2026-02-15"), 2);
  assertEquals(monthFromPeriod("May 2026"), null);
  assertEquals(monthFromPeriod("2026-13"), null);
});

// ── TDS follow-up model — projected-annual / 12 progressive slabs ──────────────

const TAX_SLABS: TaxSlab[] = [
  { lower: 0, upper: 300000, rate: 0 },
  { lower: 300000, upper: 600000, rate: 0.05 },
  { lower: 600000, upper: 900000, rate: 0.1 },
  { lower: 900000, upper: null, rate: 0.15 },
];

Deno.test("annualTaxFromSlabs: progressive — only income within each band is taxed", () => {
  // 700000 → 0 (first 3L) + 5% of 300000 (15000) + 10% of 100000 (10000) = 25000
  assertEquals(annualTaxFromSlabs(700000, TAX_SLABS), 25000);
  assertEquals(annualTaxFromSlabs(250000, TAX_SLABS), 0); // fully in the 0% band
});

Deno.test("projectedAnnualTds: annualise × 12, tax by slabs, spread over remaining months", () => {
  // monthly taxable 60000 → projected annual 720000 → 5%×300000 + 10%×120000 = 27000; /12 = 2250
  assertAlmostEquals(projectedAnnualTds(60000, TAX_SLABS, { remainingMonths: 12 }), 2250, 0.01);
});

Deno.test("projectedAnnualTds: a rebate reduces the annual tax (floored at 0)", () => {
  assertEquals(projectedAnnualTds(20000, TAX_SLABS, { remainingMonths: 12, rebate: 100000 }), 0);
});

Deno.test("projectedAnnualTds: no slabs configured → 0 (deploy-safe)", () => {
  assertEquals(projectedAnnualTds(60000, [], { remainingMonths: 12 }), 0);
});

// ── INTEGRATION — generatePayrollRun folds statutory into the money invariant ──

function structure(over: Record<string, unknown> = {}): Record<string, unknown> {
  return {
    employeeId: "e1",
    employeeCode: "EMP-1",
    employeeName: "Asha",
    department: "academics",
    basicPay: 20000,
    allowances: 5000, // gross 25000
    deductions: 0,
    ...over,
  };
}

Deno.test("integration: generatePayrollRun folds employee statutory into deductions, captures employer", () => {
  const snap = { structures: [structure()] };
  const { entries } = generatePayrollRun(snap, {
    runId: "r",
    period: "2026-07",
    statutory: {
      configs: [PF(), ESI(), PT({ state: "KA" }), TDS({ employeeRate: 0 })],
      ptSlabs: KA_SLABS,
      state: "KA",
      month: 7,
    },
  });
  const e = entries[0]!;
  // PF 12% of capped 15000 = 1800; ESI gross 25000 > 21000 → 0; PT 200; TDS 0.
  assertEquals(e.statutoryEmployee, 2000); // 1800 + 200
  assertEquals(e.statutoryEmployer, 1800); // PF employer only
  assertEquals(e.deductions, 2000); // structural(0) + lop(0) + statutory(2000)
  assertEquals(e.netPay, 25000 - 2000); // 23000
});

Deno.test("integration: no statutory config → entries unchanged (backwards compatible)", () => {
  const snap = { structures: [structure({ deductions: 1000 })] };
  const { entries } = generatePayrollRun(snap, { runId: "r", period: "2026-07" });
  const e = entries[0]!;
  assertEquals(e.statutoryEmployee, 0);
  assertEquals(e.statutoryEmployer, 0);
  assertEquals((e.statutory as unknown[]).length, 0);
  assertEquals(e.deductions, 1000); // structural only
  assertEquals(e.netPay, 25000 - 1000); // 24000
});

Deno.test("integration: statutory + LOP + structural all fold into one honest deduction", () => {
  const snap = { structures: [structure({ basicPay: 30000, allowances: 0, deductions: 500 })] }; // per-day 1000
  const attendance = { records: [{ employeeId: "e1", date: "2026-07-03", status: "absent" }] };
  const { entries } = generatePayrollRun(snap, {
    runId: "r",
    period: "2026-07",
    attendance,
    statutory: { configs: [PF()], state: "", month: 7 }, // PF 12% of capped 15000 = 1800
  });
  const e = entries[0]!;
  assertEquals(e.lopAmount, 1000); // 1 absent day
  assertEquals(e.statutoryEmployee, 1800);
  assertEquals(e.deductions, 500 + 1000 + 1800); // structural + lop + statutory = 3300
  assertEquals(e.netPay, 30000 - 3300); // 26700
});

Deno.test("integration: derived run liabilities aggregate the generated entries", () => {
  const snap = {
    structures: [
      structure({ employeeId: "e1", employeeCode: "EMP-1" }),
      structure({ employeeId: "e2", employeeCode: "EMP-2", basicPay: 12000, allowances: 2000 }),
    ],
  };
  const { entries } = generatePayrollRun(snap, {
    runId: "r",
    period: "2026-07",
    statutory: { configs: [PF(), PT({ state: "KA" })], ptSlabs: KA_SLABS, state: "KA", month: 7 },
  });
  const liabilities = deriveStatutoryLiabilities(entries);
  const byComp = Object.fromEntries(liabilities.map((l) => [l.component, l]));
  // e1 PF: 12% of 15000 (capped) = 1800; e2 PF: 12% of 12000 = 1440 → Σ 3240
  assertEquals(byComp.pf!.employeeAmount, 3240);
  assertEquals(byComp.pf!.employerAmount, 3240);
  assertEquals(byComp.pf!.employeeCount, 2);
  // e1 gross 25000 → PT 200; e2 gross 14000 → PT 0 (below band) → Σ 200, one payer
  assertEquals(byComp.pt!.employeeAmount, 200);
  assertEquals(byComp.pt!.employeeCount, 1);
});
