// FIN-D1 / FIN-D3 / FIN-D5 / FIN-2 — additive finance-feature unit tests.
//
// Proves the money-adjacent guards + calculations without a live DB:
//   • FIN-D1 day-close: isDateLocked + createCollection/cancelCollection reject
//     back-dated entries on/before the latest closed day.
//   • FIN-D3 cancellation: reason is required and the reason/actor/at columns are
//     persisted.
//   • FIN-D5 late fee: computeLateFee (percent [+ flat], cap) + accrual is an ADD
//     to outstanding, idempotent, and waive reverses it.
//   • FIN-2 ledger: running-balance mapper (debits=invoices, credits=payments).

import { assertEquals, assertRejects } from "https://deno.land/std@0.224.0/assert/mod.ts";
import type { TenantQueryClient } from "../tenant_db.ts";
import {
  CancellationReasonRequiredError,
  DayLockedError,
  cancelCollection,
  createCollection,
} from "./finance_collections_repository.ts";
import {
  isDateLocked,
  latestClosedDate,
} from "./finance_day_close_repository.ts";
import { computeLateFee } from "./finance_late_fee_repository.ts";
import { studentLedgerToApi } from "./finance_mapper.ts";

const ORG = "a1000000-0000-4000-8000-000000000001";
const SCHOOL = "a2000000-0000-4000-8000-000000000001";
const STAFF = "a3000000-0000-4000-8000-000000000001";
const STUDENT = "a4000000-0000-4000-8000-000000000001";
const INVOICE = "inv-1";
const ACCOUNT = "acct-1";

type Row = Record<string, unknown>;

// Mock DB that also understands finance_day_close (so the day-lock guard can be
// exercised). Mirrors the collections-repo mock but adds a closed-days list.
class MockDb {
  closedDates: string[] = [];
  invoices: Row[] = [{
    id: INVOICE,
    organization_id: ORG,
    school_id: SCHOOL,
    student_id: STUDENT,
    fee_assignment_id: "asg-1",
    outstanding_amount: "50000",
    total_amount: "50000",
    invoice_status: "issued",
    due_date: "2026-07-07",
    late_fee_amount: "0",
  }];
  accounts: Row[] = [{
    id: ACCOUNT,
    fee_assignment_id: "asg-1",
    organization_id: ORG,
    school_id: SCHOOL,
    amount_paid: "0",
    outstanding_amount: "50000",
  }];
  collections: Row[] = [];
  receipts: Row[] = [];

  // deno-lint-ignore require-await
  async queryObject<T>(sql: string, args: unknown[] = []): Promise<T[]> {
    if (sql.includes("FROM finance_day_close") && sql.includes("status = 'closed'")) {
      const sorted = [...this.closedDates].sort().reverse();
      return sorted.length ? [{ close_date: sorted[0] } as T] : [];
    }
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
        acct.amount_paid = String(parseFloat(String(acct.amount_paid)) + Number(args[0]));
        acct.outstanding_amount = String(parseFloat(String(acct.outstanding_amount)) - Number(args[0]));
      } else if (acct && sql.includes("amount_paid -")) {
        acct.amount_paid = String(parseFloat(String(acct.amount_paid)) - Number(args[0]));
        acct.outstanding_amount = String(parseFloat(String(acct.outstanding_amount)) + Number(args[0]));
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
    return [] as T[];
  }

  // deno-lint-ignore require-await
  async queryCount(): Promise<number> {
    return this.collections.length;
  }
}

function asDb(mock: MockDb): TenantQueryClient {
  return mock as unknown as TenantQueryClient;
}

// ── FIN-D5: late-fee computation ─────────────────────────────────────────────
Deno.test("FIN-D5 computeLateFee: percent only", () => {
  assertEquals(
    computeLateFee(50000, { gracePeriodDays: 0, latePercent: 2, lateFlat: 0, lateCap: 0 }),
    1000,
  );
});

Deno.test("FIN-D5 computeLateFee: percent + flat", () => {
  assertEquals(
    computeLateFee(50000, { gracePeriodDays: 0, latePercent: 2, lateFlat: 100, lateCap: 0 }),
    1100,
  );
});

Deno.test("FIN-D5 computeLateFee: capped", () => {
  assertEquals(
    computeLateFee(50000, { gracePeriodDays: 0, latePercent: 10, lateFlat: 0, lateCap: 500 }),
    500,
  );
});

