export interface RazorpayConfig {
  keyId: string | null;
  keySecret: string | null;
  webhookSecret: string | null;
  /** True when live Razorpay API calls are allowed. */
  enabled: boolean;
  /** Stub gateway when credentials absent (staging/dev). */
  stubMode: boolean;
}

export function loadRazorpayConfig(): RazorpayConfig {
  const keyId = Deno.env.get("RAZORPAY_KEY_ID") ?? null;
  const keySecret = Deno.env.get("RAZORPAY_KEY_SECRET") ?? null;
  const webhookSecret = Deno.env.get("RAZORPAY_WEBHOOK_SECRET") ?? null;
  const forceStub = (Deno.env.get("RAZORPAY_STUB_MODE") ?? "true").toLowerCase() === "true";
  const enabled = Boolean(keyId && keySecret) && !forceStub;
  return {
    keyId,
    keySecret,
    webhookSecret,
    enabled,
    stubMode: !enabled,
  };
}
