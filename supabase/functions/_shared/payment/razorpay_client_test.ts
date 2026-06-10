import { assert, assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import {
  createRazorpayOrder,
  verifyRazorpayPaymentSignature,
  verifyRazorpayWebhookSignature,
} from "./razorpay_client.ts";
import type { RazorpayConfig } from "./razorpay_config.ts";

const stubConfig: RazorpayConfig = {
  enabled: false,
  stubMode: true,
  keyId: null,
  keySecret: null,
  webhookSecret: null,
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

Deno.test("verifyRazorpayWebhookSignature accepts stub mode without signature", async () => {
  const valid = await verifyRazorpayWebhookSignature(stubConfig, "{}", null);
  assert(valid);
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