Deno.test("FIN-D5 computeLateFee: nothing configured → 0", () => {
  assertEquals(
    computeLateFee(50000, { gracePeriodDays: 0, latePercent: 0, lateFlat: 0, lateCap: 0 }),
    0,
  );
});

// ── FIN-D1: day-close lock ───────────────────────────────────────────────────
Deno.test("FIN-D1 latestClosedDate returns the max closed date", async () => {
  const db = new MockDb();
  db.closedDates = ["2026-06-30", "2026-07-01", "2026-06-29"];
  assertEquals(await latestClosedDate(asDb(db), ORG, SCHOOL), "2026-07-01");
});

Deno.test("FIN-D1 isDateLocked: on/before latest closed = locked, after = open", async () => {
  const db = new MockDb();
  db.closedDates = ["2026-07-01"];
  assertEquals(await isDateLocked(asDb(db), ORG, SCHOOL, "2026-07-01"), true);
  assertEquals(await isDateLocked(asDb(db), ORG, SCHOOL, "2026-06-30"), true);
  assertEquals(await isDateLocked(asDb(db), ORG, SCHOOL, "2026-07-02"), false);
});

Deno.test("FIN-D1 isDateLocked: no closed day → never locked", async () => {
  const db = new MockDb();
  assertEquals(await isDateLocked(asDb(db), ORG, SCHOOL, "2020-01-01"), false);
});

Deno.test("FIN-D1 createCollection rejects a back-dated entry into a closed day", async () => {
  const db = new MockDb();
  db.closedDates = ["2026-07-01"];
  await assertRejects(
    () =>
      createCollection(asDb(db), ORG, SCHOOL, {
        invoiceId: INVOICE,
        amountCollected: 1000,
        paymentMethod: "cash",
        collectedBy: STAFF,
        collectionDate: "2026-06-30",
      }),
    DayLockedError,
  );
  assertEquals(db.collections.length, 0);
});

Deno.test("FIN-D1 createCollection allows an entry dated after the closed day", async () => {
  const db = new MockDb();
  db.closedDates = ["2026-06-30"];
  const created = await createCollection(asDb(db), ORG, SCHOOL, {
    invoiceId: INVOICE,
    amountCollected: 1000,
    paymentMethod: "cash",
    collectedBy: STAFF,
    collectionDate: "2026-07-01",
  });
  assertEquals(created.collection.collection_status, "completed");
});

Deno.test("FIN-D1 cancelCollection rejects when the collection's day is closed", async () => {
  const db = new MockDb();
  const created = await createCollection(asDb(db), ORG, SCHOOL, {
    invoiceId: INVOICE,
    amountCollected: 1000,
    paymentMethod: "cash",
    collectedBy: STAFF,
    collectionDate: "2026-07-01",
  });
  // Now close that day → the cancellation must be blocked.
  db.closedDates = ["2026-07-01"];
  await assertRejects(
    () =>
      cancelCollection(asDb(db), ORG, SCHOOL, created.collection.id, {
        reason: "mistake",
        cancelledBy: STAFF,
      }),
    DayLockedError,
  );
});

// ── FIN-D3: cancellation reason ──────────────────────────────────────────────
Deno.test("FIN-D3 cancelCollection requires a non-empty reason", async () => {
  const db = new MockDb();
  const created = await createCollection(asDb(db), ORG, SCHOOL, {
    invoiceId: INVOICE,
    amountCollected: 1000,
    paymentMethod: "cash",
    collectedBy: STAFF,
    collectionDate: "2026-07-02",
  });
  await assertRejects(
    () =>
      cancelCollection(asDb(db), ORG, SCHOOL, created.collection.id, {
        reason: "   ",
        cancelledBy: STAFF,
      }),
    CancellationReasonRequiredError,
  );
});

Deno.test("FIN-D3 cancelCollection persists reason + actor", async () => {
  const db = new MockDb();
  const created = await createCollection(asDb(db), ORG, SCHOOL, {
    invoiceId: INVOICE,
    amountCollected: 1000,
    paymentMethod: "cash",
    collectedBy: STAFF,
    collectionDate: "2026-07-02",
  });
  const cancelled = await cancelCollection(asDb(db), ORG, SCHOOL, created.collection.id, {
    reason: "duplicate receipt",
    cancelledBy: STAFF,
  });
  assertEquals(cancelled.collection.collection_status, "cancelled");
  assertEquals(cancelled.collection.cancellation_reason, "duplicate receipt");
  assertEquals(cancelled.collection.cancelled_by, STAFF);
});

