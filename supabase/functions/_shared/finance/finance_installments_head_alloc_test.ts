// FIN-6 / FIN-D2 / FIN-9 — installment schedule + per-head allocation tests.
//
// The load-bearing test is the RECONCILIATION INVARIANT (money-safety, owner-
// mandated): after ANY collection or cancellation,
//   SUM(head_paid_minor) for the invoice == amount_paid (= total - outstanding).
// It is driven end-to-end through createCollection / cancelCollection so the
// derived head ledger is proven to track the (unchanged) outstanding math.
//
// Also covers: installment schedule parsing/plan (exact-sum), tuition-first
// allocation order, reversal order, seed fallback to a single General head, and
// the FIN-9 head-wise dues rollup shape.

import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import type { TenantQueryClient } from "../tenant_db.ts";
import { createCollection, cancelCollection } from "./finance_collections_repository.ts";
import {
  buildInstallmentPlan,
  parseInstallmentOffsets,
} from "./finance_installments_repository.ts";
import {
  headWiseDues,
  seedHeadAllocations,
  type FinanceInvoiceHeadAllocationRow,
} from "./finance_head_allocations_repository.ts";
import { headAllocationToApi, headWiseDueToApi } from "./finance_mapper.ts";

const ORG = "a1000000-0000-4000-8000-000000000001";
const SCHOOL = "a2000000-0000-4000-8000-000000000001";
const STAFF = "a3000000-0000-4000-8000-000000000001";
const STUDENT = "a4000000-0000-4000-8000-000000000001";
const INVOICE = "inv-1";
const ACCOUNT = "acct-1";
const ASSIGNMENT = "asg-1";

type Row = Record<string, unknown>;

function num(v: unknown): number {
  const n = typeof v === "number" ? v : parseFloat(String(v));
  return Number.isFinite(n) ? n : 0;
}

/**
 * Mock DB that models BOTH the existing money path (invoice/account outstanding)
 * AND the FIN-D2 head-allocation ledger, so createCollection/cancelCollection
 * exercise the real repo code and we can assert reconciliation from the stored
 * head rows.
 */
class MockDb {
  invoices: Row[] = [{
    id: INVOICE,
    organization_id: ORG,
    school_id: SCHOOL,
    student_id: STUDENT,
    fee_assignment_id: ASSIGNMENT,
    outstanding_amount: "50000",
    total_amount: "50000",
    invoice_status: "issued",
    due_date: "2026-07-07",
  }];
  accounts: Row[] = [{
    id: ACCOUNT,
    fee_assignment_id: ASSIGNMENT,
    organization_id: ORG,
    school_id: SCHOOL,
    amount_paid: "0",
    outstanding_amount: "50000",
  }];
  collections: Row[] = [];
  receipts: Row[] = [];
  heads: Row[] = []; // finance_invoice_head_allocations
  // structure items linked via the assignment (tuition first by sort_order).
  structureItems: Row[] = [
    { fee_head: "tuition:Tuition", amount: "30000", sort_order: 0 },
    { fee_head: "transport:Transport", amount: "15000", sort_order: 1 },
    { fee_head: "lab:Lab", amount: "5000", sort_order: 2 },
  ];

