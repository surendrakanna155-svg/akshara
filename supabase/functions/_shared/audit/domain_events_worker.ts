import type { TenantQueryClient } from "../tenant_db.ts";

const MAX_ATTEMPTS = 5;

function retryDelayMinutes(attempt: number): number {
  return Math.min(60, 2 ** Math.max(0, attempt - 1));
}

export async function publishPendingDomainEvents(
  db: TenantQueryClient,
  orgId: string,
  limit = 100,
): Promise<{ processed: number; published: number; failed: number; retried: number }> {
  const pending = await db.queryObject<{ id: string; attempt_count: number }>(
    `SELECT id::text, attempt_count FROM domain_events
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

  for (const row of pending) {
    const nextAttempt = row.attempt_count + 1;
    try {
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

  return { processed: pending.length, published, failed, retried };
}
