// PRC-A Batch 5 — canonical webhook HMAC verifier.

import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import { hmacSha256Hex, timingSafeEqualHex, verifyHmacSha256Hex } from "./webhook_hmac.ts";

const SECRET = "whsec_test_secret";
const BODY = '{"event":"payment.captured","id":"evt_1"}';

Deno.test("hmacSha256Hex is deterministic lowercase hex of the right length", async () => {
  const a = await hmacSha256Hex(SECRET, BODY);
  const b = await hmacSha256Hex(SECRET, BODY);
  assertEquals(a, b);
  assertEquals(a.length, 64); // SHA-256 → 32 bytes → 64 hex chars
  assertEquals(/^[0-9a-f]{64}$/.test(a), true);
});

Deno.test("hmacSha256Hex changes when the body changes by one byte", async () => {
  const a = await hmacSha256Hex(SECRET, BODY);
  const b = await hmacSha256Hex(SECRET, BODY + " ");
  assertEquals(a === b, false);
});

Deno.test("verifyHmacSha256Hex accepts a correct signature", async () => {
  const sig = await hmacSha256Hex(SECRET, BODY);
  assertEquals(await verifyHmacSha256Hex(SECRET, BODY, sig), true);
});

Deno.test("verifyHmacSha256Hex accepts an upper-cased / padded signature (normalised)", async () => {
  const sig = await hmacSha256Hex(SECRET, BODY);
  assertEquals(await verifyHmacSha256Hex(SECRET, BODY, `  ${sig.toUpperCase()}  `), true);
});

Deno.test("verifyHmacSha256Hex rejects a tampered signature", async () => {
  const sig = await hmacSha256Hex(SECRET, BODY);
  const tampered = (sig[0] === "a" ? "b" : "a") + sig.slice(1);
  assertEquals(await verifyHmacSha256Hex(SECRET, BODY, tampered), false);
});

Deno.test("verifyHmacSha256Hex rejects the wrong secret", async () => {
  const sig = await hmacSha256Hex(SECRET, BODY);
  assertEquals(await verifyHmacSha256Hex("other_secret", BODY, sig), false);
});

Deno.test("verifyHmacSha256Hex rejects a missing secret or signature (clean false, no throw)", async () => {
  assertEquals(await verifyHmacSha256Hex(null, BODY, "abc"), false);
  assertEquals(await verifyHmacSha256Hex(SECRET, BODY, null), false);
  assertEquals(await verifyHmacSha256Hex("", BODY, "abc"), false);
});

Deno.test("timingSafeEqualHex: equal true, differing false, differing-length false", () => {
  assertEquals(timingSafeEqualHex("deadbeef", "deadbeef"), true);
  assertEquals(timingSafeEqualHex("deadbeef", "deadbee0"), false);
  assertEquals(timingSafeEqualHex("dead", "deadbeef"), false);
  assertEquals(timingSafeEqualHex("", ""), true);
});