  // deno-lint-ignore require-await
  async queryObject<T>(sql: string, args: unknown[] = []): Promise<T[]> {
    // ── finance_settings (getFinanceSettingValue) ──
    if (sql.includes("SELECT * FROM finance_settings")) {
      return [] as T[]; // no overrides → template defaults
    }

    // ── head-allocation structure items (seed) ──
    if (sql.includes("finance_fee_structure_items fsi") && sql.includes("JOIN finance_fee_assignments")) {
      return this.structureItems as T[];
    }
    if (sql.includes("INSERT INTO finance_invoice_head_allocations")) {
      // ON CONFLICT DO NOTHING — skip if (invoice_id, fee_head) exists.
      const exists = this.heads.some((h) => h.invoice_id === args[2] && h.fee_head === args[3]);
      if (!exists) {
        this.heads.push({
          id: crypto.randomUUID(),
          organization_id: args[0],
          school_id: args[1],
          invoice_id: args[2],
          fee_head: args[3],
          head_label: args[4],
          head_total_minor: String(args[5]),
          head_paid_minor: "0",
          sort_order: Number(args[6]),
          priority: Number(args[7]),
          created_at: new Date().toISOString(),
          updated_at: new Date().toISOString(),
        });
      }
      return [] as T[];
    }
    if (sql.includes("SELECT * FROM finance_invoice_head_allocations")) {
      let rows = this.heads.filter((h) =>
        h.invoice_id === args[0] && h.organization_id === args[1] && h.school_id === args[2]
      );
      if (sql.includes("priority DESC")) {
        rows = [...rows].sort((a, b) =>
          Number(b.priority) - Number(a.priority) ||
          Number(b.sort_order) - Number(a.sort_order)
        );
      } else {
        rows = [...rows].sort((a, b) =>
          Number(a.priority) - Number(b.priority) ||
          Number(a.sort_order) - Number(b.sort_order)
        );
      }
      return rows as T[];
    }
    if (sql.includes("UPDATE finance_invoice_head_allocations") && sql.includes("head_paid_minor = $1")) {
      const h = this.heads.find((r) => r.id === args[1]);
      if (h) h.head_paid_minor = String(args[0]);
      return [] as T[];
    }

    // ── existing money path (mirrors the collections-repo mock) ──
    if (sql.includes("FROM finance_invoices fi") && sql.includes("JOIN finance_student_accounts")) {
      const inv = this.invoices.find((i) => i.id === args[0]);
      if (!inv) return [] as T[];
      const acct = this.accounts.find((a) => a.fee_assignment_id === inv.fee_assignment_id);
      return [{ ...inv, student_account_id: acct?.id }] as T[];
    }
    if (sql.includes("INSERT INTO finance_collections")) {
      const row = {
        id: crypto.randomUUID(),
        organization_id: args[0],
        school_id: args[1],
        student_id: args[2],
        invoice_id: args[3],
        student_account_id: args[4],
        receipt_number: args[5],
        collection_date: args[6],
        payment_method: args[7],
        reference_number: args[8],
        amount_collected: String(args[9]),
        notes: args[10],
        collection_status: "completed",
        collected_by: args[11],
        cancellation_reason: null,
        cancelled_by: null,
        cancelled_at: null,
        row_version: 1,
      };
      this.collections.push(row);
      return [row as T];
    }
    if (sql.includes("INSERT INTO finance_receipts")) {
      const row = {
        id: crypto.randomUUID(),
        collection_id: args[2],
        receipt_number: args[3],
        receipt_date: args[4],
        amount: String(args[5]),
        generated_by: args[6],
      };
      this.receipts.push(row);
      return [row as T];
    }
    if (sql.includes("UPDATE finance_invoices SET") && sql.includes("outstanding_amount")) {
      const inv = this.invoices.find((i) => i.id === args[2]);
      if (inv) {
        inv.outstanding_amount = String(args[0]);
        inv.invoice_status = String(args[1]);
      }
      return [] as T[];
    }
    if (sql.includes("UPDATE finance_student_accounts SET")) {
      const acct = this.accounts.find((a) => a.id === args[1]);
      if (acct && sql.includes("amount_paid +")) {
        acct.amount_paid = String(num(acct.amount_paid) + num(args[0]));
        acct.outstanding_amount = String(num(acct.outstanding_amount) - num(args[0]));
      } else if (acct && sql.includes("amount_paid -")) {
        acct.amount_paid = String(num(acct.amount_paid) - num(args[0]));
        acct.outstanding_amount = String(num(acct.outstanding_amount) + num(args[0]));
      }
      return [] as T[];
    }
    if (sql.includes("SELECT * FROM finance_invoices WHERE id = $1")) {
      return this.invoices.filter((i) => i.id === args[0]) as T[];
    }
    if (sql.includes("SELECT * FROM finance_receipts") && sql.includes("collection_id = $1")) {
      return this.receipts.filter((r) => r.collection_id === args[0]) as T[];
    }
    if (sql.includes("UPDATE finance_collections SET") && sql.includes("cancelled")) {
      const row = this.collections.find((c) => c.id === args[0]);
      if (row) {
        row.collection_status = "cancelled";
        row.cancellation_reason = args[3];
        row.cancelled_by = args[4];
        row.cancelled_at = "2026-07-01T00:00:00Z";
      }
      return (row ? [row] : []) as T[];
    }
    if (sql.includes("FROM finance_collections fc") && sql.includes("WHERE fc.id = $1")) {
      const row = this.collections.find((c) => c.id === args[0]);
      return (row ? [{ ...row, student_name: "Probe" }] : []) as T[];
    }

    // ── FIN-9 head-wise dues rollup ──
    if (sql.includes("FROM finance_invoice_head_allocations ha") && sql.includes("GROUP BY ha.fee_head")) {
      const byHead = new Map<string, { label: string; dues: number }>();
      for (const h of this.heads) {
        const inv = this.invoices.find((i) => i.id === h.invoice_id);
        if (!inv || !["issued", "partially_paid"].includes(String(inv.invoice_status))) continue;
        const remaining = num(h.head_total_minor) - num(h.head_paid_minor);
        const cur = byHead.get(String(h.fee_head)) ?? { label: String(h.head_label), dues: 0 };
        cur.dues += remaining;
        byHead.set(String(h.fee_head), cur);
      }
      const out = [...byHead.entries()]
        .filter(([, v]) => v.dues > 0)
        .map(([fee_head, v]) => ({ fee_head, head_label: v.label, dues: String(v.dues) }))
        .sort((a, b) => num(b.dues) - num(a.dues));
      return out as T[];
    }

    return [] as T[];
  }

