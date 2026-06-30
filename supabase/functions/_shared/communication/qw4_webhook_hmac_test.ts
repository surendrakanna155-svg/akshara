// QW4 · QA-B-070 — delivery-status webhook HMAC authentication.
// The provider callback carries no JWT; it is authenticated by an HMAC-SHA256 over
// the raw body (x-akshara-signature). This proves the verifier accepts a valid
// signature and rejects a bad/missing one, and that stub mode (no secret) is open.
import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import {
  verifyCommunicationWebhookSignature,
  type CommunicationWebhookConfig,
} from "./communication_webhook_auth.ts";

const SECRET = "whsec_qa_b070_shared_secret";
const BODY = JSON.stringify({ messageId: "m-1", status: "delivered" });

/** Lowercase hex HMAC-SHA256, mirroring the verifier's own scheme. */
async function sign(secret: string, body: string): Promise<string> {
  const key = await crypto.subtle.importKey(
    "raw", new TextEncoder().encode(secret), { name: "HMAC", hash: "SHA-256" }, false, ["sign"],
  );
  const digest = await crypto.subtle.sign("HMAC", key, new TextEncoder().encode(body));
  return [...new Uint8Array(digest)].map((b) => b.toString(16).padStart(2, "0")).join("");
}

const live: CommunicationWebhookConfig = { secret: SECRET, stubMode: false };
const stub: CommunicationWebhookConfig = { secret: null, stubMode: true };

Deno.test("QA-B-070: a valid HMAC signature is accepted", async () => {
  const sig = await sign(SECRET, BODY);
  assertEquals(await verifyCommunicationWebhookSignature(live, BODY, sig), true);
});

Deno.test("QA-B-070: a signature over a DIFFERENT body is rejected (tamper)", async () => {
  const sig = await sign(SECRET, BODY);
  const tamperedBody = JSON.stringify({ messageId: "m-1", status: "failed" });
  assertEquals(await verifyCommunicationWebhookSignature(live, tamperedBody, sig), false);
});

Deno.test("QA-B-070: a signature made with the WRONG secret is rejected", async () => {
  const sig = await sign("attacker-secret", BODY);
  assertEquals(await verifyCommunicationWebhookSignature(live, BODY, sig), false);
});

Deno.test("QA-B-070: a missing signature is rejected when a secret is configured", async () => {
  assertEquals(await verifyCommunicationWebhookSignature(live, BODY, null), false);
});

Deno.test("QA-B-070: stub mode (no secret) accepts any request for local/cert runs", async () => {
  assertEquals(await verifyCommunicationWebhookSignature(stub, BODY, null), true);
  assertEquals(await verifyCommunicationWebhookSignature(stub, BODY, "anything"), true);
});
