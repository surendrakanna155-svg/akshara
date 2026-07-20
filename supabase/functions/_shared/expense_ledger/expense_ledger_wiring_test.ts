// W4 — LIVE wiring proof for the canonical Expense Ledger.
//
// Proves, at the seam each source handler actually composes (the wiring helpers +
// the same fake TenantQueryClient the handlers run against — handlers themselves
// wrap auth/tenant plumbing that is not unit-testable in isolation):
//
//   1. Each source write ALSO posts exactly ONE ledger entry (transport / payroll /
//      inventory), and no source posts more than one per event.
//   2. A ledger-post FAILURE does NOT break the source write: the post is fenced in
//      a SAVEPOINT (ROLLBACK TO SAVEPOINT on error) and the error is swallowed, so it
//      can never propagate out of the source handler or roll the source write back.
//   3. NO DOUBLE-COUNT: a replay/backfill re-posts nothing (ON CONFLICT DO NOTHING).
//   4. Each source handler is ACTUALLY wired at its commit point (source-text guard),
//      and management's expenseBreakdown is fed from the ledger (never fabricated).

import { assertEquals, assertStringIncludes } from "jsr:@std/assert@1";
import type { TenantQueryClient } from "../tenant_db.ts";
import type { TransportExpenseRow } from "../transport/transport_expenses_repository.ts";
import type { PayrollFinancePosting } from "../hr/hr_finance_posting_repository.ts";
import type { PurchaseOrderRow } from "../inventory_finance/inventory_finance_repository.ts";
import { listExpenseEntries } from "./expense_ledger_repository.ts";
import { buildExpenseBreakdown } from "./expense_ledger_breakdown.ts";
import {
  LEDGER_WIRE_SAVEPOINT,
  wireInventoryPurchaseToLedger,
  wirePayrollExpenseToLedger,
  wireTransportExpenseToLedger,
} from "./expense_ledger_wiring.ts";

const ORG = "a1000000-0000-4000-8000-000000000001";
const SCHOOL = "a2000000-0000-4000-8000-000000000001";
const PERIOD = ["2026-07-01", "2026-07-31"] as const;

// ─── Fake tenant db: models the ledger table + savepoint semantics ───────────
//
// Handles the SAVEPOINT / RELEASE / ROLLBACK TO the fence issues (as no-ops that it
// RECORDS, so the fence can be asserted), the idempotent INSERT, and the period
// SELECT. `failInsert` makes the ledger INSERT reject — modelling a genuine DB error
// (e.g. the table missing) — so we can prove the failure is isolated by the savepoint.
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

class FakeWireDb {
  entries: StoredEntry[] = [];
  savepointOps: string[] = [];
  failInsert = false;
  private seq = 0;

