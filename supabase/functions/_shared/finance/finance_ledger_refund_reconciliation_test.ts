// PRA-P1-11 (S1) — the parent fee statement must not contradict its own summary
// after a refund.
//
// Before this fix, studentLedgerToApi built the ledger from invoices (debit
// total_amount) + collections (credit amount_collected), skipping only
// 'cancelled' collections. A REFUNDED collection keeps status 'refunded' /
// 'partially_refunded', so it survived the filter and still credited its full
// original amount — driving the running balance to 0 — while the summary read
// account.outstanding_amount (which applyProcessedRefund had raised back). The
// printed statement showed "balance 0" beside "Balance ₹10,000".
//
// These tests prove:
//   1. the mapper now debits each processed refund, so the running balance ends
//      at account.outstanding_amount (full-refund case);
//   2. a partially_refunded collection debits only the refunded portion (no
//      double count);
//   3. getStudentLedger actually LOADS the processed refunds and the end-to-end
//      output reconciles.

import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import type { TenantQueryClient } from "../tenant_db.ts";
import {
  getStudentLedger,
  type StudentLedger,
} from "./finance_ledger_repository.ts";
import { studentLedgerToApi } from "./finance_mapper.ts";

const ORG = "b1000000-0000-4000-8000-000000000001";
const SCHOOL = "b2000000-0000-4000-8000-000000000001";
const STAFF = "b3000000-0000-4000-8000-000000000001";
const STUDENT = "b4000000-0000-4000-8000-000000000001";
const INVOICE = "inv-1";
const ACCOUNT = "acct-1";

type Row = Record<string, unknown>;

// ── helpers ──────────────────────────────────────────────────────────────────

function makeInvoice(overrides: Row = {}): Row {
  return {
    id: INVOICE,
    organization_id: ORG,
    school_id: SCHOOL,
    student_id: STUDENT,
    fee_assignment_id: "asg-1",
    academic_year: "2026-27",
    invoice_number: "INV-1",
    invoice_date: "2026-06-01",
    due_date: "2026-07-01",
    subtotal_amount: "10000",
    discount_amount: "0",
    total_amount: "10000",
    // outstanding on the invoice was raised back by applyProcessedRefund.
    outstanding_amount: "10000",
    invoice_status: "issued",
    late_fee_amount: "0",
    late_fee_accrued_at: null,
    created_by: STAFF,
    created_at: "2026-06-01T00:00:00Z",
    updated_at: "2026-06-15T00:00:00Z",
    ...overrides,
  };
}

function makeCollection(overrides: Row = {}): Row {
  return {
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
    amount_collected: "10000",
    notes: null,
    // NOT 'cancelled' — this is the row that survived the old filter.
    collection_status: "refunded",
    collected_by: STAFF,
    cancellation_reason: null,
    cancelled_by: null,
    cancelled_at: null,
    row_version: 2,
    created_at: "2026-06-09T00:00:00Z",
    updated_at: "2026-06-15T00:00:00Z",
    ...overrides,
  };
}

function makeRefund(overrides: Row = {}): Row {
  return {
    id: "r1",
    refund_amount: "10000",
    refund_status: "processed",
    refund_date: "2026-06-15",
    receipt_number: "RCPT-1",
    ...overrides,
  };
}

// ── 1. mapper reconciles a full refund ───────────────────────────────────────
Deno.test("PRA-P1-11 studentLedgerToApi debits a processed refund → running balance == outstanding", () => {
  const api = studentLedgerToApi({
    account: {
      id: ACCOUNT,
      student_id: STUDENT,
      student_name: "Probe",
      admission_number: "ADM-1",
      class_label: "5",
      academic_year: "2026-27",
      total_fee: "10000",
      // fully paid then fully refunded → back to owing the whole amount.
      amount_paid: "0",
      outstanding_amount: "10000",
      status: "open",
    },
    invoices: [makeInvoice()] as never,
    collections: [makeCollection()] as never,
    refunds: [makeRefund()] as never,
  });

  const ledger = api.ledger as Array<Record<string, unknown>>;
  const summary = api.summary as Record<string, unknown>;

  // invoice debit → payment credit → refund debit.
  assertEquals(ledger.length, 3);
  assertEquals(ledger[0]!.kind, "invoice");
  assertEquals(ledger[0]!.balance, "10000");
  assertEquals(ledger[1]!.kind, "payment");
  assertEquals(ledger[1]!.balance, "0");
  assertEquals(ledger[2]!.kind, "refund");
  assertEquals(ledger[2]!.debit, "10000");

  // The whole point: the ledger's final running balance now equals the summary,
  // which equals account.outstanding_amount.
  assertEquals(ledger[ledger.length - 1]!.balance, "10000");
  assertEquals(summary.balance, "10000");
  assertEquals(ledger[ledger.length - 1]!.balance, summary.balance);
});

