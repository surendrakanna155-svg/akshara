// PRC-A Batch 2 — Gate Pass single-use credential crypto.
//
// The credential presented at the gate is a 6-digit OTP OR a QR token; ONLY
// their SHA-256 hashes are ever persisted (mirrors the OTP-login hashing in
// auth_handlers.ts / jwt.ts's `hashToken`). Generation uses
// `crypto.getRandomValues` — never `Math.random` (the existing login-OTP
// generator in auth_handlers.ts uses Math.random and is NOT reused here on
// purpose; this is a child-safety credential, not a login nuisance code).
// Comparison is constant-time (mirrors the pattern in
// communication_webhook_auth.ts / communication_cron_auth.ts).

import { hashToken } from "../jwt.ts";

/**
 * Credential TTL policy: an approved gate pass's OTP/QR is valid from
 * approval until `scheduled_at + GATE_PASS_CREDENTIAL_TTL_HOURS`. A fixed
 * grace window past the scheduled pickup/exit time (rather than e.g.
 * "end of calendar day") keeps the policy deterministic and independent of
 * timezone/midnight edge cases, while still covering normal pickup-time
 * slippage (traffic, a delayed parent, etc.).
 */
export const GATE_PASS_CREDENTIAL_TTL_HOURS = 4;

/** `scheduledAt + GATE_PASS_CREDENTIAL_TTL_HOURS`. Pure — unit-testable without a DB. */
export function computeCredentialExpiry(scheduledAt: Date): Date {
  return new Date(scheduledAt.getTime() + GATE_PASS_CREDENTIAL_TTL_HOURS * 60 * 60 * 1000);
}

/** A 6-digit numeric OTP, uniformly distributed over 000000-999999, CSPRNG-sourced. */
export function generateGatePassOtp(): string {
  const buf = new Uint32Array(1);
  crypto.getRandomValues(buf);
  // buf[0] is uniform over [0, 2^32); mod 1_000_000 bias is negligible
  // (< 1 part in 4x10^3) and acceptable for a 6-digit human-entered code.
  const n = buf[0] % 1_000_000;
  return n.toString().padStart(6, "0");
}

/** A 256-bit random token (hex) for the QR-code payload. */
export function generateGatePassQrToken(): string {
  const buf = new Uint8Array(32);
  crypto.getRandomValues(buf);
  return Array.from(buf).map((b) => b.toString(16).padStart(2, "0")).join("");
}

/** SHA-256 hex digest — reuses the same primitive the OTP-login flow hashes with. */
export async function hashGatePassSecret(plaintext: string): Promise<string> {
  return await hashToken(plaintext);
}

/** Constant-time compare of two equal-length hex strings (mirrors communication_webhook_auth.ts). */
export function timingSafeEqualHex(a: string, b: string): boolean {
  if (a.length !== b.length) return false;
  let mismatch = 0;
  for (let i = 0; i < a.length; i++) {
    mismatch |= a.charCodeAt(i) ^ b.charCodeAt(i);
  }
  return mismatch === 0;
}
