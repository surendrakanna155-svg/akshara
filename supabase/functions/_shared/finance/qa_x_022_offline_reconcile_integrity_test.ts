// QA-X-022 — finance reconciliation integrity (match-once / no double credit).
//
// RE-SCOPE NOTE: A batch/file reconciliation flow does NOT exist
// (owner-deferred); this re-scopes QA-X-022 to the existing single-payment
// reconcile (`reconcileOfflinePayment` in `finance_offline_payments_repository.ts`,
// surfaced via POST /finance/payments/offline/{id}/reconcile) plus its
// idempotency. The broad "bulk/statement reconciliation" variant is DEFERRED
// and intentionally not tested.
//
// There is no pre-existing offline-payments handler/repository test, so this is
// the contract test for the reconcile path. It uses the same DB-free mock seam
// the other finance repository tests use (a class implementing queryObject<T>
// that pattern-matches the SQL, cast to TenantQueryClient). No live Postgres.
//
// Property under test — reconcile is MATCH-ONCE:
//   * reconciling a payment flips it to 'reconciled' exactly once;
//   * the reconciled amount equals the recorded payment amount (totals balance);
//   * reconciling the SAME payment twice does not credit twice — it stays a
//     single 'reconciled' row with the same amount (idempotent no-op), it does
//     not spawn a second payment / second ledger row.
//
// ICA-A2 (P0) HARDENING: the double-credit RACE is now covered structurally. The
// mock (1) COUNTS every `INSERT INTO finance_collections` so a second collection
// can no longer hide, and (2) HONORS the tightened terminal guard
// `AND status = 'pending_reconciliation'` (returns 0 rows once flipped), so the
// repo's throw-on-0-rows path is exercised. A JS mock cannot prove real row-lock
// serialization of two truly-concurrent reconciles — that is the live cert's job
// (`scripts/qa/live_cert_offline_reconcile_double_credit.sh`).

import { assertEquals, assertRejects } from "https://deno.land/std@0.224.0/assert/mod.ts";
import type { TenantQueryClient } from "../tenant_db.ts";
import {
  createOfflinePayment,
  type FinanceOfflinePaymentRow,
  OfflinePaymentNotFoundError,
  OfflinePaymentStateError,
  reconcileOfflinePayment,
} from "./finance_offline_payments_repository.ts";

const ORG = "c1000000-0000-4000-8000-000000000001";
const SCHOOL = "c2000000-0000-4000-8000-000000000001";
const STAFF = "c3000000-0000-4000-8000-000000000001";

interface MockCollectionInsert {
  id: string;
  amount_collected: string;
  idempotency_key: string | null;
  offline_payment_id: string | null;
}

/** In-memory store + SQL pattern matcher for the offline-payments repository. */
class MockOfflinePaymentsDb {
  payments: FinanceOfflinePaymentRow[] = [];
  // ICA-A2: every collection posted through the reconcile path lands here, so a
  // test can assert EXACTLY ONE collection was ever created for an instrument.
  collectionInserts: MockCollectionInsert[] = [];
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

    // getOfflinePayment (org+school scoped). ICA-A2: the reconcile path now appends
    // `FOR UPDATE`; the normalized SQL still starts with this prefix, so the same
    // matcher serves both the locked (reconcile) and unlocked (bounce) reads.
    if (s.startsWith("SELECT * FROM finance_offline_payments WHERE id = $1")) {
      const row = this.payments.find((p) =>
        p.id === args[0] && p.organization_id === args[1] && p.school_id === args[2]
      );
      return row ? [structuredClone(row) as T] : [];
    }

