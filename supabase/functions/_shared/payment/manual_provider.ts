// A SECOND, honest PaymentProvider — offline / bank-transfer / cash.
//
// This exists to prove the abstraction supports >1 provider WITHOUT pretending
// an unimplemented online gateway works. It is deliberately, transparently
// fail-closed on the automated capture path:
//
//   • createOrder — issues a real, pending "pay offline with this reference"
//     order. A reference number is NOT a receipt; no money has moved, nothing is
//     posted to the books. This is honest: it is the school's bank-transfer /
//     cash reference the parent quotes when paying.
//
//   • verifyPaymentSignature — ALWAYS false. An offline payment carries no
//     gateway signature the payer's app can present, so the parent-facing
//     confirm endpoint can NEVER self-capture it. Settlement happens out of band
//     (finance staff reconcile the bank statement and record the collection
//     through the finance maker-checker flow), not by fabricating a receipt here.
//
//   • verifyWebhookSignature — ALWAYS false. There is no gateway webhook.
//
//   • requiresGatewaySignature — true, so the confirm path enters its
//     verification branch and, finding no verifiable signature, fails closed.
//
// The net effect: a school can be switched to offline collection and the
// abstraction routes to this provider, but no unverified payment ever becomes a
// receipt. Fail-closed is preserved end-to-end.

import type {
  PaymentProvider,
  ProviderCreateOrderInput,
  ProviderOrder,
} from "./payment_provider.ts";

export const MANUAL_PROVIDER_ID = "manual";

export class ManualProvider implements PaymentProvider {
  readonly id = MANUAL_PROVIDER_ID;

  createOrder(input: ProviderCreateOrderInput): Promise<ProviderOrder> {
    // A pending offline-payment reference. Amount mirrors Razorpay's paise unit
    // for a consistent order shape. This is an intent to pay, not proof of it.
    const reference = `manual_${input.receipt}`;
    return Promise.resolve({
      id: reference,
      amount: input.amount * 100,
      currency: input.currency ?? "INR",
      receipt: input.receipt,
    });
  }

  // deno-lint-ignore require-await
  async verifyPaymentSignature(
    _orderId: string,
    _paymentId: string,
    _signature: string,
  ): Promise<boolean> {
    // Offline payments are not self-verifiable by the payer. FAIL CLOSED: never
    // returns true, so the confirm path can never fabricate a receipt for a
    // manual payment.
    return false;
  }

  // deno-lint-ignore require-await
  async verifyWebhookSignature(
    _body: string,
    _signature: string | null,
  ): Promise<boolean> {
    // No gateway, no webhook — anything presented as one is rejected.
    return false;
  }

  requiresGatewaySignature(): boolean {
    // Forces the confirm path into its verification branch, where the always-false
    // verifyPaymentSignature (or the absence of any signature) fails it closed.
    return true;
  }

  publicClientKey(): string | null {
    // No client-side SDK / publishable key for offline collection.
    return null;
  }
}
