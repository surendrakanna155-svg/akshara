// PRA-P1-34 (Owner decision #10, FINAL) — leave accrual + carry-forward tests.
//
// Two layers are proven here DB-free:
//   1. PURE MATH (computeAccrual + helpers): mid-year join proration (monthly and
//      annual), carry-forward cap hit, use-it-or-lose-it lapse, unlimited carry,
//      lapses=false rolls in full, max-balance running cap, opening grant, prior
//      deductions netting, and the SUM-derivable balance identity.
//   2. REPOSITORY (runAccrualForEmployee + reads) against a fake TenantQueryClient
//      that models the ledger's UNIQUE(org, school, employee, leave_type,
//      entry_type, period_key) guard: a first run writes the ledger, a SECOND run
//      in the same period writes NOTHING (no double-accrue), and the policy is read
//      from the DB (config-driven) — never hardcoded.

import { assertEquals } from "jsr:@std/assert@1";
import type { TenantQueryClient } from "../tenant_db.ts";
import {
  computeAccrual,
  deriveBalance,
  type LeaveAccrualPolicy,
  monthsInServiceForYear,
  perMonthRate,
} from "./leave_accrual.ts";
import {
  appendLedgerEntry,
  listAccrualPolicies,
  readAccrualBalances,
  rowToPolicy,
  runAccrualForEmployee,
} from "./leave_accrual_repository.ts";

const ORG = "a1000000-0000-4000-8000-000000000001";
const SCHOOL = "a2000000-0000-4000-8000-000000000001";
const USER = "a3000000-0000-4000-8000-000000000001";

/** A monthly earned-leave policy; overridable per test (config lives in DATA). */
function policy(over: Partial<LeaveAccrualPolicy> = {}): LeaveAccrualPolicy {
  return {
    leaveType: "earned",
    accrualRate: 1,
    accrualPeriod: "monthly",
    openingBalance: 0,
    carryForwardCap: null,
    maxBalance: null,
    lapses: true,
    ...over,
  };
}

// ── PURE: period math ─────────────────────────────────────────────────────────

Deno.test("months: full calendar year in service = 12 months", () => {
  assertEquals(monthsInServiceForYear("2026-01-01", "2026-12-31", 2026), 12);
});

Deno.test("months: mid-year join (July) = 6 months of service that year", () => {
  assertEquals(monthsInServiceForYear("2026-07-15", "2026-12-31", 2026), 6);
});

Deno.test("months: 0 when the year is before the join or after as-of", () => {
  assertEquals(monthsInServiceForYear("2026-07-01", "2026-12-31", 2025), 0);
  assertEquals(monthsInServiceForYear("2026-07-01", "2026-12-31", 2027), 0);
});

Deno.test("perMonthRate: annual policy spreads its rate across 12 months", () => {
  assertEquals(perMonthRate(policy({ accrualPeriod: "annual", accrualRate: 24 })), 2);
  assertEquals(perMonthRate(policy({ accrualPeriod: "monthly", accrualRate: 2 })), 2);
});

// ── PURE: accrual math ────────────────────────────────────────────────────────

Deno.test("accrual: monthly full year → one entry/month, days = rate × 12", () => {
  const r = computeAccrual(policy({ accrualRate: 1.5 }), "2026-01-01", "2026-12-31");
  const accruals = r.entries.filter((e) => e.entryType === "accrual");
  assertEquals(accruals.length, 12);
  assertEquals(r.totalAccrued, 18); // 1.5 × 12
  assertEquals(r.balance, 18);
  // The idempotency dimension is unique per month.
  assertEquals(accruals[0]!.periodKey, "2026-01");
  assertEquals(accruals[11]!.periodKey, "2026-12");
});

Deno.test("accrual: MID-YEAR JOIN proration (monthly) — July join accrues only 6 months", () => {
  const r = computeAccrual(policy({ accrualRate: 1 }), "2026-07-15", "2026-12-31");
  const accruals = r.entries.filter((e) => e.entryType === "accrual");
  assertEquals(accruals.length, 6); // Jul..Dec
  assertEquals(accruals.map((e) => e.periodKey), [
    "2026-07", "2026-08", "2026-09", "2026-10", "2026-11", "2026-12",
  ]);
  assertEquals(r.balance, 6);
});

