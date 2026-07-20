// W3 Payment Provider Abstraction (Owner decision #7, FINAL · PRA-P0-02)
//
// A gateway-neutral seam over the three operations the payment flow actually
// needs. Schools choose their preferred gateway (config-driven, default
// 'razorpay'); the registry/resolver maps that choice onto one of these.
//
// FAIL-CLOSED CONTRACT (never weaken): a provider MUST NOT fabricate a receipt
// or a "verified" result. Verification methods return a real boolean (or throw);
// an unverifiable payment is FALSE, never a silent true. The service treats a
// false/throw as a hard error and refuses to capture — so an unconfigured
// provider, an unimplemented gateway, or an unverified signature can never turn
// into money-in-the-books.

/** A gateway order (payment request), NOT a receipt/proof of payment. */
export interface ProviderOrder {
  /** Gateway order id (Razorpay `order_...`) or provider reference. */
  id: string;
  /** Amount in the smallest currency unit (paise), mirroring Razorpay. */
  amount: number;
  currency: string;
  /** Echo of the caller's receipt reference (our payment_requests.id). */
  receipt?: string;
}

export interface ProviderCreateOrderInput {
  /** Amount in rupees (whole units), as the flow supplies today. */
  amount: number;
  currency?: string;
  /** Our payment_requests.id — the gateway's `receipt` field. */
  receipt: string;
  notes?: Record<string, string>;
}

/**
 * The operations the order-create → confirm → webhook flow requires. Exactly the
 * seams `razorpay_client.ts` already implements — extracted so a second gateway
 * can plug in without the flow calling any one gateway directly.
 */
export interface PaymentProvider {
  /** Stable id; matches the config value AND payment_intents.gateway. */
  readonly id: string;

  /** Create a gateway order (or offline reference). Never issues a receipt. */
  createOrder(input: ProviderCreateOrderInput): Promise<ProviderOrder>;

  /**
   * Verify a completed-payment signature (order|payment). MUST be constant-time
   * and MUST return false — never throw-to-true — when it cannot be verified.
   */
  verifyPaymentSignature(
    orderId: string,
    paymentId: string,
    signature: string,
  ): Promise<boolean>;

  /** Verify an inbound webhook signature. False when unverifiable. */
  verifyWebhookSignature(
    body: string,
    signature: string | null,
  ): Promise<boolean>;

  /**
   * When true, the confirm path MUST obtain and verify a gateway signature
   * before capturing (live gateways, and any provider whose payments cannot be
   * self-confirmed by the payer). When false, capture may proceed without a
   * client signature — reserved for a stub/test gateway that touches no real
   * money. Fail-closed default for any real provider is `true`.
   */
  requiresGatewaySignature(): boolean;

  /**
   * The public/publishable key the client SDK initialises with, if the provider
   * exposes one (Razorpay key id). Null when the provider has no client key
   * (e.g. an offline/manual provider).
   */
  publicClientKey(): string | null;
}

/**
 * Thrown when a school is configured with a provider id that has no registered
 * implementation. Resolving it is FAIL-CLOSED — the flow errors rather than
 * silently falling back and pretending an unknown gateway works.
 */
export class UnknownPaymentProviderError extends Error {
  constructor(public readonly providerId: string) {
    super(`Unknown payment provider: ${providerId}`);
    this.name = "UnknownPaymentProviderError";
  }
}

/**
 * Thrown when a school has explicitly DISABLED online payments for its
 * configured provider. Fail-closed: we do not silently fall back to a default
 * gateway a school has switched off.
 */
export class PaymentProviderDisabledError extends Error {
  constructor(public readonly providerId: string) {
    super(`Payment provider is disabled for this school: ${providerId}`);
    this.name = "PaymentProviderDisabledError";
  }
}
