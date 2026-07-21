import type { TenantQueryClient } from "../tenant_db.ts";
import { type DomainEvent, dispatchDomainEvent } from "./domain_event_subscribers.ts";

const MAX_ATTEMPTS = 5;

function retryDelayMinutes(attempt: number): number {
  return Math.min(60, 2 ** Math.max(0, attempt - 1));
}

export async function publishPendingDomainEvents(
  db: TenantQueryClient,
  orgId: string,
  limit = 100,
): Promise<
  {
    processed: number;
    published: number;
    failed: number;
    retried: number;
    /** Distinct schools whose events were published — the Signal Refinery
     * (W1.4) refines exactly these after the drain commits. */
    schoolIds: string[];
  }
> {
  const pending = await db.queryObject<
    {
      id: string;
      attempt_count: number;
      school_id: string | null;
      event_type: string;
      payload: Record<string, unknown> | null;
      correlation_id: string | null;
      source_module: string;
      created_at: string;
    }
  >(
    `SELECT id::text, attempt_count, school_id::text,
            event_type, payload, correlation_id, source_module, created_at
     FROM domain_events
     WHERE organization_id = $1
       AND status IN ('pending', 'failed')
       AND (next_retry_at IS NULL OR next_retry_at <= timezone('utc', now()))
     ORDER BY created_at
     LIMIT $2`,
    [orgId, limit],
  );

  let published = 0;
  let failed = 0;
  let retried = 0;
  const schoolIds = new Set<string>();

  for (const row of pending) {
    const nextAttempt = row.attempt_count + 1;
    try {
      // Deliver to every registered in-process subscriber whose eventTypes
      // match BEFORE the terminal publish (ICA-G1 seam). At-least-once: if any
      // subscriber throws, the UPDATE below is skipped, so the event stays
      // pending/failed and the SAME event is redelivered on the next drain
      // (subscribers must be idempotent). With zero subscribers this is a no-op
      // and "published" honestly means "durably logged". A throw here for THIS
      // event does not block the loop — the next event is still processed.
      const event: DomainEvent = {
        id: row.id,
        organizationId: orgId,
        schoolId: row.school_id,
        eventType: row.event_type,
        payload: row.payload ?? {},
        correlationId: row.correlation_id,
        sourceModule: row.source_module,
        createdAt: new Date(row.created_at).toISOString(),
      };
      await dispatchDomainEvent(event, db);

      await db.queryObject(
        `UPDATE domain_events
         SET status = 'published',
             published_at = timezone('utc', now()),
             attempt_count = $2,
             next_retry_at = NULL,
             last_error = NULL
         WHERE id = $1::uuid AND status IN ('pending', 'failed')`,
        [row.id, nextAttempt],
      );
      published += 1;
      if (row.school_id) schoolIds.add(row.school_id);
    } catch (error) {
      const message = error instanceof Error ? error.message : "publish failed";
      if (nextAttempt >= MAX_ATTEMPTS) {
        await db.queryObject(
          `UPDATE domain_events
           SET status = 'failed', attempt_count = $2, last_error = $3
           WHERE id = $1::uuid`,
          [row.id, nextAttempt, message],
        );
        failed += 1;
      } else {
        await db.queryObject(
          `UPDATE domain_events
           SET status = 'pending',
               attempt_count = $2,
               last_error = $3,
               next_retry_at = timezone('utc', now()) + ($4 || ' minutes')::interval
           WHERE id = $1::uuid`,
          [row.id, nextAttempt, message, String(retryDelayMinutes(nextAttempt))],
        );
        retried += 1;
      }
    }
  }

  return { processed: pending.length, published, failed, retried, schoolIds: [...schoolIds] };
}