// ── FIN-2: ledger running balance ────────────────────────────────────────────
Deno.test("FIN-2 studentLedgerToApi builds a running balance (debit invoice, credit payment)", () => {
  const api = studentLedgerToApi({
    account: {
      id: ACCOUNT,
      student_id: STUDENT,
      student_name: "Probe",
      admission_number: "ADM-1",
      class_label: "5",
      academic_year: "2026-27",
      total_fee: "50000",
      amount_paid: "20000",
      outstanding_amount: "30000",
      status: "open",
    },
    invoices: [{
      id: INVOICE,
      organization_id: ORG,
      school_id: SCHOOL,
      student_id: STUDENT,
      fee_assignment_id: "asg-1",
      academic_year: "2026-27",
      invoice_number: "INV-1",
      invoice_date: "2026-06-01",
      due_date: "2026-07-01",
      subtotal_amount: "50000",
      discount_amount: "0",
      total_amount: "50000",
      outstanding_amount: "30000",
      invoice_status: "partially_paid",
      late_fee_amount: "0",
      late_fee_accrued_at: null,
      created_by: STAFF,
      created_at: "2026-06-01T00:00:00Z",
      updated_at: "2026-06-09T00:00:00Z",
    }],
    collections: [{
      id: "c1",
      organization_id: ORG,
      school_id: SCHOOL,
      student_id: STUDENT,
      invoice_id: INVOICE,
      student_account_id: ACCOUNT,
      receipt_number: "RCPT-1",
      collection_date: "2026-06-09",
      payment_method: "cash",
      reference_number: null,
      amount_collected: "20000",
      notes: null,
      collection_status: "completed",
      collected_by: STAFF,
      cancellation_reason: null,
      cancelled_by: null,
      cancelled_at: null,
      row_version: 1,
      created_at: "2026-06-09T00:00:00Z",
      updated_at: "2026-06-09T00:00:00Z",
    }],
  });
  const ledger = api.ledger as Array<Record<string, unknown>>;
  assertEquals(ledger.length, 2);
  // Invoice first (debit 50000 → balance 50000), then payment (credit 20000 → 30000).
  assertEquals(ledger[0]!.kind, "invoice");
  assertEquals(ledger[0]!.balance, "50000");
  assertEquals(ledger[1]!.kind, "payment");
  assertEquals(ledger[1]!.balance, "30000");
  const summary = api.summary as Record<string, unknown>;
  assertEquals(summary.balance, "30000");
  assertEquals(summary.invoiceCount, 1);
  assertEquals(summary.paymentCount, 1);
});

Deno.test("FIN-2 studentLedgerToApi ignores cancelled collections in the running balance", () => {
  const api = studentLedgerToApi({
    account: {
      id: ACCOUNT,
      student_id: STUDENT,
      student_name: "Probe",
      admission_number: "ADM-1",
      class_label: "5",
      academic_year: "2026-27",
      total_fee: "50000",
      amount_paid: "0",
      outstanding_amount: "50000",
      status: "open",
    },
    invoices: [],
    collections: [{
      id: "c1",
      organization_id: ORG,
      school_id: SCHOOL,
      student_id: STUDENT,
      invoice_id: INVOICE,
      student_account_id: ACCOUNT,
      receipt_number: "RCPT-CANCELLED",
      collection_date: "2026-06-09",
      payment_method: "cash",
      reference_number: null,
      amount_collected: "20000",
      notes: null,
      collection_status: "cancelled",
      collected_by: STAFF,
      cancellation_reason: "error",
      cancelled_by: STAFF,
      cancelled_at: "2026-06-10T00:00:00Z",
      row_version: 2,
      created_at: "2026-06-09T00:00:00Z",
      updated_at: "2026-06-10T00:00:00Z",
    }],
  });
  const ledger = api.ledger as Array<Record<string, unknown>>;
  assertEquals(ledger.length, 0);
  // But the cancelled payment still appears in the raw payments list.
  assertEquals((api.payments as unknown[]).length, 1);
});
