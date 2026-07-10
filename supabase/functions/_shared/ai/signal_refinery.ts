// Adaptive AI — P3-AI-1 / W1.4: the Signal Refinery (design doc 04 §2).
//
// The consumer the domain_events outbox never had: it maps each event to the
// entity tags whose cached generations must die (staleness rule, doc 03 §3.5)
// and to a Fact/Signal freshness record. Fully deterministic + idempotent —
// replaying the same events invalidates the same (already-gone) cache entries
// and re-upserts the same signal rows, so duplicates cause no drift.
//
// Wiring (W1-completion F2): runSignalRefinery is invoked per school from the
// domain_events drain (handleProcessDomainEvents), each school in its own
// tenant transaction so cache/signal writes run under the required school RLS
// scope and one school's failure never touches another's or the publish. A
// per-school watermark (a reserved ai_fact_signals row) makes it consume only
// NEW events in created_at order with no re-processing storms and no coverage
// loss under load, and each event is applied inside a SAVEPOINT so a single bad
// event is skipped, not head-of-line-blocking. Full materialized-rollup
// recompute (real aging/at-risk numbers) rides the compute layer + XCT-2 rail
// with the W2 surfaces that read them; this W1 layer keeps caches fresh + marks
// signal recency.

import type { TenantQueryClient } from "../tenant_db.ts";
import type { AiTenantScope } from "./ai_call_log_repository.ts";
import { invalidateCacheByEntityTags } from "./ai_response_cache_repository.ts";
import {
  type FactSignalUpsert,
  getFactSignal,
  upsertFactSignal,
} from "./ai_fact_signals_repository.ts";

export type EventFamily =
  | "fees"
  | "attendance"
  | "exams"
  | "approvals"
  | "homework"
  | "library"
  | "inventory"
  | "transport"
  | "admissions";

export interface RefineryEvent {
  eventType: string;
  payload: Record<string, unknown>;
}

export interface RefineryResult {
  processed: number;
  cacheEntriesInvalidated: number;
  signalsTouched: number;
  /** Events whose application errored and were skipped (savepoint rolled back). */
  skipped: number;
}

/** Classify an event_type into the cache/signal family it affects (or null).
 * Module-prefixed families are matched FIRST so `transport.attendance.*` and
 * `staff_attendance.*` (bus / biometric-HR) never fall into the academic
 * `attendance` family (audit F19 misclassification fix). */
export function eventFamily(eventType: string): EventFamily | null {
  const t = eventType.toLowerCase();
  // Biometric HR attendance is not academic class attendance — carries no
  // academic cache/signal dependency here.
  if (t.startsWith("staff_attendance.")) return null;
  if (t.startsWith("transport.")) return "transport";
  if (t.startsWith("library.")) return "library";
  if (t.startsWith("inventory.")) return "inventory";
  if (t.startsWith("admissions.")) return "admissions";
  if (/homework/.test(t)) return "homework";
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

/** Testable core: derive tags + signals per event and apply them via deps.
 * Deterministic + idempotent; errors propagate (the production path isolates
 * each event in a SAVEPOINT — see runSignalRefinery). */
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
  return { processed: events.length, cacheEntriesInvalidated, signalsTouched, skipped: 0 };
}

// Per-school consumption watermark, stored as a reserved ai_fact_signals row
// (no new table): {lastCreatedAt} of the newest event this school has refined.
const CURSOR_SIGNAL = "_refinery_cursor";
const CURSOR_SCOPE = "_cursor";

async function readCursor(db: TenantQueryClient, scope: AiTenantScope): Promise<string | null> {
  const row = await getFactSignal(db, scope, CURSOR_SIGNAL, CURSOR_SCOPE);
  const v = row?.payload?.["lastCreatedAt"];
  return typeof v === "string" && v.length > 0 ? v : null;
}

/** Advance the watermark MONOTONICALLY: the ON CONFLICT update only fires when
 * the stored cursor is strictly older, so two overlapping drains for the same
 * school can never REGRESS the watermark (H5). ISO-8601 UTC strings compare
 * chronologically as text. */
