// Append-only telemetry for the AI Model Gateway (P3-AI-1 / W1.1).
//
// Persists one row per governed model call and exposes the trailing-window
// aggregates the gateway uses to enforce rate limits and the monthly spend cap.
// Every query is org+school scoped; RLS (see migration 20260867000000) forces
// the same scope again as defense-in-depth, so a caller can only ever read or
// write its own tenant's telemetry.

import type { TenantQueryClient } from "../tenant_db.ts";

/** The eight outcomes an attempted gateway call can record. */
export type AiCallOutcome =
  | "ok"
  | "refused"
  | "fallback_no_key"
  | "fallback_rate_user"
  | "fallback_rate_school"
  | "fallback_spend_cap"
  | "fallback_timeout"
  | "fallback_error";

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
}

export interface AiTenantScope {
  organizationId: string;
  /** Null for an org-scoped call; matched with IS NOT DISTINCT FROM. */
  schoolId: string | null;
}

/** Insert one telemetry row. Never throws into the caller's happy path — the
 * gateway wraps this so a logging failure can degrade to "unlogged" without
 * failing the user's request. */
export async function recordAiCall(
  db: TenantQueryClient,
  entry: AiCallLogEntry,
): Promise<void> {
  await db.queryObject(
    `INSERT INTO ai_call_log (
       organization_id, school_id, user_id, surface, provider, model, outcome,
       input_tokens, output_tokens, estimated_cost_micros, latency_ms,
       cache_written, fallback_used
     ) VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13)`,
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
        AND outcome <> 'fallback_no_key'`,
    [scope.organizationId, scope.schoolId, userId, sinceIso],
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
        AND outcome <> 'fallback_no_key'`,
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
