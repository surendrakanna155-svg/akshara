import {
  assertEquals,
} from "https://deno.land/std@0.224.0/assert/mod.ts";
import { evaluateOtpRateLimit, type OtpRateLimits } from "./otp_rate_limit.ts";

const limits: OtpRateLimits = {
  windowSeconds: 3600,
  maxPerPhone: 5,
  maxPerIp: 20,
  resendCooldownSeconds: 60,
};

const NOW = 1_700_000_000_000;

Deno.test("allows a first request", () => {
  const d = evaluateOtpRateLimit([], 0, limits, NOW);
  assertEquals(d.allowed, true);
});

Deno.test("blocks rapid resend within cooldown", () => {
  const d = evaluateOtpRateLimit([NOW - 10_000], 0, limits, NOW);
  assertEquals(d.allowed, false);
  assertEquals(d.code, "OTP_COOLDOWN");
  assertEquals(d.retryAfterSeconds, 50);
});

Deno.test("allows resend after cooldown", () => {
  const d = evaluateOtpRateLimit([NOW - 70_000], 0, limits, NOW);
  assertEquals(d.allowed, true);
});

Deno.test("blocks when per-phone cap reached", () => {
  const times = [2, 3, 4, 5, 6].map((m) => NOW - m * 60_000); // 5 old requests
  const d = evaluateOtpRateLimit(times, 0, limits, NOW);
  assertEquals(d.allowed, false);
  assertEquals(d.code, "OTP_RATE_LIMITED");
});

Deno.test("blocks when per-IP cap reached", () => {
  const d = evaluateOtpRateLimit([NOW - 120_000], 20, limits, NOW);
  assertEquals(d.allowed, false);
  assertEquals(d.code, "OTP_IP_RATE_LIMITED");
});

Deno.test("cooldown takes precedence over caps", () => {
  const times = [2, 3, 4, 5].map((m) => NOW - m * 60_000);
  times.push(NOW - 5_000); // most recent within cooldown
  const d = evaluateOtpRateLimit(times, 0, limits, NOW);
  assertEquals(d.code, "OTP_COOLDOWN");
});
