-- Ops backup ledger — durable record of every database backup + restore drill.
--
-- Batch 7 (2026-06-24). The live VPS had NO backups and no way to know whether
-- one ever ran. These two tables are the source of truth the backup tooling
-- writes to and the `/health/backup` endpoint reads from, so "is our data safe
-- right now?" becomes a queryable fact, not a guess:
--   * ops_backup_runs    — one row per nightly/manual dump (size, sha256, where
--                          it landed, whether it reached off-site, success/fail).
--   * ops_restore_drills — one row per automated restore test (a backup you have
--                          never restored is not a backup).
--
-- Security: these are PLATFORM/OPS tables, not tenant data — they carry no
-- school_id and must never be visible to a tenant token. RLS is ENABLED with NO
-- policy, so the only reachable paths are the superuser (supabase_admin, used by
-- the backup scripts via psql) and the service-role connection (used by the edge
-- health endpoint) — both of which bypass RLS. The PostgREST `authenticator`
-- role and every app role are denied by default.

-- ─── Backup runs ────────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS ops_backup_runs (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  kind            text NOT NULL DEFAULT 'nightly',   -- nightly | manual | weekly | monthly
  status          text NOT NULL DEFAULT 'running',   -- running | success | failed
  database_name   text NOT NULL,
  host            text,
  artifact_path   text,                              -- local path on the VPS
  artifact_bytes  bigint,
  sha256          text,
  encrypted       boolean NOT NULL DEFAULT false,
  offsite         boolean NOT NULL DEFAULT false,    -- copied off the box?
  offsite_location text,                             -- e.g. rclone remote:bucket/path
  duration_ms     bigint,
  error           text,
  started_at      timestamptz NOT NULL DEFAULT now(),
  finished_at     timestamptz,
  created_at      timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS ops_backup_runs_created_idx
  ON ops_backup_runs (created_at DESC);
CREATE INDEX IF NOT EXISTS ops_backup_runs_status_idx
  ON ops_backup_runs (status, created_at DESC);

ALTER TABLE ops_backup_runs ENABLE ROW LEVEL SECURITY;
-- No policy on purpose: superuser + service_role only (both bypass RLS).

-- ─── Restore drills ─────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS ops_restore_drills (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  status          text NOT NULL DEFAULT 'running',   -- running | success | failed
  host            text,
  source_artifact text,                              -- which backup file was restored
  target_db       text,                              -- throwaway db it was restored into
  tables_checked  integer,
  rows_sampled    bigint,
  mismatch        text,                              -- non-null => drill found a problem
  duration_ms     bigint,
  error           text,
  started_at      timestamptz NOT NULL DEFAULT now(),
  finished_at     timestamptz,
  created_at      timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS ops_restore_drills_created_idx
  ON ops_restore_drills (created_at DESC);

ALTER TABLE ops_restore_drills ENABLE ROW LEVEL SECURITY;
-- No policy on purpose: superuser + service_role only (both bypass RLS).
