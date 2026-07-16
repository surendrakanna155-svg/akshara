// Append-only telemetry for the AI Model Gateway (P3-AI-1 / W1.1).
//
// Persists one row per governed model call and exposes the trailing-window
// aggregates the gateway uses to enforce rate limits and the monthly spend cap.
// Every query is org+school scoped; RLS (see migration 20260867000000) forces
// the same scope again as defense-in-depth, so a caller can only ever read or
// write its own tenant's telemetry.

import type { TenantQueryClient } from "../tenant_db.ts";

/** The outcomes an attempted gateway call can record. */
export type AiCallOutcome =
  | "ok"
  | "refused"
  | "fallback_no_key"
  | "fallback_rate_user"
  | "fallback_rate_school"
  | "fallback_spend_cap"
  | "fallback_timeout"
  | "fallback_error"
  /** Reply failed the output guard (output_guard.ts) → discarded, fallback served. */
  | "fallback_guard"
  /**
   * PRC-A Batch 3 — the org has no purchased AI credits left (owner decision #3).
   * Deliberately distinct from `fallback_spend_cap`: that is OUR cost governance
   * throttling us, this is the school running out of what it bought. Different
   * cause, different remedy (top up vs wait for the 1st), so the cost panel must
   * not conflate them.
   */
  | "fallback_wallet_empty";

export interface AiCallLogEntry {
  organizationId: string;
  /** Null for an org-scoped call (director / org-builder / onboarding). */
  schoolId: string | null;
  userId?: string | null;
  surface: string;
  provider: string;
  model: string;
  outcome: AiCallOutcome;
  inputTokens: number;
  outputTokens: number;
  estimatedCostMicros: number;
  latencyMs: number;
  cacheWritten: boolean;
  fallbackUsed: boolean;
  /**
   * PRC-A Batch 3 — product credits this call consumed from the org's wallet
   * (owner decision #3). Integer units, NOT currency: independent of
   * `estimatedCostMicros`, which stays our provider-cost governance number.
   *
   * Optional and defaulted to 0 so every existing caller compiles and behaves
   * unchanged. 0 is also the correct value whenever the wallet is not enforced
   * or the call never reached the provider — a denied call must never be charged
   * against a school's purchased credits.
   */
  creditsDebited?: number;
}

export interface AiTenantScope {
  organizationId: string;
  /** Null for an org-scoped call; matched with IS NOT DISTINCT FROM. */
  schoolId: string | null;
}

/** Rate windows count only attempts that reached (or tried to reach) the
 * provider. Pure gate denials are excluded — otherwise a user who is already
 * rate-limited keeps logging denial rows that fill the SCHOOL's daily window,
 * letting one hammering client lock every user in the school out of AI until
 * 24h of silence (audit P1-2, self-sustaining DoS amplification). Spend sums
 * are unaffected (denials carry zero cost). */
export const RATE_WINDOW_OUTCOME_FILTER =
  "outcome NOT IN ('fallback_no_key', 'fallback_rate_user', 'fallback_rate_school', 'fallback_spend_cap')";

/** Insert one telemetry row. Never throws into the caller's happy path — the
 * gateway wraps this so a logging failure can degrade to "unlogged" without
 * failing the user's request. */
export async function recordAiCall(
  db: TenantQueryClient,
  entry: AiCallLogEntry,
): Promise<void> {
  await db.queryObject(
    // PRC-A Batch 3: `credits_debited` rides THIS statement, deliberately — not a
    // separate best-effort write. The wallet debit and the record of the call it
    // pays for must be atomically inseparable: if the debit could be lost after
    // the row landed, the call was served and never charged (free usage). Sitting
    // in the same INSERT, either both exist or neither does — and "neither" is
    // already the pre-existing unlogged-call case that the spend cap shares, so
    // the wallet inherits exactly the same failure mode rather than a new one.
    // It sits ALONGSIDE estimated_cost_micros, never replacing it, so provider
    // cost governance and the purchased wallet stay reconcilable from one row.
    `INSERT INTO ai_call_log (
       organization_id, school_id, user_id, surface, provider, model, outcome,
       input_tokens, output_tokens, estimated_cost_micros, latency_ms,
       cache_written, fallback_used, credits_debited
     ) VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13,$14)`,
    [
      entry.organizationId,
      entry.schoolId,
      entry.userId ?? null,
      entry.surface,
      entry.provider,
      entry.model,
      entry.outcome,
      Math.trunc(entry.inputTokens),
      Math.trunc(entry.outputTokens),
      Math.trunc(entry.estimatedCostMicros),
      Math.trunc(entry.latencyMs),
      entry.cacheWritten,
      entry.fallbackUsed,
      Math.max(0, Math.trunc(entry.creditsDebited ?? 0)),
    ],
  );
}