// ── 2. partial refund debits only the refunded portion ───────────────────────
Deno.test("PRA-P1-11 partially_refunded collection debits only the refunded portion (no double count)", () => {
  const api = studentLedgerToApi({
    account: {
      id: ACCOUNT,
      student_id: STUDENT,
      student_name: "Probe",
      admission_number: "ADM-1",
      class_label: "5",
      academic_year: "2026-27",
      total_fee: "10000",
      amount_paid: "7000",
      outstanding_amount: "3000",
      status: "open",
    },
    invoices: [makeInvoice({ outstanding_amount: "3000", invoice_status: "partially_paid" })] as never,
    collections: [makeCollection({ collection_status: "partially_refunded" })] as never,
    refunds: [makeRefund({ refund_amount: "3000" })] as never,
  });

  const ledger = api.ledger as Array<Record<string, unknown>>;
  const summary = api.summary as Record<string, unknown>;

  const refundEntries = ledger.filter((e) => e.kind === "refund");
  assertEquals(refundEntries.length, 1);
  assertEquals(refundEntries[0]!.debit, "3000");

  // 10000 (debit) - 10000 (credit) + 3000 (refund debit) = 3000 = outstanding.
  assertEquals(ledger[ledger.length - 1]!.balance, "3000");
  assertEquals(summary.balance, "3000");
});

// ── 3. getStudentLedger actually loads the processed refunds ──────────────────
class MockDb {
  account: Row = {
    id: ACCOUNT,
    student_id: STUDENT,
    student_name: "Probe",
    admission_number: "ADM-1",
    class_label: "5",
    academic_year: "2026-27",
    total_fee: "10000",
    amount_paid: "0",
    outstanding_amount: "10000",
    status: "open",
  };
  invoices: Row[] = [makeInvoice()];
  collections: Row[] = [makeCollection()];
  refunds: Row[] = [makeRefund()];

  // deno-lint-ignore require-await
  async queryObject<T>(sql: string, _args: unknown[] = []): Promise<T[]> {
    if (sql.includes("FROM finance_student_accounts fsa")) {
      return [this.account] as T[];
    }
    // Must precede the finance_collections branch: the refunds query LEFT JOINs
    // finance_collections for receipt context.
    if (sql.includes("FROM finance_refunds fr")) {
      return this.refunds as T[];
    }
    if (sql.includes("FROM finance_invoices")) {
      return this.invoices as T[];
    }
    if (sql.includes("FROM finance_collections")) {
      return this.collections as T[];
    }
    return [] as T[];
  }
}

function asDb(mock: MockDb): TenantQueryClient {
  return mock as unknown as TenantQueryClient;
}

Deno.test("PRA-P1-11 getStudentLedger loads processed refunds and the statement reconciles end-to-end", async () => {
  const db = asDb(new MockDb());
  const ledger = await getStudentLedger(db, ORG, SCHOOL, ACCOUNT);

  // The repository now populates the refunds it must debit.
  assertEquals(ledger !== null, true);
  const loaded = ledger as StudentLedger;
  assertEquals((loaded.refunds ?? []).length, 1);
  assertEquals(loaded.refunds![0]!.refund_amount, "10000");

  const api = studentLedgerToApi(loaded);
  const ledgerRows = api.ledger as Array<Record<string, unknown>>;
  const summary = api.summary as Record<string, unknown>;
  const hasRefundDebit = ledgerRows.some((e) => e.kind === "refund");

  assertEquals(hasRefundDebit, true);
  assertEquals(ledgerRows[ledgerRows.length - 1]!.balance, "10000");
  assertEquals(ledgerRows[ledgerRows.length - 1]!.balance, summary.balance);
});