  // deno-lint-ignore require-await
  async queryCount(): Promise<number> {
    return this.collections.length;
  }

  /** Test helper — amount_paid for the invoice (= total - outstanding). */
  amountPaid(): number {
    const inv = this.invoices[0]!;
    return num(inv.total_amount) - num(inv.outstanding_amount);
  }

  /** Test helper — SUM(head_paid) for the invoice. */
  sumHeadPaid(): number {
    return this.heads
      .filter((h) => h.invoice_id === INVOICE)
      .reduce((s, h) => s + num(h.head_paid_minor), 0);
  }
}

function asDb(mock: MockDb): TenantQueryClient {
  return mock as unknown as TenantQueryClient;
}

async function seed(db: MockDb): Promise<void> {
  await seedHeadAllocations(asDb(db), ORG, SCHOOL, INVOICE, ASSIGNMENT, 50000);
}

// ── FIN-6: installment schedule ──────────────────────────────────────────────
Deno.test("FIN-6 parseInstallmentOffsets: '1' → single term at due-days", () => {
  assertEquals(parseInstallmentOffsets("1", 30), [30]);
  assertEquals(parseInstallmentOffsets("", 45), [45]);
});

Deno.test("FIN-6 parseInstallmentOffsets: CSV of explicit day offsets", () => {
  assertEquals(parseInstallmentOffsets("0,90,180,270", 30), [0, 90, 180, 270]);
});

Deno.test("FIN-6 parseInstallmentOffsets: N terms evenly spread across a year", () => {
  assertEquals(parseInstallmentOffsets("4", 30), [0, 91, 183, 274]);
});

Deno.test("FIN-6 parseInstallmentOffsets: malformed → single fallback term", () => {
  assertEquals(parseInstallmentOffsets("abc", 30), [30]);
});

Deno.test("FIN-6 buildInstallmentPlan: terms sum EXACTLY to the total (remainder on last)", () => {
  const issue = new Date("2026-06-01T00:00:00.000Z");
  const plan = buildInstallmentPlan(issue, 50000, [0, 90, 180]);
  assertEquals(plan.length, 3);
  const sum = plan.reduce((s, t) => s + t.amount, 0);
  assertEquals(Math.round(sum * 100) / 100, 50000);
  assertEquals(plan[0]!.termNo, 1);
  assertEquals(plan[0]!.dueDate, "2026-06-01");
  assertEquals(plan[2]!.dueDate, "2026-11-28");
});

