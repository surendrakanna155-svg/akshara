// Adaptive AI — P3-AI-1 / W1.4: the Signal Refinery (design doc 04 §2).
//
// The consumer the domain_events outbox never had: it maps each event to the
// entity tags whose cached generations must die (staleness rule, doc 03 §3.5)
// and to a Fact/Signal freshness record. Fully deterministic + idempotent —
// replaying the same events invalidates the same (already-gone) cache entries
// and re-upserts the same signal rows, so duplicates cause no drift.
//
// Scope note for W1: this delivers event→tag cache invalidation + idempotent
// signal freshness. Full materialized-rollup recomputation (real aging/at-risk
// numbers) and the nightly repair/pre-warm job ride the compute layer + XCT-2
// rail and land with the W2 wave that consumes them. The trigger (a cron/route
// calling runSignalRefinery) is deploy-time wiring, like the COM-4 cron.

import type { TenantQueryClient } from "../tenant_db.ts";
import type { AiTenantScope } from "./ai_call_log_repository.ts";
import { invalidateCacheByEntityTags } from "./ai_response_cache_repository.ts";
import { type FactSignalUpsert, upsertFactSignal } from "./ai_fact_signals_repository.ts";

export type EventFamily = "fees" | "attendance" | "exams" | "approvals";

export interface RefineryEvent {
  eventType: string;
  payload: Record<string, unknown>;
}

export interface RefineryResult {
  processed: number;
  cacheEntriesInvalidated: number;
  signalsTouched: number;
}

/** Classify an event_type into the cache/signal family it affects (or null). */
export function eventFamily(eventType: string): EventFamily | null {
  const t = eventType.toLowerCase();
  if (/(fee|payment|collection|invoice|concession|refund|scholarship)/.test(t)) return "fees";
  if (/attendance/.test(t)) return "attendance";
  if (/(exam|marks|result|grade)/.test(t)) return "exams";
  if (/approval/.test(t)) return "approvals";
  return null;
}

function studentIdOf(payload: Record<string, unknown>): string | null {
  const v = payload["student_id"] ?? payload["studentId"] ?? null;
  return typeof v === "string" && v.length > 0 ? v : null;
}

/** Entity tags whose cached generations depend on this event (doc 03 §3.5). */
export function eventToEntityTags(
  eventType: string,
  payload: Record<string, unknown>,
): string[] {
  const family = eventFamily(eventType);
  if (!family) return [];
  const tags = [`school:${family}`];
  const sid = studentIdOf(payload);
  if (sid) tags.push(`student:${sid}:${family}`);
  return tags;
}

/** The Fact/Signal freshness record to refresh for this event (or null). */
export function eventToSignal(
  eventType: string,
  payload: Record<string, unknown>,
): FactSignalUpsert | null {
  const family = eventFamily(eventType);
  if (!family) return null;
  const sid = studentIdOf(payload);
  return {
    signalType: `${family}_activity`,
    scopeKey: sid ? `student:${sid}` : "school",
    payload: { lastEventType: eventType, source: "signal_refinery" },
  };
}

export interface RefineryDeps {
  invalidate: (tags: string[]) => Promise<number>;
  touchSignal: (signal: FactSignalUpsert) => Promise<void>;
}

/** Testable core: derive tags + signals per event and apply them via deps. */
export async function refineEvents(
  events: RefineryEvent[],
  deps: RefineryDeps,
): Promise<RefineryResult> {
  let cacheEntriesInvalidated = 0;
  let signalsTouched = 0;
  for (const ev of events) {
    const payload = ev.payload ?? {};
    const tags = eventToEntityTags(ev.eventType, payload);
    if (tags.length > 0) {
      cacheEntriesInvalidated += await deps.invalidate(tags);
    }
    const signal = eventToSignal(ev.eventType, payload);
    if (signal) {
      await deps.touchSignal(signal);
      signalsTouched++;
    }
  }
  return { processed: events.length, cacheEntriesInvalidated, signalsTouched };
}

/** Production entry point: read a recent batch of tenant events and refine them.
 * Idempotent, so overlapping batches are safe. */
export async function runSignalRefinery(
  db: TenantQueryClient,
  scope: AiTenantScope,
  opts?: { limit?: number },
): Promise<RefineryResult> {
  const limit = Math.max(1, Math.trunc(opts?.limit ?? 200));
  const rows = await db.queryObject<{ event_type: string; payload: Record<string, unknown> }>(
    `SELECT event_type, payload
       FROM domain_events
      WHERE organization_id = $1 AND school_id = $2
      ORDER BY created_at DESC
      LIMIT $3`,
    [scope.organizationId, scope.schoolId, limit],
  );
  const events: RefineryEvent[] = rows.map((r) => ({
    eventType: r.event_type,
    payload: r.payload ?? {},
  }));
  return refineEvents(events, {
    invalidate: (tags) => invalidateCacheByEntityTags(db, scope, tags),
    touchSignal: (signal) => upsertFactSignal(db, scope, signal),
  });
}
