// Razorpay as a PaymentProvider — a thin WRAPPER over the existing, certified
// razorpay_client.ts logic (order-create + signature/webhook verification). The
// gateway behaviour is NOT rewritten here; this only binds a RazorpayConfig to
// the PaymentProvider seam so the flow can talk to Razorpay through the registry
// instead of importing razorpay_client directly.

import type { RazorpayConfig } from "./razorpay_config.ts";
import { loadRazorpayConfig } from "./razorpay_config.ts";
import {
  createRazorpayOrder,
  verifyRazorpayPaymentSignature,
  verifyRazorpayWebhookSignature,
} from "./razorpay_client.ts";
import type {
  PaymentProvider,
  ProviderCreateOrderInput,
  ProviderOrder,
} from "./payment_provider.ts";

export const RAZORPAY_PROVIDER_ID = "razorpay";

export class RazorpayProvider implements PaymentProvider {
  readonly id = RAZORPAY_PROVIDER_ID;

  constructor(private readonly config: RazorpayConfig) {}

  createOrder(input: ProviderCreateOrderInput): Promise<ProviderOrder> {
    // Delegates verbatim to the existing client (stub-mode + live paths intact).
    return createRazorpayOrder(this.config, input);
  }

  verifyPaymentSignature(
    orderId: string,
    paymentId: string,
    signature: string,
  ): Promise<boolean> {
    return verifyRazorpayPaymentSignature(
      this.config,
      orderId,
      paymentId,
      signature,
    );
  }

  verifyWebhookSignature(
    body: string,
    signature: string | null,
  ): Promise<boolean> {
    return verifyRazorpayWebhookSignature(this.config, body, signature);
  }

  requiresGatewaySignature(): boolean {
    // Preserves the exact confirm/webhook gate the service used before: a LIVE
    // Razorpay gateway demands signature proof; stub mode (no real money) does
    // not. `stubMode` is the inverse of `enabled` in loadRazorpayConfig().
    return !this.config.stubMode;
  }

  publicClientKey(): string | null {
    return this.config.keyId;
  }
}

/** Build a Razorpay provider from the process env (RAZORPAY_* / stub default). */
export function razorpayProviderFromEnv(): RazorpayProvider {
  return new RazorpayProvider(loadRazorpayConfig());
}