Deno.test("FIN-6 buildInstallmentPlan: uneven split still sums exactly", () => {
  const issue = new Date("2026-06-01T00:00:00.000Z");
  const plan = buildInstallmentPlan(issue, 100, [0, 30, 60]); // 33.33 * 3 = 99.99
  const sum = plan.reduce((s, t) => s + t.amount, 0);
  assertEquals(Math.round(sum * 100) / 100, 100);
  assertEquals(plan[2]!.amount, 33.34); // last term absorbs the remainder
});

// ── FIN-D2: seeding ──────────────────────────────────────────────────────────
Deno.test("FIN-D2 seed: heads from structure items, tuition gets top priority", async () => {
  const db = new MockDb();
  await seed(db);
  assertEquals(db.heads.length, 3);
  const tuition = db.heads.find((h) => h.fee_head === "tuition:Tuition")!;
  const transport = db.heads.find((h) => h.fee_head === "transport:Transport")!;
  assertEquals(tuition.priority, 0);
  assertEquals(transport.priority, 1);
  // Seeded heads sum to the invoice total (reconcile baseline).
  assertEquals(db.heads.reduce((s, h) => s + num(h.head_total_minor), 0), 50000);
});

Deno.test("FIN-D2 seed fallback: no/mismatched structure items → single General head = total", async () => {
  const db = new MockDb();
  db.structureItems = []; // breakdown unreachable
  await seed(db);
  assertEquals(db.heads.length, 1);
  assertEquals(db.heads[0]!.fee_head, "general:General");
  assertEquals(num(db.heads[0]!.head_total_minor), 50000);
});

// ── FIN-D2: RECONCILIATION INVARIANT (the load-bearing money-safety test) ─────
Deno.test("FIN-D2 RECONCILE: SUM(head_paid) == amount_paid after each collection (tuition first)", async () => {
  const db = new MockDb();
  await seed(db);

  // 1) Part payment of 20000 → fills tuition (30000 total) partially.
  await createCollection(asDb(db), ORG, SCHOOL, {
    invoiceId: INVOICE,
    amountCollected: 20000,
    paymentMethod: "cash",
    collectedBy: STAFF,
  });
  assertEquals(db.amountPaid(), 20000);
  assertEquals(db.sumHeadPaid(), db.amountPaid());
  const tuition = db.heads.find((h) => h.fee_head === "tuition:Tuition")!;
  assertEquals(num(tuition.head_paid_minor), 20000); // tuition first

  // 2) Another 20000 → tuition tops out at 30000, spillover to transport (10000).
  await createCollection(asDb(db), ORG, SCHOOL, {
    invoiceId: INVOICE,
    amountCollected: 20000,
    paymentMethod: "cash",
    collectedBy: STAFF,
  });
  assertEquals(db.amountPaid(), 40000);
  assertEquals(db.sumHeadPaid(), db.amountPaid());
  assertEquals(num(db.heads.find((h) => h.fee_head === "tuition:Tuition")!.head_paid_minor), 30000);
  assertEquals(num(db.heads.find((h) => h.fee_head === "transport:Transport")!.head_paid_minor), 10000);

  // 3) Final 10000 → fully paid; every head at its total.
  await createCollection(asDb(db), ORG, SCHOOL, {
    invoiceId: INVOICE,
    amountCollected: 10000,
    paymentMethod: "cash",
    collectedBy: STAFF,
  });
  assertEquals(db.amountPaid(), 50000);
  assertEquals(db.sumHeadPaid(), 50000);
  assertEquals(db.invoices[0]!.invoice_status, "paid");
  for (const h of db.heads) {
    assertEquals(num(h.head_paid_minor), num(h.head_total_minor));
  }
});

