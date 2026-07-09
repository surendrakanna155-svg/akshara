// COM-4 (Track B gap-sweep) — internal cron authentication for the
// scheduled-broadcast runner.
//
// `POST /communications/broadcasts/run-scheduled` normally requires a full
// user JWT + the `manageCommunications` permission (see
// `handleRunScheduledBroadcasts`), scoped to the caller's own org. A scheduler
// (VPS cron) has no user session, so it needs an alternate way in — but the
// route must NEVER become reachable without SOME credential.
//
// This mirrors the only existing internal-auth precedent in the codebase,
// `internal_health_auth.ts` (`INTERNAL_HEALTH_TOKEN` / `x-internal-health-token`),
// but is intentionally STRICTER: the health-token guard allows any request
// through when the token is unset in non-production environments (a
// local/dev convenience). The cron path fans a single call out across EVERY
// org, so there is no safe "unset = open" mode for any environment — an
// unset/empty `INTERNAL_CRON_TOKEN` must ALWAYS fail closed (see
// `verifyInternalCronToken`).
//
// Like `communication_webhook_auth.ts` (COMMUNICATION_WEBHOOK_SECRET), this
// module owns its own env var directly rather than threading a new field
// through the shared `AppConfig` — keeping the change local to this module
// per the file-ownership boundary for this task.

export interface CommunicationCronConfig {
  /** Shared secret from `INTERNAL_CRON_TOKEN`; null when unset/empty. */
  token: string | null;
}

/** Loads the internal cron token from the environment. */
export function loadCommunicationCronConfig(): CommunicationCronConfig {
  const raw = Deno.env.get("INTERNAL_CRON_TOKEN") ?? null;
  return { token: raw && raw.length > 0 ? raw : null };
}

/** Lowercase hex SHA-256 digest of `value`. */
async function sha256Hex(value: string): Promise<string> {
  const digest = await crypto.subtle.digest(
    "SHA-256",
    new TextEncoder().encode(value),
  );
  return [...new Uint8Array(digest)]
    .map((byte) => byte.toString(16).padStart(2, "0"))
    .join("");
}

/** Constant-time compare of two SHA-256 hex digests (always 64 chars, so the
 * loop never branches on length — unlike a raw string `===`, which both
 * short-circuits on length and can leak comparison time on the plaintext). */
function timingSafeEqualHex(a: string, b: string): boolean {
  let mismatch = 0;
  for (let i = 0; i < a.length; i++) {
    mismatch |= a.charCodeAt(i) ^ b.charCodeAt(i);
  }
  return mismatch === 0;
}

/**
 * Verifies the `x-internal-cron-token` header value against the configured
 * `INTERNAL_CRON_TOKEN`.
 *
 * FAIL CLOSED, no exceptions:
 *   - unset/empty server-side token  → always `false` (never authorizes,
 *     regardless of environment — there is no dev/local bypass here).
 *   - missing/empty provided header  → always `false`.
 *   - otherwise: SHA-256 both sides and compare digests in constant time, so
 *     neither the token's length nor its content is observable via timing.
 */
export async function verifyInternalCronToken(
  config: CommunicationCronConfig,
  providedToken: string | null,
): Promise<boolean> {
  if (!config.token) return false;
  if (!providedToken || providedToken.length === 0) return false;
  const [expected, provided] = await Promise.all([
    sha256Hex(config.token),
    sha256Hex(providedToken),
  ]);
  return timingSafeEqualHex(expected, provided);
}

/** Header the scheduler presents the token in. */
export const INTERNAL_CRON_TOKEN_HEADER = "x-internal-cron-token";

/**
 * Synthetic actor identity for cron-triggered runs — no human session backs
 * this call. `audit_events.user_id` has no FK constraint (see
 * `20260614500000_audit_ingestion_domain_events.sql`), so writing this fixed,
 * recognizable non-null id is safe and makes cron-originated audit rows
 * unambiguous at a glance.
 */
export const INTERNAL_CRON_ACTOR_ID = "00000000-0000-0000-0000-000000000000";
export const INTERNAL_CRON_SESSION_ID = "internal-cron";
export const INTERNAL_CRON_ROLE = "system";