Deno.test("accrual: MID-YEAR JOIN proration (annual) — July join = half the annual rate", () => {
  const r = computeAccrual(
    policy({ accrualPeriod: "annual", accrualRate: 24 }),
    "2026-07-01",
    "2026-12-31",
  );
  const accruals = r.entries.filter((e) => e.entryType === "accrual");
  assertEquals(accruals.length, 1);
  assertEquals(accruals[0]!.periodKey, "2026"); // annual period key
  assertEquals(r.totalAccrued, 12); // 24 × 6/12
  assertEquals(r.balance, 12);
});

Deno.test("accrual: CARRY-FORWARD CAP HIT — excess above the cap lapses at year end", () => {
  // 4 days/month → 48 in 2026; cap 30 → 18 lapse; +24 in H1 2027 → 54.
  const r = computeAccrual(
    policy({ accrualRate: 4, carryForwardCap: 30, lapses: true }),
    "2026-01-01",
    "2027-06-30",
  );
  const lapses = r.entries.filter((e) => e.entryType === "lapse");
  assertEquals(lapses.length, 1);
  assertEquals(lapses[0]!.periodKey, "lapse:2026");
  assertEquals(lapses[0]!.amount, -18); // 48 − 30
  assertEquals(r.totalLapsed, 18);
  assertEquals(r.balance, 54); // 30 carried + 24 accrued in 2027
});

Deno.test("accrual: LAPSE AT YEAR END — use-it-or-lose-it (cap 0) forfeits the whole balance", () => {
  const r = computeAccrual(
    policy({ accrualRate: 2, carryForwardCap: 0, lapses: true }),
    "2026-01-01",
    "2027-03-31",
  );
  const lapse2026 = r.entries.find((e) => e.periodKey === "lapse:2026");
  assertEquals(lapse2026?.amount, -24); // all 24 of 2026 lapses
  assertEquals(r.totalAccrued, 30); // 24 (2026) + 6 (Jan–Mar 2027)
  assertEquals(r.balance, 6); // only 2027's accrual survives
});

Deno.test("accrual: UNLIMITED CAP (carryForwardCap null) never lapses — full balance rolls", () => {
  const r = computeAccrual(
    policy({ accrualRate: 4, carryForwardCap: null, lapses: true }),
    "2026-01-01",
    "2027-06-30",
  );
  assertEquals(r.entries.filter((e) => e.entryType === "lapse").length, 0);
  assertEquals(r.totalLapsed, 0);
  assertEquals(r.balance, 72); // 48 + 24, nothing forfeited
});

Deno.test("accrual: lapses=false rolls the full balance even with a cap set", () => {
  const r = computeAccrual(
    policy({ accrualRate: 4, carryForwardCap: 30, lapses: false }),
    "2026-01-01",
    "2027-06-30",
  );
  assertEquals(r.totalLapsed, 0);
  assertEquals(r.balance, 72);
});

Deno.test("accrual: MAX BALANCE running cap — balance never exceeds the cap", () => {
  // rate 4, cap 20: accrues 4,4,4,4,4 → 20, then stops (no zero entries).
  const r = computeAccrual(
    policy({ accrualRate: 4, maxBalance: 20 }),
    "2026-01-01",
    "2026-12-31",
  );
  const accruals = r.entries.filter((e) => e.entryType === "accrual");
  assertEquals(accruals.length, 5);
  assertEquals(r.totalAccrued, 20);
  assertEquals(r.balance, 20);
});

Deno.test("accrual: OPENING balance is granted once as an 'opening' entry", () => {
  const r = computeAccrual(
    policy({ accrualRate: 0, openingBalance: 10 }),
    "2026-01-01",
    "2026-01-01",
  );
  const opening = r.entries.filter((e) => e.entryType === "opening");
  assertEquals(opening.length, 1);
  assertEquals(opening[0]!.amount, 10);
  assertEquals(opening[0]!.periodKey, "opening");
  assertEquals(r.balance, 10);
});