  // deno-lint-ignore no-explicit-any
  queryObject<T>(sql: string, args: any[] = []): Promise<T[]> {
    const q = sql.replace(/\s+/g, " ").trim();

    if (q.startsWith("SAVEPOINT")) {
      this.savepointOps.push("SAVEPOINT");
      return Promise.resolve([] as T[]);
    }
    if (q.startsWith("ROLLBACK TO SAVEPOINT")) {
      this.savepointOps.push("ROLLBACK_TO");
      return Promise.resolve([] as T[]);
    }
    if (q.startsWith("RELEASE SAVEPOINT")) {
      this.savepointOps.push("RELEASE");
      return Promise.resolve([] as T[]);
    }

    if (q.includes("INSERT INTO expense_ledger_entries")) {
      if (this.failInsert) {
        return Promise.reject(
          new Error('relation "expense_ledger_entries" does not exist'),
        );
      }
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

    if (q.includes("SELECT * FROM expense_ledger_entries")) {
      const [org, school, from, to] = args;
      const rows = this.entries
        .filter((e) =>
          e.organization_id === org && e.school_id === school &&
          e.incurred_on >= from && e.incurred_on <= to
        )
        .map((e) => ({ ...e, amount: e.amount.toFixed(2) }))
        .sort((a, b) =>
          a.incurred_on < b.incurred_on ? 1 : a.incurred_on > b.incurred_on ? -1 : 0
        );
      return Promise.resolve(rows as unknown as T[]);
    }

    throw new Error(`Unhandled SQL in FakeWireDb: ${q.slice(0, 80)}`);
  }
}

function db(fake: FakeWireDb): TenantQueryClient {
  return fake as unknown as TenantQueryClient;
}

function transportRow(overrides: Partial<TransportExpenseRow> = {}): TransportExpenseRow {
  return {
    id: "te-1",
    organization_id: ORG,
    school_id: SCHOOL,
    category: "fuel",
    vehicle_id: "veh-1",
    route_id: null,
    amount: "2000.00",
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

const payrollPosting: PayrollFinancePosting = {
  payrollRunId: "pay_7",
  period: "2026-07",
  grossAmount: 500000,
  netAmount: 430000,
  employeeCount: 12,
};

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

// ─── 1. Each source write ALSO posts exactly one ledger entry ────────────────

Deno.test("wiring: a recorded transport expense posts exactly ONE ledger entry", async () => {
  const fake = new FakeWireDb();
  const res = await wireTransportExpenseToLedger(db(fake), transportRow());
  assertEquals(res, { posted: true, entryId: "entry-1", isolatedFailure: false });
  assertEquals(fake.entries.length, 1);
  assertEquals(fake.entries[0].source_module, "transport");
  assertEquals(fake.entries[0].source_ref, "te-1");
  assertEquals(fake.entries[0].category, "fuel");
  assertEquals(fake.entries[0].amount, 2000);
  // The happy path opens and RELEASEs its fence (no rollback).
  assertEquals(fake.savepointOps, ["SAVEPOINT", "RELEASE"]);
});

Deno.test("wiring: a posted payroll run posts ONE 'salary' ledger entry at GROSS", async () => {
  const fake = new FakeWireDb();
  const res = await wirePayrollExpenseToLedger(db(fake), ORG, SCHOOL, payrollPosting, "2026-07-28");
  assertEquals(res.posted, true);
  assertEquals(fake.entries.length, 1);
  assertEquals(fake.entries[0].source_module, "payroll");
  assertEquals(fake.entries[0].source_ref, "pay_7");
  assertEquals(fake.entries[0].category, "salary");
  assertEquals(fake.entries[0].amount, 500000); // GROSS, not net
});

Deno.test("wiring: an approved purchase order posts ONE 'procurement' ledger entry", async () => {
  const fake = new FakeWireDb();
  const res = await wireInventoryPurchaseToLedger(db(fake), ORG, SCHOOL, poRow());
  assertEquals(res.posted, true);
  assertEquals(fake.entries.length, 1);
  assertEquals(fake.entries[0].source_module, "inventory");
  assertEquals(fake.entries[0].source_ref, "po-1");
  assertEquals(fake.entries[0].category, "procurement");
  assertEquals(fake.entries[0].amount, 25000);
  // Defaults incurredOn to the PO's created date when the caller passes none.
  assertEquals(fake.entries[0].incurred_on, "2026-07-09");
});

Deno.test("wiring: a VOIDed transport expense / draft PO posts nothing (never counts)", async () => {
  const fake = new FakeWireDb();
  const voided = await wireTransportExpenseToLedger(db(fake), transportRow({ status: "void" }));
  const draft = await wireInventoryPurchaseToLedger(db(fake), ORG, SCHOOL, poRow({ status: "draft" }));
  assertEquals(voided.posted, false);
  assertEquals(draft.posted, false);
  assertEquals(fake.entries.length, 0);
});

// ─── 2. A ledger-post failure does NOT break the source write ────────────────

Deno.test("wiring: a failing ledger INSERT is ISOLATED — no throw, source write unaffected", async () => {
  const fake = new FakeWireDb();
  fake.failInsert = true; // model a genuine DB error (e.g. table missing)

  // The wiring MUST resolve (never throw) so the source handler continues to COMMIT.
  const res = await wireTransportExpenseToLedger(db(fake), transportRow());

  assertEquals(res, { posted: false, entryId: null, isolatedFailure: true });
  assertEquals(fake.entries.length, 0, "nothing was written");
  // The fence fired: opened, rolled back ONLY the projection, then released. The
  // source write (which ran BEFORE this savepoint) is therefore left intact for COMMIT.
  assertEquals(fake.savepointOps, ["SAVEPOINT", "ROLLBACK_TO", "RELEASE"]);
});

Deno.test("wiring: the same isolation holds for payroll and inventory posts", async () => {
  for (const post of [
    (f: FakeWireDb) => wirePayrollExpenseToLedger(db(f), ORG, SCHOOL, payrollPosting, "2026-07-28"),
    (f: FakeWireDb) => wireInventoryPurchaseToLedger(db(f), ORG, SCHOOL, poRow()),
  ]) {
    const fake = new FakeWireDb();
    fake.failInsert = true;
    const res = await post(fake);
    assertEquals(res.isolatedFailure, true);
    assertEquals(res.posted, false);
    assertEquals(fake.entries.length, 0);
    assertEquals(fake.savepointOps, ["SAVEPOINT", "ROLLBACK_TO", "RELEASE"]);
  }
});

// ─── 3. No double-count on replay / backfill ─────────────────────────────────

Deno.test("wiring: re-posting the same source event does NOT double-count", async () => {
  const fake = new FakeWireDb();
  // Post each source twice (a retry / nightly backfill).
  for (let i = 0; i < 2; i++) {
    await wireTransportExpenseToLedger(db(fake), transportRow({ id: "te-1" }));
    await wirePayrollExpenseToLedger(db(fake), ORG, SCHOOL, payrollPosting, "2026-07-28");
    await wireInventoryPurchaseToLedger(db(fake), ORG, SCHOOL, poRow({ id: "po-1" }), "2026-07-09");
  }
  assertEquals(fake.entries.length, 3, "one row per source event despite the replay");
});

// ─── 4a. Management: the breakdown reflects REAL posted entries ──────────────

Deno.test("wiring: management's expenseBreakdown is built from the real posted ledger", async () => {
  const fake = new FakeWireDb();
  await wireTransportExpenseToLedger(db(fake), transportRow({ id: "te-1", amount: "2000.00", category: "fuel" }));
  await wirePayrollExpenseToLedger(db(fake), ORG, SCHOOL, payrollPosting, "2026-07-28");
  await wireInventoryPurchaseToLedger(db(fake), ORG, SCHOOL, poRow({ id: "po-1", total_amount: 25000 }), "2026-07-09");

  const entries = await listExpenseEntries(db(fake), ORG, SCHOOL, ...PERIOD);
  const breakdown = buildExpenseBreakdown(entries); // exactly what handleDashboard feeds

  assertEquals(breakdown.map((b) => b.label), ["salary", "procurement", "fuel"]);
  assertEquals(breakdown[0], { label: "salary", value: 500000, percent: 94.88, category: "salary", amount: 500000 });
  // Percentages of the real 527000 grand total — never a fabricated figure.
  const total = breakdown.reduce((s, b) => s + b.value, 0);
  assertEquals(total, 527000);
});

Deno.test("wiring: an empty ledger yields an EMPTY breakdown (honest, not fabricated)", async () => {
  const fake = new FakeWireDb();
  const entries = await listExpenseEntries(db(fake), ORG, SCHOOL, ...PERIOD);
  assertEquals(buildExpenseBreakdown(entries), []);
});

// ─── 4b. Source-text guards: each handler is ACTUALLY wired at its commit point ─

async function handlerSrc(rel: string): Promise<string> {
  return await Deno.readTextFile(new URL(rel, import.meta.url));
}

Deno.test("wired: the transport record handler calls the ledger wiring after the record", async () => {
  const src = await handlerSrc("../transport/transport_expenses_handlers.ts");
  assertStringIncludes(src, 'from "../expense_ledger/expense_ledger_wiring.ts"');
  assertStringIncludes(src, "await wireTransportExpenseToLedger(db, created)");
});

Deno.test("wired: the payroll process handler calls the ledger wiring after the finance posting", async () => {
  const src = await handlerSrc("../hr/hr_write_handlers.ts");
  assertStringIncludes(src, 'from "../expense_ledger/expense_ledger_wiring.ts"');
  assertStringIncludes(src, "await wirePayrollExpenseToLedger(db, organizationId, schoolId, posting, processedOn)");
});

Deno.test("wired: the PO approve handler calls the ledger wiring after approval", async () => {
  const src = await handlerSrc("../inventory_finance/inventory_finance_handlers.ts");
  assertStringIncludes(src, 'from "../expense_ledger/expense_ledger_wiring.ts"');
  assertStringIncludes(src, "await wireInventoryPurchaseToLedger(db, orgId, schoolId, approved.purchaseOrder)");
});

Deno.test("wired: the management dashboard builds expenseBreakdown from the ledger (not [])", async () => {
  const handler = await handlerSrc("../management/management_handlers.ts");
  assertStringIncludes(handler, "listExpenseEntries(db, orgId, schoolId, from, to)");
  assertStringIncludes(handler, "buildExpenseBreakdown(entries)");
  const builder = await handlerSrc("../management/management_payload_builders.ts");
  assertStringIncludes(builder, "expenseBreakdown,");
  assertEquals(builder.includes("expenseBreakdown: []"), false, "the honest-empty literal is gone — it is now live");
});

// ─── Sanity: the fence uses one stable savepoint name ────────────────────────

Deno.test("wiring: the fence savepoint name is stable", () => {
  assertEquals(LEDGER_WIRE_SAVEPOINT, "expense_ledger_wire");
});
