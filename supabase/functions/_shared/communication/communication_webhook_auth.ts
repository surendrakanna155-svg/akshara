// SEC-1 (Wave 3) — authentication for the external delivery-status webhook.
//
// Provider callbacks to `POST /communications/delivery/webhook` carry no JWT, so
// they are authenticated with a shared-secret HMAC-SHA256 over the raw request
// body (same scheme as the Razorpay webhook). The tenant is then derived from the
// matched delivery row (see handleDeliveryWebhook), never from the payload itself.

export interface CommunicationWebhookConfig {
  /** Shared secret; when null the webhook runs in stub mode (local/cert only). */
  secret: string | null;
  /** True when no secret is configured — signature checks are skipped. */
  stubMode: boolean;
}

/** Loads the webhook secret from the environment. */
export function loadCommunicationWebhookConfig(): CommunicationWebhookConfig {
  const secret = Deno.env.get("COMMUNICATION_WEBHOOK_SECRET") ?? null;
  return { secret, stubMode: secret === null || secret.length === 0 };
}

/** Lowercase hex HMAC-SHA256 of `body` keyed by `secret`. */
async function hmacHex(secret: string, body: string): Promise<string> {
  const key = await crypto.subtle.importKey(
    "raw",
    new TextEncoder().encode(secret),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const digest = await crypto.subtle.sign(
    "HMAC",
    key,
    new TextEncoder().encode(body),
  );
  return [...new Uint8Array(digest)]
    .map((byte) => byte.toString(16).padStart(2, "0"))
    .join("");
}

/** Constant-time compare of two equal-length hex strings. */
function timingSafeEqualHex(a: string, b: string): boolean {
  if (a.length !== b.length) return false;
  let mismatch = 0;
  for (let i = 0; i < a.length; i++) {
    mismatch |= a.charCodeAt(i) ^ b.charCodeAt(i);
  }
  return mismatch === 0;
}

/**
 * Verifies the `x-akshara-signature` header against the raw body. In stub mode
 * (no secret configured) any request is accepted so local/cert runs work without
 * provisioning a secret; in production a valid signature is required.
 */
export async function verifyCommunicationWebhookSignature(
  config: CommunicationWebhookConfig,
  body: string,
  signature: string | null,
): Promise<boolean> {
  if (config.stubMode) return true;
  if (!config.secret || !signature) return false;
  const expected = await hmacHex(config.secret, body);
  return timingSafeEqualHex(expected, signature.trim().toLowerCase());
}