Deno.test("accrual: PRIOR DEDUCTIONS net into the balance (leave already taken)", () => {
  const r = computeAccrual(
    policy({ accrualRate: 1 }),
    "2026-01-01",
    "2026-12-31",
    { priorDeductions: 3 },
  );
  assertEquals(r.totalAccrued, 12);
  assertEquals(r.priorDeductions, 3);
  assertEquals(r.balance, 9); // 12 accrued − 3 taken
});

Deno.test("accrual: as-of BEFORE join accrues nothing (opening only)", () => {
  const r = computeAccrual(
    policy({ accrualRate: 5, openingBalance: 2 }),
    "2026-06-01",
    "2026-01-01",
  );
  assertEquals(r.totalAccrued, 0);
  assertEquals(r.entries.filter((e) => e.entryType === "accrual").length, 0);
  assertEquals(r.balance, 2);
});

Deno.test("accrual: balance equals SUM(amount) over the emitted ledger (derivable identity)", () => {
  const r = computeAccrual(
    policy({ accrualRate: 4, carryForwardCap: 30, lapses: true, openingBalance: 5 }),
    "2026-01-01",
    "2027-06-30",
  );
  // deriveBalance mirrors the SQL SUM(amount); with no prior deductions it equals
  // the reported balance exactly.
  assertEquals(deriveBalance(r.entries), r.balance);
});

// ── REPOSITORY: config mapping + fake-DB idempotency ─────────────────────────

/** A policy row shaped exactly like a `leave_accrual_policies` SELECT row. */
function policyRow(over: Record<string, unknown> = {}): Record<string, unknown> {
  return {
    leave_type: "earned",
    accrual_rate: "1", // NUMERIC comes back as text from the driver
    accrual_period: "monthly",
    opening_balance: "0",
    carry_forward_cap: null,
    max_balance: null,
    lapses: true,
    ...over,
  };
}

Deno.test("repo: rowToPolicy maps a DB row (config) into the pure-engine policy", () => {
  const p = rowToPolicy(policyRow({
    leave_type: "sick",
    accrual_rate: "1.5",
    accrual_period: "annual",
    opening_balance: "3",
    carry_forward_cap: "30",
    max_balance: "45",
    lapses: false,
  }));
  assertEquals(p, {
    leaveType: "sick",
    accrualRate: 1.5,
    accrualPeriod: "annual",
    openingBalance: 3,
    carryForwardCap: 30,
    maxBalance: 45,
    lapses: false,
  });
  // A NULL cap maps to `null` (unlimited), not 0.
  assertEquals(rowToPolicy(policyRow()).carryForwardCap, null);
});

/**
 * In-memory TenantQueryClient modelling BOTH accrual tables. The ledger enforces
 * the same UNIQUE(org, school, employee, leave_type, entry_type, period_key) guard
 * the migration declares, so `ON CONFLICT DO NOTHING` behaves exactly as in Postgres.
 */
