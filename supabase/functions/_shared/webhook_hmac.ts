// PRC-A Batch 5 — canonical webhook HMAC-SHA256 verification (owner-idea 25).
//
// One constant-time verifier, replacing near-duplicate copies scattered across
// the webhook surfaces. The reason this is a framework and not three private
// helpers: razorpay_client.ts verified signatures with a plain `expected ===
// signature` — a NON-constant-time comparison. A `===` on strings short-circuits
// at the first differing byte, so an attacker can measure response time to learn
// how many leading bytes of a forged signature are correct, and reconstruct a
// valid signature byte-by-byte. On the Razorpay WEBHOOK — which authorises a
// payment capture — and the payment-confirmation signature, that is a
// money-integrity hole, not a theoretical nicety. comms/gate_pass already did
// this correctly with their own copies; consolidating means there is ONE
// verifier that is right, and nowhere left to get it wrong.

/** Lowercase-hex HMAC-SHA256 of `body` keyed by `secret`. */
export async function hmacSha256Hex(secret: string, body: string): Promise<string> {
  const key = await crypto.subtle.importKey(
    "raw",
    new TextEncoder().encode(secret),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const digest = await crypto.subtle.sign("HMAC", key, new TextEncoder().encode(body));
  return [...new Uint8Array(digest)]
    .map((byte) => byte.toString(16).padStart(2, "0"))
    .join("");
}

/**
 * Constant-time hex-string equality. Compares over the FULL max length and folds
 * a length mismatch into the accumulator, so the running time leaks neither which
 * byte differs NOR whether the two strings even have the same length. Out-of-range
 * `charCodeAt` is NaN → coerced to 0 before the XOR.
 */
export function timingSafeEqualHex(a: string, b: string): boolean {
  const len = Math.max(a.length, b.length);
  let mismatch = a.length === b.length ? 0 : 1;
  for (let i = 0; i < len; i++) {
    mismatch |= (a.charCodeAt(i) || 0) ^ (b.charCodeAt(i) || 0);
  }
  return mismatch === 0;
}

/**
 * Verify a caller-supplied lowercase-hex HMAC-SHA256 signature over `body` keyed
 * by `secret`, in constant time. The provided signature is trimmed + lowercased
 * (providers vary in casing/whitespace). Returns false — never throws — on a
 * missing secret or signature, so a verify failure is always a clean reject.
 */
export async function verifyHmacSha256Hex(
  secret: string | null | undefined,
  body: string,
  signatureHex: string | null | undefined,
): Promise<boolean> {
  if (!secret || !signatureHex) return false;
  const expected = await hmacSha256Hex(secret, body);
  return timingSafeEqualHex(expected, signatureHex.trim().toLowerCase());
}
