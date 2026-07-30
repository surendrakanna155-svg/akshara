// FIN-R7 — payment-instrument (cheque / DD / PDC) + bounce tracking.
//
// The finance_offline_payments ledger is tracking-only: it never posts to
// finance_collections. These tests pin the money-safety + lifecycle contract:
//   * a bounce flips pending → bounced and posts NO money (collection_id stays
//     null) — a dishonoured instrument reverses nothing;
//   * bounce is terminal + match-once (idempotent, no second row);
//   * a reconciled (cleared) instrument cannot be bounced (409);
//   * a bounced (dishonoured) instrument cannot be reconciled (409);
//   * PDC is an accepted method and instrument_date / bank_name are stored.
//
// Uses the same DB-free mock seam as qa_x_022 — a class implementing
// queryObject<T> that pattern-matches the SQL. No live Postgres.

import { assertEquals, assertRejects } from "https://deno.land/std@0.224.0/assert/mod.ts";
import type { TenantQueryClient } from "../tenant_db.ts";
import {
  bounceOfflinePayment,
  createOfflinePayment,
  type FinanceOfflinePaymentRow,
  isOfflinePaymentMethod,
  OfflinePaymentBouncedError,
  OfflinePaymentNotFoundError,
  OfflinePaymentReconciledError,
  reconcileOfflinePayment,
} from "./finance_offline_payments_repository.ts";

const ORG = "c1000000-0000-4000-8000-000000000001";
const SCHOOL = "c2000000-0000-4000-8000-000000000001";
const STAFF = "c3000000-0000-4000-8000-000000000001";

/** In-memory store + SQL pattern matcher honouring status transitions. */
class MockOfflinePaymentsDb {
  payments: FinanceOfflinePaymentRow[] = [];
  private seq = 0;

  async queryObject<T>(sql: string, args: unknown[] = []): Promise<T[]> {
    const s = sql.replace(/\s+/g, " ").trim();

    if (s.startsWith("INSERT INTO finance_offline_payments")) {
      this.seq++;
      const row: FinanceOfflinePaymentRow = {
        id: `pay-${this.seq.toString().padStart(4, "0")}`,
        organization_id: String(args[0]),
        school_id: String(args[1]),
        invoice_id: (args[2] as string | null) ?? null,
        student_name: String(args[3]),
        amount: String(args[4]),
        payment_method: args[5] as FinanceOfflinePaymentRow["payment_method"],
        reference_number: String(args[6]),
        instrument_date: (args[7] as string | null) ?? null,
        bank_name: (args[8] as string | null) ?? null,
        recorded_at: (args[9] as string | null) ?? "2026-06-30T00:00:00.000Z",
        status: "pending_reconciliation",
        collection_id: null,
        reconciled_at: null,
        reconciled_by: null,
        bounced_at: null,
        bounced_reason: null,
        bounced_by: null,
        notes: null,
        recorded_by: (args[10] as string | null) ?? null,
        created_at: "2026-06-30T00:00:00.000Z",
        updated_at: "2026-06-30T00:00:00.000Z",
      };
      this.payments.push(row);
      return [structuredClone(row) as T];
    }

    if (s.startsWith("SELECT * FROM finance_offline_payments WHERE id = $1")) {
      const row = this.find(args);
      return row ? [structuredClone(row) as T] : [];
    }

    if (s.startsWith("UPDATE finance_offline_payments SET status = 'reconciled'")) {
      const row = this.find(args);
      // Mirror the WHERE guard: a bounced row is not updated.
      if (!row || row.status === "bounced") return [] as T[];
      row.status = "reconciled";
      row.reconciled_at = (args[3] as string | null) ?? "2026-06-30T12:00:00.000Z";
      row.reconciled_by = (args[4] as string | null) ?? null;
      if (args[5] != null) row.notes = String(args[5]);
      if (args[6] != null) row.collection_id = String(args[6]); // PRA-P1-09
      return [structuredClone(row) as T];
    }

    if (s.startsWith("UPDATE finance_offline_payments SET status = 'bounced'")) {
      const row = this.find(args);
      // Mirror the WHERE guard: only pending/bounced rows are updated.
      if (!row || row.status === "reconciled") return [] as T[];
      row.status = "bounced";
      row.bounced_at = (args[3] as string | null) ?? "2026-06-30T12:00:00.000Z";
      row.bounced_by = (args[4] as string | null) ?? null;
      if (args[5] != null) row.bounced_reason = String(args[5]);
      return [structuredClone(row) as T];
    }

    // PRA-P1-09 (S1): reconcile now posts a collection via createCollection.
    if (s.includes("FROM finance_invoices fi") && s.includes("JOIN finance_student_accounts")) {
      return [{
        id: String(args[0]),
        organization_id: ORG,
        school_id: SCHOOL,
        student_id: "stu-1",
        student_account_id: "acct-1",
        fee_assignment_id: "fa-1",
        total_amount: "100000",
        outstanding_amount: "100000",
        invoice_status: "issued",
      } as T];
    }
    if (s.startsWith("INSERT INTO finance_collections")) {
      return [{
        id: "coll-1",
        organization_id: ORG,
        school_id: SCHOOL,
        receipt_number: String(args[5]),
        amount_collected: String(args[9]),
        collection_status: "completed",
      } as T];
    }
    if (s.startsWith("INSERT INTO finance_receipts")) {
      return [{ id: "rcpt-1", receipt_number: String(args[3]) } as T];
    }
    // Unhandled reads/writes from the createCollection post-path are inert here.
    return [] as T[];
  }

