// PRA-P0-24 — payroll → Finance expense posting.
//
// Money-critical. Two layers are proven here DB-free:
//   1. PURE totals (buildPayrollFinancePosting + selectRunEntries): the posted
//      gross/net/employeeCount are the HONEST run totals, summed from the same
//      entries the salary register reports.
//   2. IDEMPOTENCY (postPayrollRunToFinance): the INSERT ... ON CONFLICT DO
//      NOTHING posts a run ONCE; a re-post of the same payroll_run_id writes no
//      second row (no double-post), exercised against a fake TenantQueryClient
//      that models the UNIQUE(organization_id, school_id, payroll_run_id) guard.

import { assertEquals } from "jsr:@std/assert@1";
import type { TenantQueryClient } from "../tenant_db.ts";
import {
  buildPayrollFinancePosting,
  postPayrollRunToFinance,
  selectRunEntries,
} from "./hr_finance_posting_repository.ts";

const ORG = "a1000000-0000-4000-8000-000000000001";
const SCHOOL = "a2000000-0000-4000-8000-000000000001";
const USER = "a3000000-0000-4000-8000-000000000001";

function entry(over: Record<string, unknown> = {}): Record<string, unknown> {
  return {
    runId: "pay_1",
    employeeId: "e1",
    basicPay: 40000,
    allowances: 8000,
    deductions: 3000,
    netPay: 45000, // 40000 + 8000 - 3000
    ...over,
  };
}

// ── PURE totals ──────────────────────────────────────────────────────────────

Deno.test("posting: gross = Σ(basic+allowances), net = Σ netPay, count = #entries (honest)", () => {
  const run = { id: "pay_1", period: "2026-07" };
  const entries = [
    entry(),
    entry({ employeeId: "e2", basicPay: 30000, allowances: 2000, deductions: 1000, netPay: 31000 }),
  ];
  const posting = buildPayrollFinancePosting(run, entries);
  assertEquals(posting.payrollRunId, "pay_1");
  assertEquals(posting.period, "2026-07");
  assertEquals(posting.grossAmount, 40000 + 8000 + 30000 + 2000); // 80000
  assertEquals(posting.netAmount, 45000 + 31000); // 76000
  assertEquals(posting.employeeCount, 2);
});

Deno.test("posting: an empty run posts honest zeros, not a fabricated number", () => {
  const posting = buildPayrollFinancePosting({ id: "pay_x", period: "2026-08" }, []);
  assertEquals(posting.grossAmount, 0);
  assertEquals(posting.netAmount, 0);
  assertEquals(posting.employeeCount, 0);
});

Deno.test("posting: selectRunEntries takes tagged entries for the run + legacy untagged", () => {
  const snapshot = {
    entries: [
      entry({ runId: "pay_1", employeeId: "e1" }),
      entry({ runId: "pay_2", employeeId: "e2" }), // other run — excluded
      entry({ runId: undefined, employeeId: "e3" }), // legacy untagged — included
    ],
  };
  const selected = selectRunEntries(snapshot, "pay_1");
  assertEquals(selected.map((e) => e.employeeId).sort(), ["e1", "e3"]);
});

Deno.test("posting: derived totals equal the salary-register totals for the run", () => {
  const snapshot = {
    runs: [{ id: "pay_1", period: "2026-07", status: "processed" }],
    entries: [
      entry({ employeeId: "e1" }),
      entry({ employeeId: "e2", basicPay: 50000, allowances: 5000, deductions: 2000, netPay: 53000 }),
      entry({ runId: "pay_other", employeeId: "e9" }), // must NOT be counted
    ],
  };
  const runEntries = selectRunEntries(snapshot, "pay_1");
  const posting = buildPayrollFinancePosting(
    (snapshot.runs as Array<Record<string, unknown>>)[0]!,
    runEntries,
  );
  assertEquals(posting.employeeCount, 2);
  assertEquals(posting.grossAmount, (40000 + 8000) + (50000 + 5000)); // 103000
  assertEquals(posting.netAmount, 45000 + 53000); // 98000
});

// ── IDEMPOTENCY (fake DB) ────────────────────────────────────────────────────

/** In-memory TenantQueryClient modelling UNIQUE(org, school, payroll_run_id). */
function fakePostingDb(): { db: TenantQueryClient; rowCount: () => number } {
  const rows = new Map<string, { id: string }>();
  let seq = 0;
  const db = {
    // deno-lint-ignore no-explicit-any
    queryObject: (_sql: string, args: unknown[] = []): Promise<any[]> => {
      const [org, school, runId] = args as string[];
      const key = `${org}|${school}|${runId}`;
      if (rows.has(key)) return Promise.resolve([]); // ON CONFLICT DO NOTHING → no RETURNING
      const id = `posting-${++seq}`;
      rows.set(key, { id });
      return Promise.resolve([{ id }]);
    },
  } as unknown as TenantQueryClient;
  return { db, rowCount: () => rows.size };
}

Deno.test("posting: a first post writes exactly one row (posted=true, id returned)", async () => {
  const { db, rowCount } = fakePostingDb();
  const posting = buildPayrollFinancePosting({ id: "pay_1", period: "2026-07" }, [entry()]);
  const result = await postPayrollRunToFinance(db, ORG, SCHOOL, posting, USER);
  assertEquals(result.posted, true);
  assertEquals(result.postingId, "posting-1");
  assertEquals(rowCount(), 1);
});

Deno.test("posting: RE-POSTING the same run does NOT double-post (posted=false, still one row)", async () => {
  const { db, rowCount } = fakePostingDb();
  const posting = buildPayrollFinancePosting({ id: "pay_1", period: "2026-07" }, [entry()]);
  const first = await postPayrollRunToFinance(db, ORG, SCHOOL, posting, USER);
  const second = await postPayrollRunToFinance(db, ORG, SCHOOL, posting, USER);
  assertEquals(first.posted, true);
  assertEquals(second.posted, false); // conflict → no new row
  assertEquals(second.postingId, null);
  assertEquals(rowCount(), 1, "the run is posted exactly once");
});

Deno.test("posting: a different run in the same school posts its own row", async () => {
  const { db, rowCount } = fakePostingDb();
  await postPayrollRunToFinance(db, ORG, SCHOOL, buildPayrollFinancePosting({ id: "pay_1", period: "2026-07" }, [entry()]), USER);
  const other = await postPayrollRunToFinance(db, ORG, SCHOOL, buildPayrollFinancePosting({ id: "pay_2", period: "2026-08" }, [entry({ runId: "pay_2" })]), USER);
  assertEquals(other.posted, true);
  assertEquals(rowCount(), 2);
});
