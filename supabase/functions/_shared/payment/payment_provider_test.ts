// W3 Payment Provider Abstraction tests (Owner decision #7 · PRA-P0-02).
//
// Covers: registry lookup, school-choice resolution (default + configured +
// unknown + disabled → all fail-closed on error), the Razorpay path unchanged
// through the wrapper, the second (manual/offline) provider is fail-closed, and
// that signature verification still gates receipt persistence for a non-Razorpay
// provider routed through confirmPayment.

import {
  assert,
  assertEquals,
  assertRejects,
} from "https://deno.land/std@0.224.0/assert/mod.ts";
import type { AccessTokenClaims } from "../jwt.ts";
import type { TenantQueryClient } from "../tenant_db.ts";
import {
  PaymentProviderDisabledError,
  UnknownPaymentProviderError,
} from "./payment_provider.ts";
import {
  DEFAULT_PROVIDER_ID,
  getPaymentProvider,
  registeredProviderIds,
  resolvePaymentProvider,
  resolveSchoolProviderId,
} from "./payment_provider_registry.ts";
import { ManualProvider } from "./manual_provider.ts";
import { RazorpayProvider } from "./razorpay_provider.ts";
import {
  PaymentIntentStateError,
  type PaymentIntentRow,
} from "./payment_repository.ts";
import { confirmPayment } from "./payment_service.ts";

// ── env helper ────────────────────────────────────────────────────────────────
function withEnv(
  env: Record<string, string | undefined>,
  fn: () => Promise<void> | void,
): () => Promise<void> {
  const keys = ["RAZORPAY_KEY_ID", "RAZORPAY_KEY_SECRET", "RAZORPAY_STUB_MODE"];
  return async () => {
    const prev: Record<string, string | undefined> = {};
    for (const k of keys) prev[k] = Deno.env.get(k);
    try {
      for (const k of keys) {
        const v = env[k];
        if (v === undefined) Deno.env.delete(k);
        else Deno.env.set(k, v);
      }
      await fn();
    } finally {
      for (const k of keys) {
        const v = prev[k];
        if (v === undefined) Deno.env.delete(k);
        else Deno.env.set(k, v);
      }
    }
  };
}

/** A mock config store returning zero or one payment_provider_config row. */
class ProviderConfigDb {
  constructor(
    private readonly row: { provider: string; enabled: boolean } | null,
  ) {}
  // deno-lint-ignore require-await
  async queryObject<T>(sql: string, _args: unknown[] = []): Promise<T[]> {
    if (sql.includes("FROM payment_provider_config")) {
      return (this.row ? [this.row] : []) as T[];
    }
    return [] as T[];
  }
}

// ── registry ──────────────────────────────────────────────────────────────────

Deno.test("registry: getPaymentProvider('razorpay') returns the Razorpay provider", () => {
  const provider = getPaymentProvider("razorpay");
  assert(provider instanceof RazorpayProvider);
  assertEquals(provider.id, "razorpay");
});

Deno.test("registry: getPaymentProvider('manual') returns the manual provider", () => {
  const provider = getPaymentProvider("manual");
  assert(provider instanceof ManualProvider);
  assertEquals(provider.id, "manual");
});

Deno.test("registry: an unknown provider id fails closed (throws, never a no-op provider)", () => {
  let threw = false;
  try {
    getPaymentProvider("stripe");
  } catch (e) {
    threw = true;
    assert(e instanceof UnknownPaymentProviderError);
    assertEquals((e as UnknownPaymentProviderError).providerId, "stripe");
  }
  assert(threw, "getPaymentProvider must throw for an unknown provider");
});

Deno.test("registry: exposes exactly the two registered providers", () => {
  const ids = registeredProviderIds().sort();
  assertEquals(ids, ["manual", "razorpay"]);
  assertEquals(DEFAULT_PROVIDER_ID, "razorpay");
});

// ── school-choice resolution ────────────────────────────────────────────────

Deno.test("resolver: no config row → defaults to razorpay", async () => {
  const db = new ProviderConfigDb(null) as unknown as TenantQueryClient;
  assertEquals(await resolveSchoolProviderId(db, "org-1", "school-1"), "razorpay");
  const provider = await resolvePaymentProvider(db, "org-1", "school-1");
  assertEquals(provider.id, "razorpay");
});

