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

export interface AiEconomics {
  monthStart: string;
  spendMicros: number;
  spendCapMicros: number;
  modelCalls: number; // real provider calls (ok + refused)
  fallbacks: number; // governed fallbacks (no-key/limit/timeout/error)
  callsByOutcome: Record<string, number>;
  callsBySurface: Record<string, number>;
  cacheEntries: number;
  cacheHits: number;
  tokensSaved: number;
  /** hits / (hits + model calls); 0 when there is no activity yet. */
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

/** Pure aggregation → the panel's numbers. */
export function computeEconomics(
  monthStart: string,
  outcomes: OutcomeRow[],
  surfaces: SurfaceRow[],
  cache: CacheAgg,
  spendCapMicros: number,
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

  const denom = cache.hits + modelCalls;
  const cacheHitRatio = denom > 0 ? cache.hits / denom : 0;

  return {
    monthStart,
    spendMicros,
    spendCapMicros,
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

  const outcomeRows = await db.queryObject<{ outcome: string; n: number; cost: string | number }>(
    `SELECT outcome, count(*)::int AS n, coalesce(sum(estimated_cost_micros), 0)::bigint AS cost
       FROM ai_call_log
      WHERE organization_id = $1 AND school_id = $2 AND created_at >= $3
      GROUP BY outcome`,
    [scope.organizationId, scope.schoolId, monthStart],
  );
  const surfaceRows = await db.queryObject<{ surface: string; n: number }>(
    `SELECT surface, count(*)::int AS n
       FROM ai_call_log
      WHERE organization_id = $1 AND school_id = $2 AND created_at >= $3
      GROUP BY surface`,
    [scope.organizationId, scope.schoolId, monthStart],
  );
  const cacheRows = await db.queryObject<{ entries: number; hits: string | number; saved: string | number }>(
    `SELECT count(*)::int AS entries,
            coalesce(sum(hit_count), 0)::bigint AS hits,
            coalesce(sum(tokens_saved), 0)::bigint AS saved
       FROM ai_response_cache
      WHERE organization_id = $1 AND school_id = $2`,
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
  );
}