function fakeDb(policyRows: Record<string, unknown>[] = []): {
  db: TenantQueryClient;
  ledgerCount: () => number;
} {
  const ledger = new Map<string, { amount: number; leave_type: string; entry_type: string }>();
  let seq = 0;

  const db = {
    // deno-lint-ignore no-explicit-any
    queryObject: (sql: string, args: unknown[] = []): Promise<any[]> => {
      // INSERT into the ledger (idempotent on the composite key).
      if (sql.includes("INSERT INTO leave_accrual_ledger")) {
        const [org, school, employeeId, leaveType, entryType, amount, periodKey] =
          args as [string, string, string, string, string, number, string];
        const key = `${org}|${school}|${employeeId}|${leaveType}|${entryType}|${periodKey}`;
        if (ledger.has(key)) return Promise.resolve([]); // conflict → no RETURNING
        ledger.set(key, { amount: Number(amount), leave_type: leaveType, entry_type: entryType });
        return Promise.resolve([{ id: `led-${++seq}` }]);
      }
      // Prior deductions: −SUM(amount) over 'deduction' rows.
      if (sql.includes("entry_type = 'deduction'")) {
        const [, , , leaveType] = args as string[];
        let sum = 0;
        for (const e of ledger.values()) {
          if (e.entry_type === "deduction" && e.leave_type === leaveType) sum += e.amount;
        }
        return Promise.resolve([{ deducted: String(-sum) }]);
      }
      // Balances: SUM(amount) grouped by leave_type.
      if (sql.includes("GROUP BY leave_type")) {
        const byType = new Map<string, number>();
        for (const e of ledger.values()) {
          byType.set(e.leave_type, (byType.get(e.leave_type) ?? 0) + e.amount);
        }
        return Promise.resolve(
          [...byType.entries()]
            .sort(([a], [b]) => a.localeCompare(b))
            .map(([leave_type, balance]) => ({ leave_type, balance: String(balance) })),
        );
      }
      // getAccrualPolicy (has a leave_type filter) vs listAccrualPolicies.
      if (sql.includes("FROM leave_accrual_policies")) {
        if (sql.includes("leave_type = $3")) {
          const leaveType = (args as string[])[2];
          const found = policyRows.find((p) => String(p.leave_type) === leaveType);
          return Promise.resolve(found ? [found] : []);
        }
        return Promise.resolve([...policyRows]);
      }
      throw new Error(`fakeDb: unhandled SQL: ${sql.slice(0, 60)}`);
    },
  } as unknown as TenantQueryClient;

  return { db, ledgerCount: () => ledger.size };
}

Deno.test("repo: listAccrualPolicies reads the CONFIG from the DB (not hardcoded)", async () => {
  const { db } = fakeDb([
    policyRow({ leave_type: "casual", accrual_rate: "1" }),
    policyRow({ leave_type: "sick", accrual_rate: "0.5", accrual_period: "annual" }),
  ]);
  const policies = await listAccrualPolicies(db, ORG, SCHOOL);
  assertEquals(policies.map((p) => p.leaveType), ["casual", "sick"]);
  assertEquals(policies[1]!.accrualPeriod, "annual");
});

Deno.test("repo: a first accrual run writes the ledger; balance = accrued", async () => {
  const { db, ledgerCount } = fakeDb();
  const result = await runAccrualForEmployee(
    db, ORG, SCHOOL, "emp-1", "2026-01-01", "2026-06-30",
    policy({ accrualRate: 2 }), USER,
  );
  assertEquals(result.planned, 6); // Jan..Jun
  assertEquals(result.inserted, 6);
  assertEquals(result.balance, 12); // 2 × 6
  assertEquals(ledgerCount(), 6);
});

Deno.test("repo: IDEMPOTENCY — re-running the SAME period does NOT double-accrue", async () => {
  const { db, ledgerCount } = fakeDb();
  const p = policy({ accrualRate: 2 });
  const first = await runAccrualForEmployee(db, ORG, SCHOOL, "emp-1", "2026-01-01", "2026-06-30", p, USER);
  const second = await runAccrualForEmployee(db, ORG, SCHOOL, "emp-1", "2026-01-01", "2026-06-30", p, USER);
  assertEquals(first.inserted, 6);
  assertEquals(second.inserted, 0, "second run in the same period writes nothing");
  assertEquals(second.planned, 6, "it still PLANS the same 6 — they just already exist");
  assertEquals(ledgerCount(), 6, "still exactly 6 ledger rows — no double-accrue");
  // The derivable balance is unchanged by the redundant run.
  const balances = await readAccrualBalances(db, ORG, SCHOOL, "emp-1");
  assertEquals(balances, [{ employeeId: "emp-1", leaveType: "earned", balance: 12 }]);
});

