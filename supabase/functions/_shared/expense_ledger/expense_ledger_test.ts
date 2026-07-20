import { assertEquals, assertRejects } from "jsr:@std/assert@1";
import type { TenantQueryClient } from "../tenant_db.ts";
import type { TransportExpenseRow } from "../transport/transport_expenses_repository.ts";
import type { PayrollFinancePosting } from "../hr/hr_finance_posting_repository.ts";
import type { PurchaseOrderRow } from "../inventory_finance/inventory_finance_repository.ts";
import {
  getExpenseByCategory,
  getExpenseBySource,
  getExpenseSummary,
  InvalidExpenseAmountError,
  InvalidExpenseInputError,
  listExpenseEntries,
  postExpense,
} from "./expense_ledger_repository.ts";
import { buildExpenseBreakdown } from "./expense_ledger_breakdown.ts";
import {
  mapInventoryPurchaseExpense,
  mapPayrollExpense,
  mapTransportExpense,
  postInventoryPurchaseExpense,
  postPayrollExpense,
  postTransportExpense,
} from "./expense_ledger_adapters.ts";

const ORG = "a1000000-0000-4000-8000-000000000001";
const SCHOOL = "a2000000-0000-4000-8000-000000000001";

// ─── Stateful in-memory model of the append-only ledger ──────────────────────
//
// Models the table's real semantics: UNIQUE (org, school, source_module,
// source_ref) + INSERT ... ON CONFLICT DO NOTHING (a duplicate returns 0 rows),
// the period SELECT, and the GROUP BY category / source_module aggregations. There
// is NO update/delete path — the fake exposes none, which is the append-only
// property under test.
interface StoredEntry {
  id: string;
  organization_id: string;
  school_id: string;
  source_module: string;
  source_ref: string;
  category: string;
  amount: number;
  incurred_on: string;
  description: string | null;
  created_at: string;
}

class FakeLedgerDb {
  entries: StoredEntry[] = [];
  private seq = 0;

  // deno-lint-ignore no-explicit-any
  queryObject<T>(sql: string, args: any[] = []): Promise<T[]> {
    const q = sql.replace(/\s+/g, " ").trim();

    if (q.includes("INSERT INTO expense_ledger_entries")) {
      const [org, school, sourceModule, sourceRef, category, amount, incurredOn, description] = args;
      const dup = this.entries.find((e) =>
        e.organization_id === org && e.school_id === school &&
        e.source_module === sourceModule && e.source_ref === sourceRef
      );
      if (dup) return Promise.resolve([] as T[]); // ON CONFLICT DO NOTHING
      const id = `entry-${++this.seq}`;
      this.entries.push({
        id,
        organization_id: org,
        school_id: school,
        source_module: sourceModule,
        source_ref: sourceRef,
        category,
        amount: Number(amount),
        incurred_on: incurredOn,
        description: description ?? null,
        created_at: `2026-07-20T00:00:${String(this.seq).padStart(2, "0")}Z`,
      });
      return Promise.resolve([{ id }] as unknown as T[]);
    }

    if (q.includes("GROUP BY category")) {
      return Promise.resolve(this.aggregate(args, "category", "category") as T[]);
    }
    if (q.includes("GROUP BY source_module")) {
      return Promise.resolve(this.aggregate(args, "source_module", "source_module") as T[]);
    }
    if (q.includes("SELECT * FROM expense_ledger_entries")) {
      const [org, school, from, to] = args;
      const rows = this.inPeriod(org, school, from, to)
        .map((e) => ({ ...e, amount: e.amount.toFixed(2) }))
        .sort((a, b) =>
          a.incurred_on < b.incurred_on ? 1 : a.incurred_on > b.incurred_on ? -1 : 0
        );
      return Promise.resolve(rows as unknown as T[]);
    }
    throw new Error(`Unhandled SQL in FakeLedgerDb: ${q.slice(0, 80)}`);
  }

  private inPeriod(org: string, school: string, from: string, to: string): StoredEntry[] {
    return this.entries.filter((e) =>
      e.organization_id === org && e.school_id === school &&
      e.incurred_on >= from && e.incurred_on <= to
    );
  }

