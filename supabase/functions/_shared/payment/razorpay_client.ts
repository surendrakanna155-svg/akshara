import type { RazorpayConfig } from "./razorpay_config.ts";

export interface RazorpayOrder {
  id: string;
  amount: number;
  currency: string;
  receipt?: string;
}

export interface CreateOrderInput {
  amount: number;
  currency?: string;
  receipt: string;
  notes?: Record<string, string>;
}

export class RazorpayNotConfiguredError extends Error {
  constructor() {
    super("Razorpay credentials not configured");
    this.name = "RazorpayNotConfiguredError";
  }
}

function stubOrderId(): string {
  return `order_stub_${crypto.randomUUID().replace(/-/g, "").slice(0, 14)}`;
}

export async function createRazorpayOrder(
  config: RazorpayConfig,
  input: CreateOrderInput,
): Promise<RazorpayOrder> {
  const currency = input.currency ?? "INR";
  const amountPaise = input.amount * 100;

  if (config.stubMode || !config.enabled) {
    return {
      id: stubOrderId(),
      amount: amountPaise,
      currency,
      receipt: input.receipt,
    };
  }

  if (!config.keyId || !config.keySecret) {
    throw new RazorpayNotConfiguredError();
  }

  const auth = btoa(`${config.keyId}:${config.keySecret}`);
  const response = await fetch("https://api.razorpay.com/v1/orders", {
    method: "POST",
    headers: {
      Authorization: `Basic ${auth}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      amount: amountPaise,
      currency,
      receipt: input.receipt,
      notes: input.notes ?? {},
    }),
  });

  if (!response.ok) {
    const body = await response.text();
    throw new Error(`Razorpay order creation failed: ${response.status} ${body}`);
  }

  const data = await response.json() as {
    id: string;
    amount: number;
    currency: string;
    receipt?: string;
  };
  return {
    id: data.id,
    amount: data.amount,
    currency: data.currency,
    receipt: data.receipt,
  };
}

export async function verifyRazorpayWebhookSignature(
  config: RazorpayConfig,
  body: string,
  signature: string | null,
): Promise<boolean> {
  if (config.stubMode) {
    return signature === "stub_signature" || signature === null;
  }
  if (!config.webhookSecret || !signature) {
    return false;
  }
  const key = await crypto.subtle.importKey(
    "raw",
    new TextEncoder().encode(config.webhookSecret),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const digest = await crypto.subtle.sign(
    "HMAC",
    key,
    new TextEncoder().encode(body),
  );
  const expected = [...new Uint8Array(digest)]
    .map((byte) => byte.toString(16).padStart(2, "0"))
    .join("");
  return expected === signature;
}

export async function verifyRazorpayPaymentSignature(
  config: RazorpayConfig,
  orderId: string,
  paymentId: string,
  signature: string,
): Promise<boolean> {
  if (config.stubMode) {
    return signature === "stub_payment_signature" || signature.length > 0;
  }
  if (!config.keySecret) {
    return false;
  }
  const payload = `${orderId}|${paymentId}`;
  const key = await crypto.subtle.importKey(
    "raw",
    new TextEncoder().encode(config.keySecret),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const digest = await crypto.subtle.sign(
    "HMAC",
    key,
    new TextEncoder().encode(payload),
  );
  const expected = [...new Uint8Array(digest)]
    .map((byte) => byte.toString(16).padStart(2, "0"))
    .join("");
  return expected === signature;
}