  private find(args: unknown[]): FinanceOfflinePaymentRow | undefined {
    return this.payments.find((p) =>
      p.id === args[0] && p.organization_id === args[1] && p.school_id === args[2]
    );
  }

  get client(): TenantQueryClient {
    return this as unknown as TenantQueryClient;
  }
}

function seedPdc(db: MockOfflinePaymentsDb) {
  return createOfflinePayment(db.client, ORG, SCHOOL, {
    studentName: "Ravi Kumar",
    amount: 5000,
    method: "pdc",
    referenceNumber: "CHQ-99881",
    instrumentDate: "2026-08-15",
    bankName: "State Bank",
    recordedBy: STAFF,
    // PRA-P1-09 (S1): reconciliation posts a collection against this invoice.
    invoiceId: "inv-1",
  });
}

Deno.test("FIN-R7 PDC is a valid method and instrument metadata is stored", async () => {
  assertEquals(isOfflinePaymentMethod("pdc"), true);
  const db = new MockOfflinePaymentsDb();
  const created = await seedPdc(db);
  assertEquals(created.payment_method, "pdc");
  assertEquals(created.instrument_date, "2026-08-15");
  assertEquals(created.bank_name, "State Bank");
  assertEquals(created.status, "pending_reconciliation");
});

Deno.test("FIN-R7 bounce flips pending → bounced and posts NO money (money-safe)", async () => {
  const db = new MockOfflinePaymentsDb();
  const created = await seedPdc(db);

  const bounced = await bounceOfflinePayment(db.client, ORG, SCHOOL, created.id, {
    bouncedBy: STAFF,
    reason: "Insufficient funds",
  });

  assertEquals(bounced.status, "bounced");
  assertEquals(bounced.bounced_reason, "Insufficient funds");
  assertEquals(bounced.bounced_by, STAFF);
  // Tracking-only: no collection is ever spawned — a bounce reverses nothing.
  assertEquals(bounced.collection_id, null);
  // The recorded amount is unchanged — the ledger row is a record, not money.
  assertEquals(bounced.amount, created.amount);
  assertEquals(db.payments.length, 1);
});

Deno.test("FIN-R7 bounce is terminal + idempotent (match-once, no second row)", async () => {
  const db = new MockOfflinePaymentsDb();
  const created = await seedPdc(db);

  const first = await bounceOfflinePayment(db.client, ORG, SCHOOL, created.id, {
    bouncedBy: STAFF,
    reason: "Cheque returned",
  });
  const second = await bounceOfflinePayment(db.client, ORG, SCHOOL, created.id, {
    bouncedBy: STAFF,
  });

  assertEquals(first.id, second.id);
  assertEquals(second.status, "bounced");
  assertEquals(db.payments.length, 1);
});

Deno.test("FIN-R7 a reconciled (cleared) instrument cannot be bounced", async () => {
  const db = new MockOfflinePaymentsDb();
  const created = await seedPdc(db);
  await reconcileOfflinePayment(db.client, ORG, SCHOOL, created.id, { reconciledBy: STAFF });

  await assertRejects(
    () => bounceOfflinePayment(db.client, ORG, SCHOOL, created.id, { bouncedBy: STAFF }),
    OfflinePaymentReconciledError,
  );
  assertEquals(db.payments[0]!.status, "reconciled");
});

Deno.test("FIN-R7 a bounced (dishonoured) instrument cannot be reconciled", async () => {
  const db = new MockOfflinePaymentsDb();
  const created = await seedPdc(db);
  await bounceOfflinePayment(db.client, ORG, SCHOOL, created.id, { bouncedBy: STAFF });

  await assertRejects(
    () => reconcileOfflinePayment(db.client, ORG, SCHOOL, created.id, { reconciledBy: STAFF }),
    OfflinePaymentBouncedError,
  );
  assertEquals(db.payments[0]!.status, "bounced");
});

Deno.test("FIN-R7 bouncing an unknown instrument is rejected (no phantom row)", async () => {
  const db = new MockOfflinePaymentsDb();
  await assertRejects(
    () => bounceOfflinePayment(db.client, ORG, SCHOOL, "pay-does-not-exist", { bouncedBy: STAFF }),
    OfflinePaymentNotFoundError,
  );
  assertEquals(db.payments.length, 0);
});