async function writeCursor(
  db: TenantQueryClient,
  scope: AiTenantScope,
  lastCreatedAt: string,
): Promise<void> {
  await db.queryObject(
    `INSERT INTO ai_fact_signals (
       organization_id, school_id, signal_type, scope_key, payload, computed_at
     ) VALUES ($1,$2,$3,$4,$5::jsonb, timezone('utc', now()))
     ON CONFLICT (organization_id, school_id, signal_type, scope_key) DO UPDATE SET
       payload = EXCLUDED.payload,
       computed_at = timezone('utc', now())
     WHERE (ai_fact_signals.payload->>'lastCreatedAt')
             < (EXCLUDED.payload->>'lastCreatedAt')`,
    [
      scope.organizationId,
      scope.schoolId,
      CURSOR_SIGNAL,
      CURSOR_SCOPE,
      JSON.stringify({ lastCreatedAt }),
    ],
  );
}

/**
 * Production entry point (must run under the SCHOOL RLS scope of `scope`).
 * Consumes this school's domain_events newer than the watermark, in created_at
 * order, invalidating tagged caches + refreshing signal recency, then advances
 * the watermark. Each event applies inside a SAVEPOINT so one bad event is
 * skipped (not head-of-line-blocking); idempotent, so an interrupted run simply
 * re-consumes from the un-advanced watermark next time.
 */
export async function runSignalRefinery(
  db: TenantQueryClient,
  scope: AiTenantScope,
  opts?: { limit?: number },
): Promise<RefineryResult> {
  const limit = Math.min(5000, Math.max(1, Math.trunc(opts?.limit ?? 500)));
  const cursor = await readCursor(db, scope);
  const rows = await db.queryObject<
    { event_type: string; payload: Record<string, unknown>; created_at: string }
  >(
    `SELECT event_type, payload, created_at
       FROM domain_events
      WHERE organization_id = $1 AND school_id = $2
        AND ($3::timestamptz IS NULL OR created_at > $3::timestamptz)
        AND event_type <> $4
      ORDER BY created_at ASC
      LIMIT $5`,
    [scope.organizationId, scope.schoolId, cursor, CURSOR_SIGNAL, limit],
  );
  if (rows.length === 0) {
    return { processed: 0, cacheEntriesInvalidated: 0, signalsTouched: 0, skipped: 0 };
  }

  let cacheEntriesInvalidated = 0;
  let signalsTouched = 0;
  let skipped = 0;
  // Advance only over the CONTIGUOUS successfully-processed prefix (H5): a
  // (usually transient) per-event error stops advancement so that event and
  // everything after it is re-consumed next run — idempotently — instead of
  // being silently passed forever (the W1 layer has no nightly recompute yet).
  let cursorAdvance: string | null = cursor;
  let contiguous = true;
  let i = 0;
  for (const r of rows) {
    const sp = `sr_${i++}`;
    await db.queryObject(`SAVEPOINT ${sp}`);
    try {
      const payload = r.payload ?? {};
      const tags = eventToEntityTags(r.event_type, payload);
      if (tags.length > 0) {
        cacheEntriesInvalidated += await invalidateCacheByEntityTags(db, scope, tags);
      }
      const signal = eventToSignal(r.event_type, payload);
      if (signal) {
        await upsertFactSignal(db, scope, signal);
        signalsTouched++;
      }
      await db.queryObject(`RELEASE SAVEPOINT ${sp}`);
      // Normalize to ISO-8601 UTC (deno-postgres returns timestamptz as a Date)
      // so the watermark stored + compared everywhere is one consistent format.
      if (contiguous) cursorAdvance = new Date(r.created_at).toISOString();
    } catch {
      // Un-poison the transaction and skip only this event (audit F19).
      await db.queryObject(`ROLLBACK TO SAVEPOINT ${sp}`);
      skipped++;
      contiguous = false;
    }
  }

  if (cursorAdvance && cursorAdvance !== cursor) {
    await writeCursor(db, scope, cursorAdvance);
  }
  return { processed: rows.length, cacheEntriesInvalidated, signalsTouched, skipped };
}