Deno.test("resolver: a configured provider is honoured", async () => {
  const db = new ProviderConfigDb({ provider: "manual", enabled: true }) as unknown as TenantQueryClient;
  assertEquals(await resolveSchoolProviderId(db, "org-1", "school-1"), "manual");
  const provider = await resolvePaymentProvider(db, "org-1", "school-1");
  assert(provider instanceof ManualProvider);
  assertEquals(provider.id, "manual");
});

Deno.test("resolver: an UNCONFIGURED (unknown) provider fails closed", async () => {
  const db = new ProviderConfigDb({ provider: "payu", enabled: true }) as unknown as TenantQueryClient;
  await assertRejects(
    () => resolvePaymentProvider(db, "org-1", "school-1"),
    UnknownPaymentProviderError,
    "Unknown payment provider: payu",
  );
});

Deno.test("resolver: a DISABLED provider fails closed (no silent fallback to default)", async () => {
  const db = new ProviderConfigDb({ provider: "razorpay", enabled: false }) as unknown as TenantQueryClient;
  await assertRejects(
    () => resolvePaymentProvider(db, "org-1", "school-1"),
    PaymentProviderDisabledError,
  );
});

// ── Razorpay path unchanged through the wrapper ─────────────────────────────

Deno.test(
  "razorpay provider (stub): createOrder + verify behave exactly as the client",
  withEnv({ RAZORPAY_KEY_ID: undefined, RAZORPAY_KEY_SECRET: undefined, RAZORPAY_STUB_MODE: "true" }, async () => {
    const provider = getPaymentProvider("razorpay");
    const order = await provider.createOrder({ amount: 4200, receipt: "req_test" });
    assert(order.id.startsWith("order_stub_"));
    assertEquals(order.amount, 420000);
    assertEquals(order.currency, "INR");
    // stub gateway = no live money = no signature required for capture
    assertEquals(provider.requiresGatewaySignature(), false);
    assertEquals(provider.publicClientKey(), null);
    assert(await provider.verifyWebhookSignature("{}", null));
    assert(await provider.verifyPaymentSignature("order_abc", "pay_xyz", "stub_payment_signature"));
  }),
);

Deno.test(
  "razorpay provider (live): requires signature, exposes key id, rejects a forged signature",
  withEnv({ RAZORPAY_KEY_ID: "rzp_live_test", RAZORPAY_KEY_SECRET: "secret_test", RAZORPAY_STUB_MODE: "false" }, async () => {
    const provider = getPaymentProvider("razorpay");
    assertEquals(provider.requiresGatewaySignature(), true);
    assertEquals(provider.publicClientKey(), "rzp_live_test");
    // A forged signature is rejected (constant-time HMAC mismatch) — never a
    // throw-to-true, never a fabricated pass.
    assertEquals(
      await provider.verifyPaymentSignature("order_x", "pay_x", "deadbeef"),
      false,
    );
    assertEquals(await provider.verifyWebhookSignature("{}", "forged"), false);
  }),
);

// ── the second provider is fail-closed ──────────────────────────────────────

Deno.test("manual provider: issues a pending reference but NEVER self-verifies", async () => {
  const provider = new ManualProvider();
  const order = await provider.createOrder({ amount: 4200, receipt: "req_manual" });
  assertEquals(order.id, "manual_req_manual"); // a reference, not a receipt
  assertEquals(order.amount, 420000);
  assertEquals(provider.publicClientKey(), null);
  assertEquals(provider.requiresGatewaySignature(), true);
  // offline payment carries no verifiable signature — ALWAYS false, for any input
  assertEquals(await provider.verifyPaymentSignature("o", "p", "anything"), false);
  assertEquals(await provider.verifyPaymentSignature("o", "p", ""), false);
  assertEquals(await provider.verifyWebhookSignature("{}", "sig"), false);
  assertEquals(await provider.verifyWebhookSignature("{}", null), false);
});

// ── verification gates receipt persistence for the second provider ──────────

