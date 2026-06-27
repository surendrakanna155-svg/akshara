-- Red Team Wave 1 — Transactional Integrity (duplicates & lost updates).
-- Source of truth: docs/RED_TEAM_MASTER_TRACKER.md (RT-01, RT-02, RT-07, RT-08).
--
-- This migration adds the DATABASE-level guarantees behind Wave 1. The matching
-- application-layer fixes (FOR UPDATE locks, idempotency replay, savepoint
-- retry-on-conflict, marks bounds) live in the edge functions; the constraints
-- here are the last line of defence so a race that slips past the app cannot
-- corrupt money, student identity, or grades.
--
-- RT-03/04/05/06 are code-only (existing PKs / unique constraints already
-- protect integrity); no schema change is required for them.

-- ─────────────────────────────────────────────────────────────────────────────
-- RT-01 (Critical) — Finance fee collection: double-payment / negative-outstanding.
--   The app now SELECT … FOR UPDATEs the invoice before the outstanding check and
--   honours an Idempotency-Key. This column + partial-unique index make a replayed
--   collection a DB-enforced no-op: a second write with the same key cannot create
--   a second collection row (it raises 23505, which the app maps to a replay/409).
-- ─────────────────────────────────────────────────────────────────────────────
ALTER TABLE finance_collections
  ADD COLUMN IF NOT EXISTS idempotency_key TEXT;

CREATE UNIQUE INDEX IF NOT EXISTS finance_collections_idempotency_key_uq
  ON finance_collections (organization_id, idempotency_key)
  WHERE idempotency_key IS NOT NULL;

-- ─────────────────────────────────────────────────────────────────────────────
-- RT-02 (Critical) — Student create: duplicate admission number splits a child's
--   marks/fees across two profiles. There was only UNIQUE(student_id); the
--   app-level SELECT-then-INSERT check is TOCTOU-racy. Enforce uniqueness of the
--   admission number per school at the DB. The pre-existing non-unique lookup
--   index is now redundant (the unique constraint provides the same index).
-- ─────────────────────────────────────────────────────────────────────────────
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'student_profiles_school_admission_unique'
  ) THEN
    ALTER TABLE student_profiles
      ADD CONSTRAINT student_profiles_school_admission_unique
      UNIQUE (school_id, admission_number);
  END IF;
END $$;

DROP INDEX IF EXISTS idx_student_profiles_school_admission;

-- ─────────────────────────────────────────────────────────────────────────────
-- RT-07 (Medium) — Generic entity-write framework ignored the (CORS-advertised)
--   Idempotency-Key, so a double-tapped POST duplicated everything. This table
--   backs a generic store-and-replay in `runWrite`: the first request with a key
--   claims the row, runs, and stores its response; a concurrent/repeated request
--   with the same key is serialized by the unique index and replays the stored
--   response instead of writing again. School-scoped under `erp_tenant` RLS.
-- ─────────────────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS request_idempotency (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id UUID NOT NULL REFERENCES organizations (id),
  school_id UUID NOT NULL REFERENCES schools (id),
  idempotency_key TEXT NOT NULL,
  method TEXT NOT NULL,
  path TEXT NOT NULL,
  status_code INTEGER,
  response_payload JSONB,
  created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),
  completed_at TIMESTAMPTZ,
  UNIQUE (organization_id, idempotency_key)
);

CREATE INDEX IF NOT EXISTS idx_request_idempotency_org_school
  ON request_idempotency (organization_id, school_id);

-- The live edge runs as the non-bypass `erp_tenant` role, which needs table
-- grants in addition to the RLS policy (mirrors the *_entities tables).
GRANT SELECT, INSERT, UPDATE, DELETE ON request_idempotency TO erp_tenant;

ALTER TABLE request_idempotency ENABLE ROW LEVEL SECURITY;
ALTER TABLE request_idempotency FORCE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS request_idempotency_school_scope ON request_idempotency;
CREATE POLICY request_idempotency_school_scope ON request_idempotency
  FOR ALL
  USING (
    organization_id = app_current_tenant_id()
    AND app_current_scope() = 'school'
    AND school_id = app_current_school_id()
  )
  WITH CHECK (
    organization_id = app_current_tenant_id()
    AND app_current_scope() = 'school'
    AND school_id = app_current_school_id()
  );

-- ─────────────────────────────────────────────────────────────────────────────
-- RT-08 (High) — Exam marks had no server/DB bound (only Number.isFinite), so a
--   client could persist marks > max_marks or negative, corrupting grades / %.
--   The handler now bounds 0 <= marks <= max_marks; this CHECK is the DB backstop.
--   NOT VALID: enforced for every INSERT/UPDATE going forward without failing the
--   migration on any legacy out-of-range row; new corrupt writes are rejected.
-- ─────────────────────────────────────────────────────────────────────────────
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'exam_mark_entries_marks_bounds'
  ) THEN
    ALTER TABLE exam_mark_entries
      ADD CONSTRAINT exam_mark_entries_marks_bounds
      CHECK (marks_obtained >= 0 AND marks_obtained <= max_marks) NOT VALID;
  END IF;
END $$;
