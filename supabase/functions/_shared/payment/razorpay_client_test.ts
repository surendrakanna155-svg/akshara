import { assert, assertEquals, assertFalse } from "https://deno.land/std@0.224.0/assert/mod.ts";
import {
  createRazorpayOrder,
  verifyRazorpayPaymentSignature,
  verifyRazorpayWebhookSignature,
} from "./razorpay_client.ts";
import { hmacSha256Hex } from "../webhook_hmac.ts";
import type { RazorpayConfig } from "./razorpay_config.ts";

const stubConfig: RazorpayConfig = {
  enabled: false,
  stubMode: true,
  keyId: null,
  keySecret: null,
  webhookSecret: null,
};

const liveConfig: RazorpayConfig = {
  enabled: true,
  stubMode: false,
  keyId: "rzp_live_test",
  keySecret: "secret_test",
  webhookSecret: "whsec",
};

Deno.test("createRazorpayOrder returns stub order in stub mode", async () => {
  const order = await createRazorpayOrder(stubConfig, {
    amount: 4200,
    receipt: "req_test",
    notes: { installment_id: "term_2" },
  });
  assert(order.id.startsWith("order_stub_"));
  assertEquals(order.amount, 420000);
  assertEquals(order.currency, "INR");
});

// ICA-A5: an absent signature is unauthenticated and is NEVER valid — not even
// in stub mode. This assertion previously expected `true`, which let any public
// caller forge a payment.captured webhook that posted a real, zero-payment
// receipt. The RAZORPAY_ALLOW_UNSIGNED handler flag is the only dev escape hatch.
Deno.test("verifyRazorpayWebhookSignature rejects a null signature in stub mode", async () => {
  const valid = await verifyRazorpayWebhookSignature(stubConfig, "{}", null);
  assertFalse(valid);
});

Deno.test("verifyRazorpayWebhookSignature rejects an empty-string signature in stub mode", async () => {
  const valid = await verifyRazorpayWebhookSignature(stubConfig, "{}", "");
  assertFalse(valid);
});

Deno.test("verifyRazorpayWebhookSignature still accepts the explicit stub_signature token in stub mode", async () => {
  // Keeps the deterministic dev order/confirm loop working without a live gateway.
  const valid = await verifyRazorpayWebhookSignature(stubConfig, "{}", "stub_signature");
  assert(valid);
});

Deno.test("verifyRazorpayWebhookSignature rejects an arbitrary non-stub token in stub mode", async () => {
  const valid = await verifyRazorpayWebhookSignature(stubConfig, "{}", "forged");
  assertFalse(valid);
});

Deno.test("verifyRazorpayWebhookSignature accepts a correctly-signed live webhook (no Razorpay account needed)", async () => {
  const body = '{"event":"payment.captured","payload":{"payment":{"id":"pay_x"}}}';
  const expected = await hmacSha256Hex("whsec", body);
  const valid = await verifyRazorpayWebhookSignature(liveConfig, body, expected);
  assert(valid);
});

Deno.test("verifyRazorpayWebhookSignature rejects a garbage signature on a live webhook", async () => {
  const body = '{"event":"payment.captured","payload":{"payment":{"id":"pay_x"}}}';
  const valid = await verifyRazorpayWebhookSignature(liveConfig, body, "deadbeef");
  assertFalse(valid);
});

Deno.test("verifyRazorpayWebhookSignature rejects a null signature in live mode", async () => {
  const valid = await verifyRazorpayWebhookSignature(liveConfig, "{}", null);
  assertFalse(valid);
});

Deno.test("verifyRazorpayPaymentSignature accepts stub signature", async () => {
  const valid = await verifyRazorpayPaymentSignature(
    stubConfig,
    "order_abc",
    "pay_xyz",
    "stub_payment_signature",
  );
  assert(valid);
});
