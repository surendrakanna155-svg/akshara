// Adaptive AI — P3-AI-1 / W1.4: Fact/Signal Memory repository (design doc 03 §2.4).
//
// Materialized, per-scope signal rows kept fresh by the Signal Refinery. Writes
// are idempotent (upsert on the natural key) so replayed/duplicate domain events
// cause no drift. Org+school RLS (migration 20260868) forces tenant isolation.

import type { TenantQueryClient } from "../tenant_db.ts";
import type { AiTenantScope } from "./ai_call_log_repository.ts";

export interface FactSignal {
  signalType: string;
  scopeKey: string;
  payload: Record<string, unknown>;
  computedAt: string;
}

export interface FactSignalUpsert {
  signalType: string;
  scopeKey: string;
  payload: Record<string, unknown>;
}

/** Idempotent upsert on (org, school, signal_type, scope_key): re-applying the
 * same event leaves the same end state (refreshes payload + computed_at). */
export async function upsertFactSignal(
  db: TenantQueryClient,
  scope: AiTenantScope,
  signal: FactSignalUpsert,
): Promise<void> {
  await db.queryObject(
    `INSERT INTO ai_fact_signals (
       organization_id, school_id, signal_type, scope_key, payload, computed_at
     ) VALUES ($1,$2,$3,$4,$5::jsonb, timezone('utc', now()))
     ON CONFLICT (organization_id, school_id, signal_type, scope_key) DO UPDATE SET
       payload = EXCLUDED.payload,
       computed_at = timezone('utc', now())`,
    [
      scope.organizationId,
      scope.schoolId,
      signal.signalType,
      signal.scopeKey,
      JSON.stringify(signal.payload ?? {}),
    ],
  );
}

export async function getFactSignal(
  db: TenantQueryClient,
  scope: AiTenantScope,
  signalType: string,
  scopeKey: string,
): Promise<FactSignal | null> {
  const rows = await db.queryObject<{
    signal_type: string;
    scope_key: string;
    payload: Record<string, unknown>;
    computed_at: string;
  }>(
    `SELECT signal_type, scope_key, payload, computed_at
       FROM ai_fact_signals
      WHERE organization_id = $1 AND school_id = $2
        AND signal_type = $3 AND scope_key = $4
      LIMIT 1`,
    [scope.organizationId, scope.schoolId, signalType, scopeKey],
  );
  const row = rows[0];
  if (!row) return null;
  return {
    signalType: row.signal_type,
    scopeKey: row.scope_key,
    payload: row.payload ?? {},
    computedAt: row.computed_at,
  };
}