  private aggregate(
    // deno-lint-ignore no-explicit-any
    args: any[],
    key: "category" | "source_module",
    outKey: string,
  ): Array<Record<string, string>> {
    const [org, school, from, to] = args;
    const totals = new Map<string, number>();
    for (const e of this.inPeriod(org, school, from, to)) {
      totals.set(e[key], (totals.get(e[key]) ?? 0) + e.amount);
    }
    const out = [...totals.entries()].map(([k, v]) => ({ [outKey]: k, total: v.toFixed(2) }));
    // Mirror the repo SQL: ORDER BY SUM(amount) DESC, <key> ASC.
    out.sort((a, b) => Number(b.total) - Number(a.total) || a[outKey].localeCompare(b[outKey]));
    return out;
  }
}

function db(fake: FakeLedgerDb): TenantQueryClient {
  return fake as unknown as TenantQueryClient;
}

const PERIOD = ["2026-07-01", "2026-07-31"] as const;

// ─── postExpense idempotency (the core no-double-count guarantee) ─────────────

Deno.test("postExpense: re-posting the same (source_module, source_ref) does not double-count", async () => {
  const fake = new FakeLedgerDb();
  const input = {
    organizationId: ORG,
    schoolId: SCHOOL,
    sourceModule: "transport" as const,
    sourceRef: "te-1",
    category: "fuel",
    amount: 1000,
    incurredOn: "2026-07-10",
    description: null,
  };

  const first = await postExpense(db(fake), input);
  const second = await postExpense(db(fake), input);

  assertEquals(first.posted, true);
  assertEquals(typeof first.entryId, "string");
  assertEquals(second.posted, false, "the idempotency guard must fire on the replay");
  assertEquals(second.entryId, null);
  assertEquals(fake.entries.length, 1, "only ONE ledger row for the same source expense");

  const { total } = await getExpenseByCategory(db(fake), ORG, SCHOOL, ...PERIOD);
  assertEquals(total, "1000.00", "the amount is counted exactly once");
});

Deno.test("postExpense: distinct source_ref inserts distinct rows", async () => {
  const fake = new FakeLedgerDb();
  const base = {
    organizationId: ORG,
    schoolId: SCHOOL,
    sourceModule: "transport" as const,
    category: "fuel",
    amount: 500,
    incurredOn: "2026-07-10",
    description: null,
  };
  await postExpense(db(fake), { ...base, sourceRef: "te-1" });
  await postExpense(db(fake), { ...base, sourceRef: "te-2" });
  assertEquals(fake.entries.length, 2);
  const { total } = await getExpenseByCategory(db(fake), ORG, SCHOOL, ...PERIOD);
  assertEquals(total, "1000.00");
});

Deno.test("postExpense: rejects an invalid amount rather than writing junk", async () => {
  const fake = new FakeLedgerDb();
  const bad = (amount: number) => ({
    organizationId: ORG,
    schoolId: SCHOOL,
    sourceModule: "other" as const,
    sourceRef: "x-1",
    category: "misc",
    amount,
    incurredOn: "2026-07-10",
    description: null,
  });
  await assertRejects(() => postExpense(db(fake), bad(-1)), InvalidExpenseAmountError);
  await assertRejects(() => postExpense(db(fake), bad(Number.NaN)), InvalidExpenseAmountError);
  assertEquals(fake.entries.length, 0, "nothing is written on a rejected amount");
});

Deno.test("postExpense: rejects missing required fields", async () => {
  const fake = new FakeLedgerDb();
  await assertRejects(
    () =>
      postExpense(db(fake), {
        organizationId: ORG,
        schoolId: SCHOOL,
        sourceModule: "other",
        sourceRef: "",
        category: "misc",
        amount: 10,
        incurredOn: "2026-07-10",
        description: null,
      }),
    InvalidExpenseInputError,
  );
  await assertRejects(
    () =>
      postExpense(db(fake), {
        organizationId: ORG,
        schoolId: SCHOOL,
        sourceModule: "other",
        sourceRef: "x",
        category: "   ",
        amount: 10,
        incurredOn: "2026-07-10",
        description: null,
      }),
    InvalidExpenseInputError,
  );
});

