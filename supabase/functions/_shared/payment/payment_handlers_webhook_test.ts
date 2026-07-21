// ICA-A5 (P0, Finance/Security) — the public /webhooks/razorpay route must NOT
// post a fraudulent, zero-payment receipt from a forged/unsigned webhook while
// the gateway is in stub mode (the pilot's current, credential-less state).
//
// These tests exercise handleRazorpayWebhook end-to-end at the guard boundary,
// fully hermetic: the two 403 fail-closed guards short-circuit BEFORE any DB /
// service client is created, and the "allowed past the guard" case throws at the
// tenant-DB seam (ERP_TENANT_DATABASE_URL unset) — so no network or DB is
// touched. Verifies both halves of the fix:
//   1. razorpay_client: an absent signature is never valid in any mode.
//   2. payment_handlers: money-affecting webhooks are refused in stub mode.

import {
  assert,
  assertEquals,
} from "https://deno.land/std@0.224.0/assert/mod.ts";
import type { AppConfig } from "../config.ts";
import { handleRazorpayWebhook } from "./payment_handlers.ts";

// Swaps the Razorpay env vars around a single test and restores them after,
// copying the technique used by payment_service_test.ts's withRazorpayEnv (kept
// local so this file stays self-contained and does not import that test module).
function withEnv(
  env: Record<string, string | undefined>,
  fn: () => Promise<void>,
): () => Promise<void> {
  const keys = [
    "RAZORPAY_KEY_ID",
    "RAZORPAY_KEY_SECRET",
    "RAZORPAY_WEBHOOK_SECRET",
    "RAZORPAY_STUB_MODE",
    "RAZORPAY_ALLOW_UNSIGNED",
  ];
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

// A minimal AppConfig. Only the fields the webhook handler touches AFTER the
// guards matter (supabase* for createServiceClient, erpTenantDatabaseUrl left
// null so withTenantContext fails closed instead of opening a real connection).
function fakeConfig(): AppConfig {
  return {
    supabaseUrl: "http://localhost:54321",
    supabaseServiceRoleKey: "test-service-role-key",
    erpTenantDatabaseUrl: null,
  } as unknown as AppConfig;
}

// The pilot's stub environment: no live credentials, unsigned webhooks NOT
// explicitly allowed. This is exactly how the deployed pilot runs today.
const PILOT_STUB_ENV: Record<string, string | undefined> = {
  RAZORPAY_KEY_ID: undefined,
  RAZORPAY_KEY_SECRET: undefined,
  RAZORPAY_WEBHOOK_SECRET: undefined,
  RAZORPAY_STUB_MODE: "true",
  RAZORPAY_ALLOW_UNSIGNED: undefined,
};

const CAPTURE_PAYLOAD = JSON.stringify({
  event: "payment.captured",
  payload: { payment: { id: "pay_forged_1" } },
});

function webhookRequest(signature: string | null): Request {
  const headers: Record<string, string> = { "Content-Type": "application/json" };
  if (signature !== null) headers["X-Razorpay-Signature"] = signature;
  return new Request("https://x.local/functions/v1/api/webhooks/razorpay", {
    method: "POST",
    headers,
    body: CAPTURE_PAYLOAD,
  });
}

Deno.test(
  "handleRazorpayWebhook rejects an unsigned payment.captured in stub mode (ICA-A5 forgery)",
  withEnv(PILOT_STUB_ENV, async () => {
    // No X-Razorpay-Signature → verifyWebhookSignature returns false (an absent
    // signature is never valid), RAZORPAY_ALLOW_UNSIGNED is unset → the RT-23
    // guard fail-closes with 403 BEFORE any service/DB client is created. Before
    // the fix, a null signature verified as `true` in stub mode and the handler
    // went on to write a real finance_collection + receipt for zero payment.
    const res = await handleRazorpayWebhook(webhookRequest(null), fakeConfig());
    assertEquals(res.status, 403);
    const body = await res.json();
    assertEquals(body.error.code, "FORBIDDEN");
    assertEquals(body.error.message, "Invalid Razorpay webhook signature");
  }),
);

Deno.test(
  "handleRazorpayWebhook refuses money-affecting webhook in stub mode even with the stub token (ICA-A5 change 2)",
  withEnv(PILOT_STUB_ENV, async () => {
    // Header carries the literal "stub_signature" token, so signature
    // verification passes (valid=true) and the RT-23 guard does NOT fire. The
    // new stub-mode capture guard must still refuse it: a stub-mode provider
    // cannot carry a real cryptographic signature and MUST NOT post to the books.
    const res = await handleRazorpayWebhook(
      webhookRequest("stub_signature"),
      fakeConfig(),
    );
    assertEquals(res.status, 403);
    const body = await res.json();
    assertEquals(body.error.code, "FORBIDDEN");
    assertEquals(
      body.error.message,
      "Webhook capture is disabled while the payment gateway is in stub mode",
    );
  }),
);

Deno.test(
  "handleRazorpayWebhook lets an unsigned webhook past the guards when RAZORPAY_ALLOW_UNSIGNED=true (dev escape hatch)",
  withEnv(
    { ...PILOT_STUB_ENV, RAZORPAY_ALLOW_UNSIGNED: "true" },
    async () => {
      // With the explicit dev opt-in, BOTH 403 guards are bypassed and the
      // handler proceeds into processing. It then fails closed at the tenant-DB
      // seam (ERP_TENANT_DATABASE_URL unset → TenantDbNotConfiguredError, no
      // real connection) which surfaces as a 5xx. Any non-403 5xx here proves
      // the request was accepted PAST both fail-closed 403 guards.
      const res = await handleRazorpayWebhook(webhookRequest(null), fakeConfig());
      await res.body?.cancel();
      assert(
        res.status >= 500,
        `expected a 5xx from the DB layer past the guards, got ${res.status}`,
      );
      assert(res.status !== 403, "must not be a fail-closed 403 guard rejection");
    },
  ),
);
