-- ICA-D3 (P2, Engineering/Operational) — bounded retention for
-- `request_idempotency`.
--
-- The store-and-replay idempotency table (created in
-- 20260814000000_red_team_wave1_transactional_integrity.sql) grows one row per
-- distinct Idempotency-Key and is NEVER trimmed: the app-layer store only ever
-- DELETEs a single key's own NULL-payload row on a non-2xx `release()`
-- (idempotency_dispatch.ts). So today the table has (a) UNBOUNDED growth of
-- COMPLETED rows that are retained forever even though a client's offline-replay
-- retry window is finite, and (b) ORPHAN in-flight rows — a row is claimed
-- (response_payload IS NULL) but the edge invocation crashes after the claim and
-- before `store()`/`release()`, leaving a NULL-payload row that nothing ever
-- cleans up and that would 409 any future retry of that key. ICA-A4 adds the
-- client-facing TTL / re-claim staleness in idempotency_dispatch.ts; this
-- migration is its co-requisite server-side reaper that reclaims the storage.
--
-- Retention thresholds (defaults, overridable per call):
--   * COMPLETED rows (response_payload IS NOT NULL): 7 days. The table backs
--     "a write queued offline and replayed on reconnect" (idempotency_dispatch.ts
--     §design 8.1). 7 days is a generous offline-replay horizon for a mobile
--     client that was disconnected for up to a week; a retry arriving after that
--     is beyond any realistic offline window and re-syncs fresh instead of
--     replaying. The horizon is anchored on `created_at` — the instant the CLIENT
--     first made the request, which is exactly what the client's own retry clock
--     measures from — so a retry within 7 days of the original POST still replays.
--     (created_at is within the sub-second/seconds edge-request lifetime of
--     completed_at, so anchoring on created_at is equivalent to, and marginally
--     more conservative than, anchoring on completion, and lets a single
--     created_at index serve the whole delete predicate.)
--   * ORPHAN in-flight rows (response_payload IS NULL): 1 hour. An in-flight row
--     exists only between `claim()` and `store()`/`release()`; edge invocations
--     are bounded to seconds, so a NULL-payload row older than an hour is
--     definitively orphaned and can be reaped with zero risk of racing a live
--     request. This is deliberately conservative and comfortably exceeds any sane
--     ICA-A4 re-claim staleness window (the in-flight TTL must stay >= A4's
--     re-claim window; 1h leaves ample headroom).
--
-- SCHEDULING — how this runs (verified against the repo, 2026-07-21):
--   There is NO pg_cron extension in this database (no `cron.schedule` /
--   `CREATE EXTENSION pg_cron` in any migration; the only mention is a comment in
--   communication_service.ts). The established precedent for a DATA-RETENTION
--   purge is DB-6 audit retention (audit_repository.ts), which is explicit: a
--   retention delete "is enforced by an ops-lane purge ... under a privileged
--   role — never a client-reachable delete path." That rule is doubly binding
--   here: `request_idempotency` is FORCE ROW LEVEL SECURITY with a school-scope
--   policy, so a cross-tenant reaper CANNOT run from any tenant (`erp_tenant`)
--   path and MUST run under an RLS-bypassing privileged role. Tenant-fanned
--   scheduled jobs in this repo (e.g. run-scheduled broadcasts) use an internal
--   cron-token HTTP endpoint hit by VPS cron, but that path is per-tenant and
--   client-reachable, which is exactly what a global retention purge must NOT be.
--   Therefore this ships as a callable, privileged SQL function — NOT a new HTTP
--   endpoint and NOT a new scheduler.
--
--   OPS / DEPLOY STEP (required to actually bound growth): schedule a periodic
--   invocation under the privileged DB role, on the existing ops-cron lane
--   (deploy/akshara-vps/backup/install-ops-cron.sh already runs `docker exec
--   <pg> psql`/pg_dump against the tenant DB). Recommended cadence: hourly, e.g.
--     docker exec <akshara-postgres> psql -U <admin> -d <db> \
--       -c "SELECT reap_request_idempotency();"
--   If pg_cron is ever enabled on this database, this same function can instead be
--   registered with cron.schedule(); no code change is required either way.
--
-- Additive + idempotent (CREATE OR REPLACE FUNCTION, CREATE INDEX IF NOT EXISTS).

-- Supporting index for the reaper's time-bounded DELETE predicate. Keeps each
-- sweep cheap (and the very first sweep, against any accumulated backlog,
-- bounded) instead of a full sequential scan.
CREATE INDEX IF NOT EXISTS idx_request_idempotency_created_at
  ON request_idempotency (created_at);

-- Bounded-retention reaper. Returns the number of rows deleted (for ops logging).
--
-- SECURITY DEFINER + SET search_path = public, mirroring the ICA-B3 posture
-- (20260920000110): owned by the privileged migration role (BYPASSRLS), it
-- reaps across ALL tenants despite the table's FORCE RLS school-scope policy.
-- EXECUTE is revoked from PUBLIC so this cross-tenant delete is NEVER reachable
-- from the `erp_tenant` edge role — only the privileged ops invoker may run it,
-- exactly as the DB-6 audit-retention seam requires.
CREATE OR REPLACE FUNCTION reap_request_idempotency(
  p_completed_ttl INTERVAL DEFAULT INTERVAL '7 days',
  p_inflight_ttl  INTERVAL DEFAULT INTERVAL '1 hour'
) RETURNS BIGINT
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_now     TIMESTAMPTZ := timezone('utc', now());
  v_deleted BIGINT;
BEGIN
  DELETE FROM request_idempotency
  WHERE
    -- (a) COMPLETED rows past the client offline-replay horizon.
    (response_payload IS NOT NULL AND created_at < v_now - p_completed_ttl)
    OR
    -- (b) ORPHAN in-flight rows: claimed but never completed/released.
    (response_payload IS NULL AND created_at < v_now - p_inflight_ttl);

  GET DIAGNOSTICS v_deleted = ROW_COUNT;
  RETURN v_deleted;
END;
$$;

-- Cross-tenant retention purge: privileged ops role only, never the tenant edge.
REVOKE ALL ON FUNCTION reap_request_idempotency(INTERVAL, INTERVAL) FROM PUBLIC;