    // reconcileOfflinePayment terminal UPDATE — single-row, scoped, sets status
    // reconciled and (PRA-P1-09) links the posted collection_id ($7). ICA-A2: it
    // now carries the atomic guard `AND status = 'pending_reconciliation'`.
    if (s.startsWith("UPDATE finance_offline_payments SET status = 'reconciled'")) {
      const row = this.payments.find((p) =>
        p.id === args[0] && p.organization_id === args[1] && p.school_id === args[2]
      );
      if (!row) return [] as T[];
      // ICA-A2: HONOR the tightened guard — a row that already left
      // 'pending_reconciliation' matches 0 rows, driving the repo's
      // throw-on-0-rows (OfflinePaymentStateError) fail-closed path.
      if (row.status !== "pending_reconciliation") return [] as T[];
      row.status = "reconciled";
      row.reconciled_at = (args[3] as string | null) ?? "2026-06-30T12:00:00.000Z";
      row.reconciled_by = (args[4] as string | null) ?? null;
      if (args[5] != null) row.notes = String(args[5]);
      if (args[6] != null) row.collection_id = String(args[6]);
      row.updated_at = "2026-06-30T12:00:00.000Z";
      return [structuredClone(row) as T];
    }

    // PRA-P1-09 (S1): reconcile now posts a collection via createCollection.
    // Model just enough of that path: the invoice+account load and the
    // collection/receipt inserts. Everything else (day-lock, settings, invoice/
    // account updates, head allocations, idempotency lookups) safely defaults to
    // [] below.
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
      this.seq++;
      // Column order (ICA-A2): …, collected_by ($12), idempotency_key ($13),
      // offline_payment_id ($14) → args indices 11, 12, 13.
      const coll: MockCollectionInsert = {
        id: `coll-${this.seq}`,
        amount_collected: String(args[9]),
        idempotency_key: (args[12] as string | null) ?? null,
        offline_payment_id: (args[13] as string | null) ?? null,
      };
      this.collectionInserts.push(coll);
      return [{
        id: coll.id,
        organization_id: ORG,
        school_id: SCHOOL,
        receipt_number: String(args[5]),
        amount_collected: coll.amount_collected,
        collection_status: "completed",
        offline_payment_id: coll.offline_payment_id,
        idempotency_key: coll.idempotency_key,
      } as T];
    }
    if (s.startsWith("INSERT INTO finance_receipts")) {
      return [{ id: `rcpt-${this.seq}`, receipt_number: String(args[3]) } as T];
    }

    // Unhandled reads/writes from the createCollection post-path (idempotency /
    // offline-payment lookups, invoice/account updates, head allocations) are
    // inert here — no existing collection is found, so the first insert proceeds.
    return [] as T[];
  }

  get client(): TenantQueryClient {
    return this as unknown as TenantQueryClient;
  }
}

async function seedPayment(
  db: MockOfflinePaymentsDb,
  amount: number,
): Promise<FinanceOfflinePaymentRow> {
  return await createOfflinePayment(db.client, ORG, SCHOOL, {
    studentName: "Ravi Kumar",
    amount,
    method: "cash",
    referenceNumber: "RCPT-OFF-1",
    recordedBy: STAFF,
    // PRA-P1-09 (S1): reconciliation posts a collection against this invoice.
    invoiceId: "inv-1",
  });
}

Deno.test("QA-X-022 reconcile flips status once and amount matches the recorded payment", async () => {
  const db = new MockOfflinePaymentsDb();
  const created = await seedPayment(db, 5000);
  assertEquals(created.status, "pending_reconciliation");

  const reconciled = await reconcileOfflinePayment(db.client, ORG, SCHOOL, created.id, {
    reconciledBy: STAFF,
    notes: "Matched to bank deposit",
  });

  assertEquals(reconciled.status, "reconciled");
  // Reconciled amount equals the recorded amount — totals balance, no skew.
  assertEquals(reconciled.amount, created.amount);
  assertEquals(reconciled.reconciled_by, STAFF);
  // Exactly one payment row exists — reconcile did not spawn a ledger duplicate.
  assertEquals(db.payments.length, 1);
  // Exactly one collection was posted for the instrument.
  assertEquals(db.collectionInserts.length, 1);
});

