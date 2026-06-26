import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import {
  type CommunicationWebhookConfig,
  verifyCommunicationWebhookSignature,
} from "./communication_webhook_auth.ts";

const SECRET = "test-webhook-secret";

async function sign(secret: string, body: string): Promise<string> {
  const key = await crypto.subtle.importKey(
    "raw",
    new TextEncoder().encode(secret),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const digest = await crypto.subtle.sign("HMAC", key, new TextEncoder().encode(body));
  return [...new Uint8Array(digest)].map((b) => b.toString(16).padStart(2, "0")).join("");
}

const enforced: CommunicationWebhookConfig = { secret: SECRET, stubMode: false };

Deno.test("accepts a correctly signed body", async () => {
  const body = JSON.stringify({ deliveryId: "d1", status: "delivered" });
  const sig = await sign(SECRET, body);
  assertEquals(await verifyCommunicationWebhookSignature(enforced, body, sig), true);
});

Deno.test("rejects a missing signature when a secret is configured", async () => {
  const body = JSON.stringify({ deliveryId: "d1", status: "delivered" });
  assertEquals(await verifyCommunicationWebhookSignature(enforced, body, null), false);
});

Deno.test("rejects a forged/wrong signature", async () => {
  const body = JSON.stringify({ deliveryId: "d1", status: "delivered" });
  const wrong = await sign("attacker-secret", body);
  assertEquals(await verifyCommunicationWebhookSignature(enforced, body, wrong), false);
});

Deno.test("rejects a signature for a tampered body", async () => {
  const original = JSON.stringify({ deliveryId: "d1", status: "delivered" });
  const tampered = JSON.stringify({ deliveryId: "d1", status: "failed" });
  const sig = await sign(SECRET, original);
  assertEquals(await verifyCommunicationWebhookSignature(enforced, tampered, sig), false);
});

Deno.test("stub mode (no secret) accepts any request for local/cert runs", async () => {
  const stub: CommunicationWebhookConfig = { secret: null, stubMode: true };
  const body = JSON.stringify({ deliveryId: "d1" });
  assertEquals(await verifyCommunicationWebhookSignature(stub, body, null), true);
});
