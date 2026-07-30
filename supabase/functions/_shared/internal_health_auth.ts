import type { AppConfig } from "./config.ts";
import { errorEnvelope } from "./http.ts";
import { timingSafeEqualHex } from "./webhook_hmac.ts";

/** Guards sensitive health probes — requires `x-internal-health-token` when configured. */
export function requireInternalHealthAccess(
  req: Request,
  config: AppConfig,
): Response | null {
  const configured = config.internalHealthToken;
  if (!configured) {
    if (config.environment === "production") {
      return errorEnvelope(
        "FORBIDDEN",
        "Internal health endpoints require INTERNAL_HEALTH_TOKEN in production",
        403,
      );
    }
    return null;
  }
  // Constant-time compare: a plain `!==` short-circuits at the first differing
  // byte, leaking — via response timing — how many leading bytes of a guessed
  // token are correct, which lets the secret be reconstructed byte-by-byte.
  // `timingSafeEqualHex` compares over the full max length and folds a length
  // mismatch into the accumulator, so neither content nor length is observable.
  // A missing header (null) is normalised to "" so every reject runs the same path.
  const provided = req.headers.get("x-internal-health-token") ?? "";
  if (!timingSafeEqualHex(provided, configured)) {
    return errorEnvelope("FORBIDDEN", "Invalid or missing internal health token", 403);
  }
  return null;
}
