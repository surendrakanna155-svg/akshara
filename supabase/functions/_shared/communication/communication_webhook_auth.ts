// SEC-1 (Wave 3) — authentication for the external delivery-status webhook.
//
// Provider callbacks to `POST /communications/delivery/webhook` carry no JWT, so
// they are authenticated with a shared-secret HMAC-SHA256 over the raw request
// body (same scheme as the Razorpay webhook). The tenant is then derived from the
// matched delivery row (see handleDeliveryWebhook), never from the payload itself.
//
// PRC-A Batch 5 (owner-idea 25) — the private hmacHex + timingSafeEqualHex here
// were one of three near-duplicate copies; verification now goes through the one
// canonical constant-time verifier in `../webhook_hmac.ts` (which also closes the
// small length-leak in the old local compare — it compared over full max length).

import { verifyHmacSha256Hex } from "../webhook_hmac.ts";

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
  return await verifyHmacSha256Hex(config.secret, body, signature);
}
