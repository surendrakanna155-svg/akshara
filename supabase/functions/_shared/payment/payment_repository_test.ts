import { assertEquals, assertRejects } from "https://deno.land/std@0.224.0/assert/mod.ts";
import type { TenantQueryClient } from "../tenant_db.ts";
import type { PaymentIntentRow } from "./payment_repository.ts";
import {
  findIntentByIdempotencyKey,
  markIntentCaptured,
  PaymentIntentNotFoundError,
  recordWebhookEvent,
} from "./payment_repository.ts";

class MockPaymentDb {
  intents: PaymentIntentRow[] = [];
  webhookIds = new Set<string>();

  async queryObject<T>(sql: string, args: unknown[] = []): Promise<T[]> {
    if (sql.includes("FROM payment_intents") && sql.includes("idempotency_key")) {
      const orgId = args[0] as string;
      const key = args[1] as string;
      const row = this.intents.find(
        (entry) => entry.organization_id === orgId && entry.idempotency_key === key,
      );
      return row ? [row] as T[] : [] as T[];
    }

    if (sql.includes("FROM payment_webhook_events")) {
      const eventId = args[0] as string;
      return this.webhookIds.has(eventId) ? [{ id: eventId }] as T[] : [] as T[];
    }

    if (sql.includes("INSERT INTO payment_webhook_events")) {
      this.webhookIds.add(args[0] as string);
      return [] as T[];
    }

    if (sql.includes("UPDATE payment_intents") && sql.includes("status = 'captured'")) {
      const intentId = args[0] as string;
      const intent = this.intents.find((i) => i.id === intentId);
      // Honor the terminal `AND status <> 'captured'` guard (RT round-3 S3): an
      // already-captured intent (the client-confirm vs webhook race loser) matches
      // 0 rows → markIntentCaptured throws → the enclosing txn rolls back the
      // collection it wrote first, so a partial online payment is never double-credited.
      if (!intent || intent.status === "captured") return [] as T[];
      intent.status = "captured";
      intent.transaction_ref = args[1] as string;
      return [intent] as T[];
    }
    if (sql.includes("UPDATE payment_requests") && sql.includes("status = 'captured'")) {
      return [] as T[];
    }

    return [] as T[];
  }
}

function seedIntent(mock: MockPaymentDb, status: string): void {
  mock.intents.push({
    id: "intent-x",
    organization_id: "org-1",
    school_id: "school-1",
    request_id: "req-x",
    payer_user_id: "parent-1",
    gateway: "razorpay",
    gateway_order_id: "order_x",
    gateway_payment_id: null,
    status,
    amount: 600,
    payment_method: "upi",
    invoice_id: "inv-1",
    collection_id: null,
    receipt_id: null,
    refund_id: null,
    idempotency_key: "idem-x",
    transaction_ref: null,
    metadata: {},
    expires_at: null,
  } as PaymentIntentRow);
}

Deno.test("RT round-3 S3: markIntentCaptured on an already-captured intent fails closed (race loser → no double capture)", async () => {
  const mock = new MockPaymentDb();
  seedIntent(mock, "captured"); // a concurrent path already captured it
  await assertRejects(
    () => markIntentCaptured(mock as unknown as TenantQueryClient, "intent-x", { transactionRef: "txn-2" }),
    PaymentIntentNotFoundError,
  );
});

Deno.test("RT round-3 S3: markIntentCaptured captures a fresh initiated intent (happy path preserved)", async () => {
  const mock = new MockPaymentDb();
  seedIntent(mock, "initiated");
  const row = await markIntentCaptured(mock as unknown as TenantQueryClient, "intent-x", { transactionRef: "txn-1" });
  assertEquals(row.status, "captured");
});

Deno.test("findIntentByIdempotencyKey returns existing intent", async () => {
  const mock = new MockPaymentDb();
  mock.intents.push({
    id: "intent-1",
    organization_id: "org-1",
    school_id: "school-1",
    request_id: "req-1",
    payer_user_id: "parent-1",
    gateway: "razorpay",
    gateway_order_id: "order_1",
    gateway_payment_id: null,
    status: "initiated",
    amount: 4200,
    payment_method: "upi",
    invoice_id: null,
    collection_id: null,
    receipt_id: null,
    refund_id: null,
    idempotency_key: "idem-1",
    transaction_ref: null,
    metadata: {},
    expires_at: null,
  });

  const found = await findIntentByIdempotencyKey(
    mock as unknown as TenantQueryClient,
    "org-1",
    "idem-1",
  );
  assertEquals(found?.id, "intent-1");
});

Deno.test("recordWebhookEvent deduplicates by event id", async () => {
  const mock = new MockPaymentDb();
  const db = mock as unknown as TenantQueryClient;
  const first = await recordWebhookEvent(db, "evt_1", "payment.captured", {}, "org-1");
  const second = await recordWebhookEvent(db, "evt_1", "payment.captured", {}, "org-1");
  assertEquals(first, true);
  assertEquals(second, false);
});
