// PRA-P1-35 — statutory payroll repository: row mappers + LIABILITY idempotency.
//
// Money-critical guard proven DB-free against a fake TenantQueryClient that models
// UNIQUE(org, school, payroll_run_id, component, state): a run's statutory
// liabilities post ONCE; a re-process posts no second row (no double-liability),
// the same guarantee proven for payroll_finance_postings.

import { assertEquals } from "jsr:@std/assert@1";
import type { TenantQueryClient } from "../tenant_db.ts";
import type { StatutoryLiability } from "./statutory_payroll.ts";
import {
  postStatutoryLiabilities,
  rowToComponentConfig,
  rowToPtSlab,
} from "./statutory_payroll_repository.ts";

const ORG = "a1000000-0000-4000-8000-000000000001";
const SCHOOL = "a2000000-0000-4000-8000-000000000001";
const USER = "a3000000-0000-4000-8000-000000000001";

// ── row mappers (DB row → engine shape) ────────────────────────────────────────

Deno.test("rowToComponentConfig: coerces numerics, nullable caps, and booleans", () => {
  const cfg = rowToComponentConfig({
    component: "pf",
    state: "",
    employee_rate: "0.12000",
    employer_rate: "0.12000",
    wage_base: "basic",
    base_cap: "15000.00",
    eligibility_ceiling: null,
    eligibility_floor: null,
    flat_employee: null,
    flat_employer: null,
    rounding: "nearest",
    active: true,
  });
  assertEquals(cfg.component, "pf");
  assertEquals(cfg.employeeRate, 0.12);
  assertEquals(cfg.wageBase, "basic");
  assertEquals(cfg.baseCap, 15000);
  assertEquals(cfg.eligibilityCeiling, null);
  assertEquals(cfg.active, true);
});

Deno.test("rowToComponentConfig: 'f'/'t' text booleans and default rounding", () => {
  const cfg = rowToComponentConfig({ component: "esi", active: "t", rounding: "up" });
  assertEquals(cfg.active, true);
  assertEquals(cfg.rounding, "up");
  const off = rowToComponentConfig({ component: "esi", active: "f" });
  assertEquals(off.active, false);
});

Deno.test("rowToPtSlab: null upper bound and null month map through", () => {
  const slab = rowToPtSlab({ state: "KA", lower_bound: "15000", upper_bound: null, amount: "200", month: null });
  assertEquals(slab.state, "KA");
  assertEquals(slab.lowerBound, 15000);
  assertEquals(slab.upperBound, null);
  assertEquals(slab.amount, 200);
  assertEquals(slab.month, null);
  const feb = rowToPtSlab({ state: "KA", lower_bound: "15000", upper_bound: null, amount: "300", month: 2 });
  assertEquals(feb.month, 2);
});

// ── LIABILITY idempotency (fake DB) ────────────────────────────────────────────

/** In-memory TenantQueryClient modelling UNIQUE(org, school, run, component, state). */
function fakeLiabilityDb(): { db: TenantQueryClient; rowCount: () => number } {
  const rows = new Map<string, { id: string }>();
  let seq = 0;
  const db = {
    // deno-lint-ignore no-explicit-any
    queryObject: (_sql: string, args: unknown[] = []): Promise<any[]> => {
      // args: org, school, runId, period, component, state, ...
      const [org, school, runId, _period, component, state] = args as string[];
      const key = `${org}|${school}|${runId}|${component}|${state}`;
      if (rows.has(key)) return Promise.resolve([]); // ON CONFLICT DO NOTHING
      const id = `liab-${++seq}`;
      rows.set(key, { id });
      return Promise.resolve([{ id }]);
    },
  } as unknown as TenantQueryClient;
  return { db, rowCount: () => rows.size };
}

function liab(over: Partial<StatutoryLiability> = {}): StatutoryLiability {
  return {
    component: "pf",
    state: "",
    employeeAmount: 1800,
    employerAmount: 1800,
    totalAmount: 3600,
    employeeCount: 1,
    ...over,
  };
}

Deno.test("liabilities: a first post writes one row per component", async () => {
  const { db, rowCount } = fakeLiabilityDb();
  const { posted } = await postStatutoryLiabilities(db, ORG, SCHOOL, "pay_1", "2026-07", [
    liab({ component: "pf" }),
    liab({ component: "pt", state: "KA", employerAmount: 0, totalAmount: 200, employeeAmount: 200 }),
  ], USER);
  assertEquals(posted, 2);
  assertEquals(rowCount(), 2);
});

Deno.test("liabilities: RE-PROCESSING the same run does NOT double-post", async () => {
  const { db, rowCount } = fakeLiabilityDb();
  const set: StatutoryLiability[] = [liab({ component: "pf" }), liab({ component: "esi" })];
  const first = await postStatutoryLiabilities(db, ORG, SCHOOL, "pay_1", "2026-07", set, USER);
  const second = await postStatutoryLiabilities(db, ORG, SCHOOL, "pay_1", "2026-07", set, USER);
  assertEquals(first.posted, 2);
  assertEquals(second.posted, 0); // both conflict → nothing new
  assertEquals(rowCount(), 2, "each (run, component) posted exactly once");
});

Deno.test("liabilities: the SAME component in two states posts two rows (per-jurisdiction)", async () => {
  const { db, rowCount } = fakeLiabilityDb();
  const { posted } = await postStatutoryLiabilities(db, ORG, SCHOOL, "pay_1", "2026-07", [
    liab({ component: "pt", state: "KA", employerAmount: 0 }),
    liab({ component: "pt", state: "MH", employerAmount: 0 }),
  ], USER);
  assertEquals(posted, 2);
  assertEquals(rowCount(), 2);
});

Deno.test("liabilities: a different run in the same school posts its own rows", async () => {
  const { db, rowCount } = fakeLiabilityDb();
  await postStatutoryLiabilities(db, ORG, SCHOOL, "pay_1", "2026-07", [liab()], USER);
  const other = await postStatutoryLiabilities(db, ORG, SCHOOL, "pay_2", "2026-08", [liab()], USER);
  assertEquals(other.posted, 1);
  assertEquals(rowCount(), 2);
});