/** Count this user's gateway calls in [sinceIso, now) — the per-user token
 * bucket. Only genuine attempts count toward the limit: no-key fallbacks are
 * excluded (they never reached the provider). */
export async function countUserCallsSince(
  db: TenantQueryClient,
  scope: AiTenantScope,
  userId: string,
  sinceIso: string,
): Promise<number> {
  const rows = await db.queryObject<{ n: number }>(
    `SELECT count(*)::int AS n
       FROM ai_call_log
      WHERE organization_id = $1 AND school_id IS NOT DISTINCT FROM $2 AND user_id = $3
        AND created_at >= $4
        AND ${RATE_WINDOW_OUTCOME_FILTER}`,
    [scope.organizationId, scope.schoolId, userId, sinceIso],
  );
  return Number(rows[0]?.n ?? 0);
}

/** Count a user's gateway calls on ONE surface in [sinceIso, now) — the
 * substrate for the per-role daily open-chat quota (W2 governance). No-key
 * fallbacks excluded (an unconfigured key must not burn a user's quota). */
export async function countUserSurfaceCallsSince(
  db: TenantQueryClient,
  scope: AiTenantScope,
  userId: string,
  surface: string,
  sinceIso: string,
): Promise<number> {
  const rows = await db.queryObject<{ n: number }>(
    `SELECT count(*)::int AS n
       FROM ai_call_log
      WHERE organization_id = $1 AND school_id IS NOT DISTINCT FROM $2 AND user_id = $3
        AND surface = $4
        AND created_at >= $5
        AND ${RATE_WINDOW_OUTCOME_FILTER}`,
    [scope.organizationId, scope.schoolId, userId, surface, sinceIso],
  );
  return Number(rows[0]?.n ?? 0);
}

/** Count this school's gateway calls in [sinceIso, now) — the per-school token
 * bucket. No-key fallbacks excluded (see {@link countUserCallsSince}). */
export async function countSchoolCallsSince(
  db: TenantQueryClient,
  scope: AiTenantScope,
  sinceIso: string,
): Promise<number> {
  const rows = await db.queryObject<{ n: number }>(
    `SELECT count(*)::int AS n
       FROM ai_call_log
      WHERE organization_id = $1 AND school_id IS NOT DISTINCT FROM $2
        AND created_at >= $3
        AND ${RATE_WINDOW_OUTCOME_FILTER}`,
    [scope.organizationId, scope.schoolId, sinceIso],
  );
  return Number(rows[0]?.n ?? 0);
}

/** Sum this school's estimated spend (micro-USD) in [sinceIso, now) — the
 * monthly spend-cap accumulator. Only real provider calls carry cost. */
export async function sumSchoolCostMicrosSince(
  db: TenantQueryClient,
  scope: AiTenantScope,
  sinceIso: string,
): Promise<number> {
  const rows = await db.queryObject<{ total: string | number }>(
    `SELECT coalesce(sum(estimated_cost_micros), 0)::bigint AS total
       FROM ai_call_log
      WHERE organization_id = $1 AND school_id IS NOT DISTINCT FROM $2
        AND created_at >= $3`,
    [scope.organizationId, scope.schoolId, sinceIso],
  );
  return Number(rows[0]?.total ?? 0);
}