// ─── Aggregation: by-category + by-source over a period ──────────────────────

Deno.test("aggregation: by-category and by-source totals are correct and sorted", async () => {
  const fake = new FakeLedgerDb();
  const post = (m: "transport" | "payroll" | "inventory", ref: string, cat: string, amt: number) =>
    postExpense(db(fake), {
      organizationId: ORG,
      schoolId: SCHOOL,
      sourceModule: m,
      sourceRef: ref,
      category: cat,
      amount: amt,
      incurredOn: "2026-07-10",
      description: null,
    });

  await post("transport", "t1", "fuel", 3000);
  await post("transport", "t2", "maintenance", 1000);
  await post("payroll", "p1", "salary", 6000);
  await post("inventory", "i1", "procurement", 2000);

  const summary = await getExpenseSummary(db(fake), ORG, SCHOOL, ...PERIOD);
  assertEquals(summary.total, "12000.00");

  // by-category: salary 6000, fuel 3000, procurement 2000, maintenance 1000 (desc).
  assertEquals(summary.byCategory, [
    { category: "salary", total: "6000.00" },
    { category: "fuel", total: "3000.00" },
    { category: "procurement", total: "2000.00" },
    { category: "maintenance", total: "1000.00" },
  ]);

  // by-source: payroll 6000, transport 4000 (fuel+maintenance), inventory 2000.
  assertEquals(summary.bySource, [
    { sourceModule: "payroll", total: "6000.00" },
    { sourceModule: "transport", total: "4000.00" },
    { sourceModule: "inventory", total: "2000.00" },
  ]);
});

Deno.test("aggregation: period filter excludes out-of-range entries", async () => {
  const fake = new FakeLedgerDb();
  const post = (ref: string, on: string, amt: number) =>
    postExpense(db(fake), {
      organizationId: ORG,
      schoolId: SCHOOL,
      sourceModule: "transport",
      sourceRef: ref,
      category: "fuel",
      amount: amt,
      incurredOn: on,
      description: null,
    });
  await post("in", "2026-07-15", 100);
  await post("before", "2026-06-30", 999);
  await post("after", "2026-08-01", 999);

  const rows = await listExpenseEntries(db(fake), ORG, SCHOOL, ...PERIOD);
  assertEquals(rows.length, 1);
  assertEquals(rows[0].source_ref, "in");
  const { total } = await getExpenseBySource(db(fake), ORG, SCHOOL, ...PERIOD);
  assertEquals(total, "100.00");
});

// ─── Pure buildExpenseBreakdown ──────────────────────────────────────────────

Deno.test("buildExpenseBreakdown: sums per category, computes percent, sorts by amount desc", () => {
  const items = buildExpenseBreakdown([
    { category: "salary", amount: 6000 },
    { category: "fuel", amount: 3000 },
    { category: "fuel", amount: 1000 }, // same category -> summed to 4000
  ]);
  // Total 10000 -> salary 6000 (60%), fuel 4000 (40%).
  assertEquals(items, [
    { label: "salary", value: 6000, percent: 60, category: "salary", amount: 6000 },
    { label: "fuel", value: 4000, percent: 40, category: "fuel", amount: 4000 },
  ]);
  // Emits exactly the keys the Flutter _mapSegments reader consumes.
  assertEquals(Object.keys(items[0]).sort(), ["amount", "category", "label", "percent", "value"]);
});

Deno.test("buildExpenseBreakdown: accepts NUMERIC-as-string amounts (as the DB returns them)", () => {
  const items = buildExpenseBreakdown([
    { category: "a", amount: "150.50" },
    { category: "b", amount: "49.50" },
  ]);
  assertEquals(items[0], { label: "a", value: 150.5, percent: 75.25, category: "a", amount: 150.5 });
  assertEquals(items[1], { label: "b", value: 49.5, percent: 24.75, category: "b", amount: 49.5 });
});