Deno.test("FIN-D2 RECONCILE: cancellation reverses in reverse-priority; SUM(head_paid) == amount_paid", async () => {
  const db = new MockDb();
  await seed(db);

  await createCollection(asDb(db), ORG, SCHOOL, {
    invoiceId: INVOICE,
    amountCollected: 35000, // tuition 30000 + transport 5000
    paymentMethod: "cash",
    collectedBy: STAFF,
  });
  assertEquals(db.sumHeadPaid(), 35000);

  const c2 = await createCollection(asDb(db), ORG, SCHOOL, {
    invoiceId: INVOICE,
    amountCollected: 10000, // transport +10000 (now 15000 full), lab 0
    paymentMethod: "cash",
    collectedBy: STAFF,
  });
  assertEquals(db.amountPaid(), 45000);
  assertEquals(db.sumHeadPaid(), 45000);

  // Cancel the 2nd (10000). Reverse-priority: lab (0) then transport → transport
  // drops by 10000 back to 5000. Reconciliation holds at 35000.
  await cancelCollection(asDb(db), ORG, SCHOOL, c2.collection.id, {
    reason: "wrong amount",
    cancelledBy: STAFF,
  });
  assertEquals(db.amountPaid(), 35000);
  assertEquals(db.sumHeadPaid(), 35000);
  assertEquals(num(db.heads.find((h) => h.fee_head === "transport:Transport")!.head_paid_minor), 5000);
  assertEquals(num(db.heads.find((h) => h.fee_head === "tuition:Tuition")!.head_paid_minor), 30000);
});

Deno.test("FIN-D2 RECONCILE: General-head fallback still reconciles across collect/cancel", async () => {
  const db = new MockDb();
  db.structureItems = [];
  await seed(db);

  const c = await createCollection(asDb(db), ORG, SCHOOL, {
    invoiceId: INVOICE,
    amountCollected: 12345,
    paymentMethod: "cash",
    collectedBy: STAFF,
  });
  assertEquals(db.sumHeadPaid(), 12345);
  assertEquals(db.sumHeadPaid(), db.amountPaid());

  await cancelCollection(asDb(db), ORG, SCHOOL, c.collection.id, {
    reason: "test",
    cancelledBy: STAFF,
  });
  assertEquals(db.sumHeadPaid(), 0);
  assertEquals(db.sumHeadPaid(), db.amountPaid());
});

// ── FIN-9: head-wise dues ────────────────────────────────────────────────────
Deno.test("FIN-9 headWiseDues: per-head remaining across open invoice", async () => {
  const db = new MockDb();
  await seed(db);
  await createCollection(asDb(db), ORG, SCHOOL, {
    invoiceId: INVOICE,
    amountCollected: 20000, // tuition partially paid
    paymentMethod: "cash",
    collectedBy: STAFF,
  });
  const dues = await headWiseDues(asDb(db), ORG, SCHOOL);
  const tuition = dues.find((d) => d.fee_head === "tuition:Tuition")!;
  assertEquals(num(tuition.dues), 10000); // 30000 - 20000
  const transport = dues.find((d) => d.fee_head === "transport:Transport")!;
  assertEquals(num(transport.dues), 15000);
  // Total dues equals invoice outstanding (self-consistent with the money path).
  const totalDues = dues.reduce((s, d) => s + num(d.dues), 0);
  assertEquals(totalDues, num(db.invoices[0]!.outstanding_amount));
});

// ── mappers ──────────────────────────────────────────────────────────────────
Deno.test("headAllocationToApi maps total/paid/remaining + category", () => {
  const api = headAllocationToApi({
    fee_head: "tuition:Tuition",
    head_label: "Tuition",
    head_total_minor: "30000",
    head_paid_minor: "12000",
    sort_order: 0,
    priority: 0,
  } as FinanceInvoiceHeadAllocationRow);
  assertEquals(api.category, "tuition");
  assertEquals(api.total, "30000");
  assertEquals(api.paid, "12000");
  assertEquals(api.remaining, "18000");
});

Deno.test("headWiseDueToApi maps fee head + dues", () => {
  const api = headWiseDueToApi({ fee_head: "transport:Bus", head_label: "Bus", dues: "15000" });
  assertEquals(api.feeHead, "transport:Bus");
  assertEquals(api.category, "transport");
  assertEquals(api.label, "Bus");
  assertEquals(api.dues, "15000");
});