Deno.test("QA-X-022 reconciling the same payment twice is match-once (no double credit)", async () => {
  const db = new MockOfflinePaymentsDb();
  const created = await seedPayment(db, 7500);

  const first = await reconcileOfflinePayment(db.client, ORG, SCHOOL, created.id, {
    reconciledBy: STAFF,
  });
  const second = await reconcileOfflinePayment(db.client, ORG, SCHOOL, created.id, {
    reconciledBy: STAFF,
  });

  // Same single row reconciled both times — no second payment / second credit.
  assertEquals(db.payments.length, 1);
  assertEquals(first.id, second.id);
  assertEquals(second.status, "reconciled");
  // Amount is unchanged across both reconciles — the value is credited once.
  assertEquals(first.amount, created.amount);
  assertEquals(second.amount, created.amount);
  // The store still holds exactly one reconciled row for this payment.
  const reconciledRows = db.payments.filter((p) =>
    p.id === created.id && p.status === "reconciled"
  );
  assertEquals(reconciledRows.length, 1);
  assertEquals(reconciledRows[0]!.amount, created.amount);
});

Deno.test("ICA-A2: a second reconcile no-ops before posting — EXACTLY ONE collection", async () => {
  const db = new MockOfflinePaymentsDb();
  const created = await seedPayment(db, 5000);

  // First reconcile: reads 'pending_reconciliation', posts its collection, flips
  // the instrument to 'reconciled' and links the collection id.
  const first = await reconcileOfflinePayment(db.client, ORG, SCHOOL, created.id, {
    reconciledBy: STAFF,
  });
  assertEquals(first.status, "reconciled");
  assertEquals(db.collectionInserts.length, 1);
  const collId = first.collection_id;

  // Second reconcile: reads 'reconciled' (in production under the FOR UPDATE row
  // lock the loser blocks until the winner commits, then reads this state) and
  // returns the idempotent no-op BEFORE calling createCollection.
  const second = await reconcileOfflinePayment(db.client, ORG, SCHOOL, created.id, {
    reconciledBy: STAFF,
  });
  assertEquals(second.status, "reconciled");
  assertEquals(first.id, second.id);
  assertEquals(second.collection_id, collId);

  // THE INVARIANT: exactly ONE collection was ever posted for this instrument —
  // the mock now counts inserts, so a double credit could not slip through.
  assertEquals(db.collectionInserts.length, 1);
  assertEquals(db.payments.length, 1);
  // The one collection is stamped with the instrument id + derived idempotency
  // key (the DB-level backstops against the race).
  assertEquals(db.collectionInserts[0]!.offline_payment_id, created.id);
  assertEquals(db.collectionInserts[0]!.idempotency_key, `offline-reconcile:${created.id}`);
});

Deno.test("ICA-A2: terminal reconcile UPDATE matching 0 rows fails closed (rolls back, no double credit)", async () => {
  const base = new MockOfflinePaymentsDb();
  const created = await seedPayment(base, 5000);

  // Simulate the invariant violation the FOR UPDATE lock exists to prevent: the
  // locked read still sees 'pending_reconciliation', createCollection posts, but
  // the guarded terminal UPDATE (`AND status = 'pending_reconciliation'`) matches
  // 0 rows because a concurrent writer flipped the status. The repo MUST throw
  // OfflinePaymentStateError so the enclosing transaction rolls back the just-
  // posted collection — an instrument is never double-credited.
  const raced = {
    async queryObject<T>(sql: string, args: unknown[] = []): Promise<T[]> {
      const s = sql.replace(/\s+/g, " ").trim();
      if (s.startsWith("UPDATE finance_offline_payments SET status = 'reconciled'")) {
        return [] as T[]; // guard matched nothing (a concurrent reconcile won)
      }
      return base.queryObject<T>(sql, args);
    },
  } as unknown as TenantQueryClient;

  await assertRejects(
    () =>
      reconcileOfflinePayment(raced, ORG, SCHOOL, created.id, {
        reconciledBy: STAFF,
      }),
    OfflinePaymentStateError,
  );
});

Deno.test("QA-X-022 reconciling an unknown payment is rejected (no phantom credit)", async () => {
  const db = new MockOfflinePaymentsDb();
  await assertRejects(
    () =>
      reconcileOfflinePayment(db.client, ORG, SCHOOL, "pay-does-not-exist", {
        reconciledBy: STAFF,
      }),
    OfflinePaymentNotFoundError,
  );
  assertEquals(db.payments.length, 0);
  assertEquals(db.collectionInserts.length, 0);
});