Deno.test("buildExpenseBreakdown: empty input -> [] ; zero total -> 0% (no divide-by-zero)", () => {
  assertEquals(buildExpenseBreakdown([]), []);
  const zero = buildExpenseBreakdown([{ category: "x", amount: 0 }]);
  assertEquals(zero, [{ label: "x", value: 0, percent: 0, category: "x", amount: 0 }]);
});

// ─── Per-source mapping ──────────────────────────────────────────────────────

function transportRow(overrides: Partial<TransportExpenseRow> = {}): TransportExpenseRow {
  return {
    id: "te-1",
    organization_id: ORG,
    school_id: SCHOOL,
    category: "fuel",
    vehicle_id: "veh-1",
    route_id: null,
    amount: "1234.50",
    incurred_on: "2026-07-12",
    vendor: "IOCL",
    reference: "INV-9",
    notes: null,
    status: "recorded",
    void_reason: null,
    voided_by: null,
    voided_at: null,
    recorded_by: "u1",
    created_at: "2026-07-12T00:00:00Z",
    updated_at: "2026-07-12T00:00:00Z",
    ...overrides,
  };
}

Deno.test("mapTransportExpense: maps a recorded row; preserves category; composes description", () => {
  const input = mapTransportExpense(transportRow());
  assertEquals(input, {
    organizationId: ORG,
    schoolId: SCHOOL,
    sourceModule: "transport",
    sourceRef: "te-1",
    category: "fuel",
    amount: 1234.5,
    incurredOn: "2026-07-12",
    description: "IOCL · INV-9",
  });
});

Deno.test("mapTransportExpense: a VOIDed expense maps to null (never counts)", () => {
  assertEquals(mapTransportExpense(transportRow({ status: "void" })), null);
});

Deno.test("postTransportExpense: a voided row posts nothing", async () => {
  const fake = new FakeLedgerDb();
  const res = await postTransportExpense(db(fake), transportRow({ status: "void" }));
  assertEquals(res, { posted: false, entryId: null });
  assertEquals(fake.entries.length, 0);
});

Deno.test("mapPayrollExpense: uses GROSS as the cost, category 'salary', run id as ref", () => {
  const posting: PayrollFinancePosting = {
    payrollRunId: "pay_7",
    period: "2026-07",
    grossAmount: 500000,
    netAmount: 430000,
    employeeCount: 12,
  };
  const input = mapPayrollExpense(ORG, SCHOOL, posting, "2026-07-28");
  assertEquals(input, {
    organizationId: ORG,
    schoolId: SCHOOL,
    sourceModule: "payroll",
    sourceRef: "pay_7",
    category: "salary",
    amount: 500000, // gross, NOT net
    incurredOn: "2026-07-28",
    description: "Payroll 2026-07 · 12 employees",
  });
});

function poRow(overrides: Partial<PurchaseOrderRow> = {}): PurchaseOrderRow {
  return {
    id: "po-1",
    po_number: "PO-1001",
    vendor_id: "v-1",
    status: "approved",
    total_amount: 25000,
    currency: "INR",
    created_at: "2026-07-09T00:00:00Z",
    requested_by: "u1",
    ...overrides,
  };
}

Deno.test("mapInventoryPurchaseExpense: approved PO -> procurement expense; defaults incurredOn to created date", () => {
  const input = mapInventoryPurchaseExpense(ORG, SCHOOL, poRow());
  assertEquals(input, {
    organizationId: ORG,
    schoolId: SCHOOL,
    sourceModule: "inventory",
    sourceRef: "po-1",
    category: "procurement",
    amount: 25000,
    incurredOn: "2026-07-09",
    description: "PO PO-1001",
  });
});

Deno.test("mapInventoryPurchaseExpense: a draft PO is not yet an incurred expense (null)", () => {
  assertEquals(mapInventoryPurchaseExpense(ORG, SCHOOL, poRow({ status: "draft" })), null);
  assertEquals(mapInventoryPurchaseExpense(ORG, SCHOOL, poRow({ status: "rejected" })), null);
});

// ─── End-to-end via the adapters (idempotent, honest, multi-source) ──────────

