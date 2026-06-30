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

import { assertEquals, assertRejects } from "https://deno.land/std@0.224.0/assert/mod.ts";
import type { TenantQueryClient } from "../tenant_db.ts";
import {
  createOfflinePayment,
  type FinanceOfflinePaymentRow,
  OfflinePaymentNotFoundError,
  reconcileOfflinePayment,
} from "./finance_offline_payments_repository.ts";

const ORG = "c1000000-0000-4000-8000-000000000001";
const SCHOOL = "c2000000-0000-4000-8000-000000000001";
const STAFF = "c3000000-0000-4000-8000-000000000001";

/** In-memory store + SQL pattern matcher for the offline-payments repository. */
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
        recorded_at: (args[7] as string | null) ?? "2026-06-30T00:00:00.000Z",
        status: "pending_reconciliation",
        collection_id: null,
        reconciled_at: null,
        reconciled_by: null,
        notes: null,
        recorded_by: (args[8] as string | null) ?? null,
        created_at: "2026-06-30T00:00:00.000Z",
        updated_at: "2026-06-30T00:00:00.000Z",
      };
      this.payments.push(row);
      return [structuredClone(row) as T];
    }

    // getOfflinePayment (org+school scoped).
    if (s.startsWith("SELECT * FROM finance_offline_payments WHERE id = $1")) {
      const row = this.payments.find((p) =>
        p.id === args[0] && p.organization_id === args[1] && p.school_id === args[2]
      );
      return row ? [structuredClone(row) as T] : [];
    }

    // reconcileOfflinePayment UPDATE — single-row, scoped, sets status reconciled.
    if (s.startsWith("UPDATE finance_offline_payments SET status = 'reconciled'")) {
      const row = this.payments.find((p) =>
        p.id === args[0] && p.organization_id === args[1] && p.school_id === args[2]
      );
      if (!row) return [] as T[];
      row.status = "reconciled";
      row.reconciled_at = (args[3] as string | null) ?? "2026-06-30T12:00:00.000Z";
      row.reconciled_by = (args[4] as string | null) ?? null;
      if (args[5] != null) row.notes = String(args[5]);
      row.updated_at = "2026-06-30T12:00:00.000Z";
      return [structuredClone(row) as T];
    }

    throw new Error(`Unhandled SQL in MockOfflinePaymentsDb: ${s.slice(0, 80)}`);
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
});