const MANUAL_INTENT: PaymentIntentRow = {
  id: "d0000000-0000-4000-8000-0000000000aa",
  organization_id: "a1000000-0000-4000-8000-000000000001",
  school_id: "a2000000-0000-4000-8000-000000000001",
  request_id: "req-m",
  payer_user_id: "a3000000-0000-4000-8000-000000000003",
  gateway: "manual", // opened by the manual provider
  gateway_order_id: "manual_req-m",
  gateway_payment_id: null,
  status: "initiated",
  amount: 4200,
  payment_method: "upi",
  invoice_id: "b9000000-0000-4000-8000-000000000001", // set: a wrong capture WOULD post a collection
  collection_id: null,
  receipt_id: null,
  refund_id: null,
  idempotency_key: null,
  transaction_ref: null,
  metadata: {},
  expires_at: null,
};

function manualParentClaims(): AccessTokenClaims {
  return {
    sub: MANUAL_INTENT.payer_user_id,
    tenant_id: MANUAL_INTENT.organization_id,
    organization_id: MANUAL_INTENT.organization_id,
    school_id: MANUAL_INTENT.school_id,
    role: "parent",
    role_slugs: ["parent"],
    primary_role: "parent",
    permissions: [],
    permissions_version: 1,
    scope: "parent",
    school_group_id: null,
    student_id: null,
    child_ids: ["a4000000-0000-4000-8000-000000000001"],
    session_id: "manual-confirm-test",
  };
}

class ManualConfirmSpyDb {
  collectionCreated = false;
  intentCaptured = false;
  // deno-lint-ignore require-await
  async queryObject<T>(sql: string, _args: unknown[] = []): Promise<T[]> {
    if (sql.includes("FROM payment_intents") && sql.includes("AND id = $2")) {
      return [MANUAL_INTENT] as T[];
    }
    if (sql.includes("INSERT INTO finance_collections")) {
      this.collectionCreated = true;
      return [] as T[];
    }
    if (sql.includes("UPDATE payment_intents") && sql.includes("captured")) {
      this.intentCaptured = true;
      return [{ ...MANUAL_INTENT, status: "captured" }] as T[];
    }
    return [] as T[];
  }
}

Deno.test("confirmPayment on a MANUAL intent fails closed when no signature is presented", async () => {
  const spy = new ManualConfirmSpyDb();
  const db = spy as unknown as TenantQueryClient;
  await assertRejects(
    () =>
      confirmPayment(db, manualParentClaims(), {
        paymentIntentId: MANUAL_INTENT.id,
        transactionRef: "TXN-OFFLINE",
        // parent's app cannot present a gateway signature for an offline payment
      }),
    PaymentIntentStateError,
  );
  assertEquals(spy.collectionCreated, false, "must NOT create a collection");
  assertEquals(spy.intentCaptured, false, "must NOT capture the intent");
});

Deno.test("confirmPayment on a MANUAL intent fails closed even with a FORGED signature", async () => {
  const spy = new ManualConfirmSpyDb();
  const db = spy as unknown as TenantQueryClient;
  await assertRejects(
    () =>
      confirmPayment(db, manualParentClaims(), {
        paymentIntentId: MANUAL_INTENT.id,
        transactionRef: "TXN-OFFLINE",
        razorpayPaymentId: "pay_forged",
        razorpaySignature: "forged_signature",
      }),
    PaymentIntentStateError,
    "Invalid Razorpay payment signature",
  );
  assertEquals(spy.collectionCreated, false, "must NOT create a collection");
  assertEquals(spy.intentCaptured, false, "must NOT capture the intent");
});

Deno.test("confirmPayment on an intent with an UNKNOWN persisted gateway fails closed", async () => {
  const spy = new (class {
    // deno-lint-ignore require-await
    async queryObject<T>(sql: string): Promise<T[]> {
      if (sql.includes("FROM payment_intents") && sql.includes("AND id = $2")) {
        return [{ ...MANUAL_INTENT, gateway: "ghostpay" }] as T[];
      }
      return [] as T[];
    }
  })();
  const db = spy as unknown as TenantQueryClient;
  await assertRejects(
    () =>
      confirmPayment(db, manualParentClaims(), {
        paymentIntentId: MANUAL_INTENT.id,
        transactionRef: "TXN-GHOST",
      }),
    UnknownPaymentProviderError,
    "ghostpay",
  );
});
