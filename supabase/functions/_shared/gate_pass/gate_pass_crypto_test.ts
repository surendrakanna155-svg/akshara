import { assertEquals, assertNotEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import {
  computeCredentialExpiry,
  GATE_PASS_CREDENTIAL_TTL_HOURS,
  generateGatePassOtp,
  generateGatePassQrToken,
  hashGatePassSecret,
  timingSafeEqualHex,
} from "./gate_pass_crypto.ts";

Deno.test("generateGatePassOtp: always a 6-digit numeric string", () => {
  for (let i = 0; i < 200; i++) {
    const otp = generateGatePassOtp();
    assertEquals(otp.length, 6);
    assertEquals(/^\d{6}$/.test(otp), true, `not all-digit: ${otp}`);
  }
});

Deno.test("generateGatePassOtp: not constant (CSPRNG, not a fixed value)", () => {
  const seen = new Set<string>();
  for (let i = 0; i < 50; i++) seen.add(generateGatePassOtp());
  // Extremely unlikely to collapse to <10 distinct values across 50 draws
  // unless the generator were broken (e.g. always returning "000000").
  assertEquals(seen.size > 10, true);
});

Deno.test("generateGatePassQrToken: 64 lowercase hex chars (256-bit)", () => {
  const token = generateGatePassQrToken();
  assertEquals(token.length, 64);
  assertEquals(/^[0-9a-f]{64}$/.test(token), true);
});

Deno.test("generateGatePassQrToken: distinct across calls", () => {
  const a = generateGatePassQrToken();
  const b = generateGatePassQrToken();
  assertNotEquals(a, b);
});

Deno.test("hashGatePassSecret: deterministic SHA-256 hex, 64 chars", async () => {
  const h1 = await hashGatePassSecret("123456");
  const h2 = await hashGatePassSecret("123456");
  assertEquals(h1, h2);
  assertEquals(h1.length, 64);
  assertEquals(/^[0-9a-f]{64}$/.test(h1), true);
});

Deno.test("hashGatePassSecret: different inputs hash differently", async () => {
  const a = await hashGatePassSecret("123456");
  const b = await hashGatePassSecret("123457");
  assertNotEquals(a, b);
});

Deno.test("timingSafeEqualHex: equal strings match", () => {
  assertEquals(timingSafeEqualHex("abcd1234", "abcd1234"), true);
});

Deno.test("timingSafeEqualHex: a single differing character fails", () => {
  assertEquals(timingSafeEqualHex("abcd1234", "abcd1235"), false);
});

Deno.test("timingSafeEqualHex: different lengths fail (no length-based shortcut leak beyond a boolean)", () => {
  assertEquals(timingSafeEqualHex("abcd", "abcd1234"), false);
});

Deno.test("computeCredentialExpiry: scheduledAt + GATE_PASS_CREDENTIAL_TTL_HOURS", () => {
  const scheduledAt = new Date("2026-07-15T10:00:00.000Z");
  const expiry = computeCredentialExpiry(scheduledAt);
  assertEquals(
    expiry.getTime() - scheduledAt.getTime(),
    GATE_PASS_CREDENTIAL_TTL_HOURS * 60 * 60 * 1000,
  );
  assertEquals(GATE_PASS_CREDENTIAL_TTL_HOURS, 4);
});