Deno.test("repo: extending the as-of date accrues ONLY the new periods (incremental)", async () => {
  const { db, ledgerCount } = fakeDb();
  const p = policy({ accrualRate: 2 });
  await runAccrualForEmployee(db, ORG, SCHOOL, "emp-1", "2026-01-01", "2026-06-30", p, USER);
  // A later run through September adds exactly Jul, Aug, Sep — not the Jan–Jun rows.
  const later = await runAccrualForEmployee(db, ORG, SCHOOL, "emp-1", "2026-01-01", "2026-09-30", p, USER);
  assertEquals(later.inserted, 3, "only the 3 new months are written");
  assertEquals(ledgerCount(), 9);
  const balances = await readAccrualBalances(db, ORG, SCHOOL, "emp-1");
  assertEquals(balances[0]!.balance, 18); // 2 × 9
});

Deno.test("repo: CONFIG-DRIVEN — changing the DB policy changes what accrues", async () => {
  // Same employee window, two different configured rates → two different results.
  const slow = fakeDb();
  const fast = fakeDb();
  const rSlow = await runAccrualForEmployee(
    slow.db, ORG, SCHOOL, "emp-1", "2026-01-01", "2026-12-31",
    rowToPolicy(policyRow({ accrual_rate: "1" })), USER,
  );
  const rFast = await runAccrualForEmployee(
    fast.db, ORG, SCHOOL, "emp-1", "2026-01-01", "2026-12-31",
    rowToPolicy(policyRow({ accrual_rate: "2.5" })), USER,
  );
  assertEquals(rSlow.balance, 12); // 1 × 12
  assertEquals(rFast.balance, 30); // 2.5 × 12 — driven purely by the DB config
});

Deno.test("repo: readAccrualBalances sums per leave-type across the append-only ledger", async () => {
  const { db } = fakeDb();
  await runAccrualForEmployee(db, ORG, SCHOOL, "emp-1", "2026-01-01", "2026-06-30", policy({ leaveType: "earned", accrualRate: 2 }), USER);
  await runAccrualForEmployee(db, ORG, SCHOOL, "emp-1", "2026-01-01", "2026-06-30", policy({ leaveType: "casual", accrualRate: 1 }), USER);
  const balances = await readAccrualBalances(db, ORG, SCHOOL, "emp-1");
  assertEquals(balances, [
    { employeeId: "emp-1", leaveType: "casual", balance: 6 },
    { employeeId: "emp-1", leaveType: "earned", balance: 12 },
  ]);
});

Deno.test("repo: prior 'deduction' entries reduce the accrued balance", async () => {
  const { db } = fakeDb();
  // Seed a deduction (leave taken) directly, as the approval path would.
  await appendLedgerEntry(db, ORG, SCHOOL, "emp-1", {
    entryType: "deduction",
    leaveType: "earned",
    amount: -4,
    periodKey: "req:req-1",
    asOfDate: "2026-03-10",
    note: "Approved leave",
  }, USER);
  const result = await runAccrualForEmployee(
    db, ORG, SCHOOL, "emp-1", "2026-01-01", "2026-06-30", policy({ accrualRate: 2 }), USER,
  );
  assertEquals(result.balance, 8); // 12 accrued − 4 taken
  const balances = await readAccrualBalances(db, ORG, SCHOOL, "emp-1");
  assertEquals(balances[0]!.balance, 8); // ledger SUM confirms it
});

Deno.test("repo: appendLedgerEntry is idempotent on the composite period key", async () => {
  const { db, ledgerCount } = fakeDb();
  const entry = {
    entryType: "accrual" as const,
    leaveType: "earned",
    amount: 2,
    periodKey: "2026-07",
    asOfDate: "2026-07-31",
    note: "Monthly accrual",
  };
  const first = await appendLedgerEntry(db, ORG, SCHOOL, "emp-1", entry, USER);
  const dup = await appendLedgerEntry(db, ORG, SCHOOL, "emp-1", entry, USER);
  assertEquals(first.inserted, true);
  assertEquals(dup.inserted, false); // same key → ON CONFLICT DO NOTHING
  assertEquals(ledgerCount(), 1);
});
