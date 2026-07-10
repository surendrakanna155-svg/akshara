// Adaptive AI — P3-AI-1 / W1.5: AI economics (the N10 cost panel data).
//
// Aggregates per-tenant AI usage from ai_call_log (spend, calls by outcome +
// surface) and ai_response_cache (hit ratio, tokens saved) for the current
// calendar month, plus the effective monthly spend cap. Pure computeEconomics
// is unit-tested; getAiEconomics wires the queries. School-scoped by RLS.

import type { TenantQueryClient } from "../tenant_db.ts";
import type { AiTenantScope } from "./ai_call_log_repository.ts";
import { resolveAiConfig } from "./ai_settings.ts";
import { resolveLimits } from "./model_gateway.ts";

/** Operators are warned once month-to-date spend reaches this fraction of the
 * cap (design doc 03 §4: 80% warn / 100% soft-degrade). */
export const SPEND_WARN_RATIO = 0.8;

export interface AiEconomics {
  monthStart: string;
  /** Month-to-date estimated spend (micro-USD). */
  spendMicros: number;
  spendCapMicros: number;
  /** The warn threshold as a fraction of the cap (0.8). */
  spendWarnRatio: number;
  /** True when a cap is set and month-to-date spend ≥ 80% of it (F8). */
  atSpendWarn: boolean;
  /** True when a cap is set and month-to-date spend ≥ 100% (T3 soft-degraded). */
  atSpendCap: boolean;
  modelCalls: number; // month-to-date real provider calls (ok + refused)
  fallbacks: number; // month-to-date governed fallbacks (no-key/limit/timeout/error/guard)
  callsByOutcome: Record<string, number>; // month-to-date
  callsBySurface: Record<string, number>; // month-to-date
  /** Live (non-expired) cache rows. */
  cacheEntries: number;
  /** Lifetime cache hits (hit_count is cumulative). */
  cacheHits: number;
  /** Lifetime tokens saved by reuse = Σ(tokens_saved × hit_count) (F6). */
  tokensSaved: number;
  /** Lifetime hits / (lifetime hits + lifetime model calls) — both windows
   * consistent (F6); 0 when there is no activity yet. */
  cacheHitRatio: number;
}

export interface OutcomeRow {
  outcome: string;
  n: number;
  cost: number;
}
export interface SurfaceRow {
  surface: string;
  n: number;
}
export interface CacheAgg {
  entries: number;
  hits: number;
  tokensSaved: number;
}

const REAL_CALL_OUTCOMES = new Set(["ok", "refused"]);

/** Pure aggregation → the panel's numbers. `lifetimeModelCalls` is the all-time
 * ok+refused count used only for the (window-consistent) cache-hit ratio. */
export function computeEconomics(
  monthStart: string,
  outcomes: OutcomeRow[],
  surfaces: SurfaceRow[],
  cache: CacheAgg,
  spendCapMicros: number,
  lifetimeModelCalls: number,
): AiEconomics {
  let spendMicros = 0;
  let modelCalls = 0;
  let fallbacks = 0;
  const callsByOutcome: Record<string, number> = {};
  for (const row of outcomes) {
    spendMicros += row.cost;
    callsByOutcome[row.outcome] = row.n;
    if (REAL_CALL_OUTCOMES.has(row.outcome)) modelCalls += row.n;
    else fallbacks += row.n;
  }
  const callsBySurface: Record<string, number> = {};
  for (const row of surfaces) callsBySurface[row.surface] = row.n;

  const denom = cache.hits + lifetimeModelCalls;
  const cacheHitRatio = denom > 0 ? cache.hits / denom : 0;
  const capped = spendCapMicros > 0;

  return {
    monthStart,
    spendMicros,
    spendCapMicros,
    spendWarnRatio: SPEND_WARN_RATIO,
    atSpendWarn: capped && spendMicros >= SPEND_WARN_RATIO * spendCapMicros,
    atSpendCap: capped && spendMicros >= spendCapMicros,
    modelCalls,
    fallbacks,
    callsByOutcome,
    callsBySurface,
    cacheEntries: cache.entries,
    cacheHits: cache.hits,
    tokensSaved: cache.tokensSaved,
    cacheHitRatio,
  };
}

function monthStartIso(now: Date): string {
  return new Date(Date.UTC(now.getUTCFullYear(), now.getUTCMonth(), 1)).toISOString();
}

export async function getAiEconomics(
  db: TenantQueryClient,
  scope: AiTenantScope,
  orgId?: string | null,
): Promise<AiEconomics> {
  const monthStart = monthStartIso(new Date());

  // school_id IS NOT DISTINCT FROM $2 so an org-scoped panel (schoolId=null)
  // sees org-scoped rows instead of silently nothing (F10).
  const outcomeRows = await db.queryObject<{ outcome: string; n: number; cost: string | number }>(
    `SELECT outcome, count(*)::int AS n, coalesce(sum(estimated_cost_micros), 0)::bigint AS cost
       FROM ai_call_log
      WHERE organization_id = $1 AND school_id IS NOT DISTINCT FROM $2 AND created_at >= $3
      GROUP BY outcome`,
    [scope.organizationId, scope.schoolId, monthStart],
  );
  const surfaceRows = await db.queryObject<{ surface: string; n: number }>(
    `SELECT surface, count(*)::int AS n
       FROM ai_call_log
      WHERE organization_id = $1 AND school_id IS NOT DISTINCT FROM $2 AND created_at >= $3
      GROUP BY surface`,
    [scope.organizationId, scope.schoolId, monthStart],
  );
  // Live (non-expired) cache only; tokens saved = per-entry output × times reused
  // (hit_count), the actual reuse savings — not the one-generation value (F6).
  const cacheRows = await db.queryObject<{ entries: number; hits: string | number; saved: string | number }>(
    `SELECT count(*)::int AS entries,
            coalesce(sum(hit_count), 0)::bigint AS hits,
            coalesce(sum(tokens_saved * hit_count), 0)::bigint AS saved
       FROM ai_response_cache
      WHERE organization_id = $1 AND school_id IS NOT DISTINCT FROM $2
        AND (expires_at IS NULL OR expires_at > timezone('utc', now()))`,
    [scope.organizationId, scope.schoolId],
  );
  // Lifetime model calls for a window-consistent cache-hit ratio (cache hits are
  // lifetime cumulative, so the denominator must be too) (F6).
  const lifetimeRows = await db.queryObject<{ n: number }>(
    `SELECT count(*)::int AS n
       FROM ai_call_log
      WHERE organization_id = $1 AND school_id IS NOT DISTINCT FROM $2
        AND outcome IN ('ok', 'refused')`,
    [scope.organizationId, scope.schoolId],
  );

  const cfg = await resolveAiConfig(db, orgId ?? scope.organizationId);
  const spendCapMicros = resolveLimits(cfg.rawConfig).monthlySpendCapMicros;

  const cache = cacheRows[0];
  return computeEconomics(
    monthStart,
    outcomeRows.map((r) => ({ outcome: r.outcome, n: Number(r.n), cost: Number(r.cost) })),
    surfaceRows.map((r) => ({ surface: r.surface, n: Number(r.n) })),
    {
      entries: Number(cache?.entries ?? 0),
      hits: Number(cache?.hits ?? 0),
      tokensSaved: Number(cache?.saved ?? 0),
    },
    spendCapMicros,
    Number(lifetimeRows[0]?.n ?? 0),
  );
}