Deno.test("adapters end-to-end: three real sources aggregate into one ledger, idempotently", async () => {
  const fake = new FakeLedgerDb();
  const payroll: PayrollFinancePosting = {
    payrollRunId: "pay_7",
    period: "2026-07",
    grossAmount: 500000,
    netAmount: 430000,
    employeeCount: 12,
  };

  // Post each source. Re-post each once — the ledger must stay single-counted.
  for (let i = 0; i < 2; i++) {
    await postTransportExpense(db(fake), transportRow({ id: "te-1", amount: "2000.00", category: "fuel" }));
    await postPayrollExpense(db(fake), ORG, SCHOOL, payroll, "2026-07-28");
    await postInventoryPurchaseExpense(db(fake), ORG, SCHOOL, poRow({ id: "po-1", total_amount: 25000 }), "2026-07-09");
  }

  assertEquals(fake.entries.length, 3, "one row per source expense despite the replay");

  const summary = await getExpenseSummary(db(fake), ORG, SCHOOL, ...PERIOD);
  assertEquals(summary.total, "527000.00"); // 2000 + 500000 + 25000
  assertEquals(summary.bySource, [
    { sourceModule: "payroll", total: "500000.00" },
    { sourceModule: "inventory", total: "25000.00" },
    { sourceModule: "transport", total: "2000.00" },
  ]);

  // The breakdown that management's `expenseBreakdown` will consume.
  const entries = await listExpenseEntries(db(fake), ORG, SCHOOL, ...PERIOD);
  const breakdown = buildExpenseBreakdown(entries.map((e) => ({ category: e.category, amount: e.amount })));
  assertEquals(breakdown.map((b) => b.label), ["salary", "procurement", "fuel"]);
  assertEquals(breakdown[0], { label: "salary", value: 500000, percent: 94.88, category: "salary", amount: 500000 });
});

// ─── Append-only invariant: migration grants no UPDATE/DELETE, repo has none ──

Deno.test("append-only: migration grants SELECT+INSERT only (no UPDATE/DELETE on the ledger)", async () => {
  const sql = await Deno.readTextFile(
    new URL("../../../migrations/20260900000026_expense_ledger.sql", import.meta.url),
  );
  assertEquals(
    sql.includes("GRANT SELECT, INSERT ON expense_ledger_entries TO erp_tenant;"),
    true,
    "ledger must grant SELECT + INSERT",
  );
  // No UPDATE or DELETE is ever granted on the ledger table.
  assertEquals(
    /GRANT[^;]*(UPDATE|DELETE)[^;]*ON expense_ledger_entries/.test(sql),
    false,
    "append-only: no UPDATE/DELETE grant",
  );
  // Tenant isolation + write-guard invariants are present.
  assertEquals(sql.includes("ENABLE ROW LEVEL SECURITY"), true);
  assertEquals(sql.includes("FORCE ROW LEVEL SECURITY"), true);
  assertEquals(sql.includes("WITH CHECK ("), true);
  // Idempotency key + source-module enum + covering indexes.
  assertEquals(
    sql.includes("UNIQUE (organization_id, school_id, source_module, source_ref)"),
    true,
  );
  assertEquals(
    sql.includes("'payroll', 'inventory', 'transport', 'maintenance', 'utilities', 'other'"),
    true,
  );
  assertEquals(sql.includes("idx_expense_ledger_entries_period"), true);
  assertEquals(sql.includes("idx_expense_ledger_entries_source"), true);
});

Deno.test("append-only: the repository never emits UPDATE or DELETE against the ledger", async () => {
  const src = await Deno.readTextFile(new URL("./expense_ledger_repository.ts", import.meta.url));
  assertEquals(/UPDATE\s+expense_ledger_entries/i.test(src), false);
  assertEquals(/DELETE\s+FROM\s+expense_ledger_entries/i.test(src), false);
  // The idempotent insert IS present.
  assertEquals(src.includes("ON CONFLICT (organization_id, school_id, source_module, source_ref)"), true);
  assertEquals(src.includes("DO NOTHING"), true);
});
