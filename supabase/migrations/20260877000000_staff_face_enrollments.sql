-- P1-PROD-22 SLICE 1 — Staff Face ID: server-authoritative enrollment backend.
-- docs/ATTENDANCE_AUTH_DESIGN_DECISION.md (FINAL) §2-4, §7: attendance auth for
-- Teachers & Staff is GPS geofence -> anti-mock location -> live camera face,
-- NEVER device biometric. §7 (owner decision): each staff member enrols a
-- reference face EMBEDDING (a float vector, never a raw image) — stored per
-- (org, school, user), replaceable, ONE active enrollment at a time. Matching is
-- SERVER-AUTHORITATIVE: the client sends a live embedding, the server computes
-- cosine similarity and decides pass/fail (the client can never assert
-- matched=true).
--
-- staff_face_enrollments ALREADY EXISTS (migration 20260820, the B4 check-in
-- re-implementation) as a minimal self-only shape: TEXT id, JSONB embedding, a
-- boolean `active` flag, RLS pinned to user_id = app_current_user_id() (a staff
-- member could only ever enrol/read/replace their OWN face). This migration
-- EVOLVES that table (ALTER, not CREATE — the table already has a live
-- consumer, staff_check_in_repository.ts, updated in the same change to the
-- renamed columns) to the governed SLICE 1 shape:
--   * embedding stored as a plain REAL[] float array — pgvector is unprovisioned
--     and unnecessary here (~192 dims; an app-side cosine compare in
--     face_match.ts is fine).
--   * a `status` lifecycle ('active' | 'revoked') replaces the boolean `active`
--     flag: revocation is an UPDATE, never a DELETE, so a revoked enrollment
--     stays in the table as an audit record (no DELETE grant).
--   * `model_tag` records which client model produced the embedding;
--     `enrolled_by` / `revoked_by` record the ACTING user — distinct from
--     `user_id`, the enrollment's OWNER, because this slice adds an
--     HR-managed enrollment/revocation of someone else's reference face.
--   * RLS widens from self-only to the standard org+school wall (mirrors
--     intel_student_risk_snapshots, migration 20260621): an HR-managed write
--     for ANOTHER user in the same school is now possible at the RLS layer; the
--     self-vs-other identity decision is enforced at the application layer (the
--     manageHr permission gate), exactly like every other manageHr-gated write
--     in this codebase — RLS is a tenant/school wall, not an identity check.
--
-- The `id` column keeps its existing TEXT / composite-PK shape (unrelated to
-- this redesign; changing a live PK type is unjustified churn) and the sibling
-- staff_attendance tables (staff_check_ins, staff_attendance_requests,
-- school_attendance_geofences) are UNTOUCHED — this migration owns exactly one
-- table. The check-in verification CHAIN (geofence -> anti-mock -> liveness ->
-- match -> check-in) is SLICE 2 and is NOT touched here; face_match.ts is
-- exported for it.

-- 1. New lifecycle + audit columns (additive) -----------------------------------------
ALTER TABLE staff_face_enrollments
  ADD COLUMN IF NOT EXISTS model_tag TEXT NOT NULL DEFAULT '',
  ADD COLUMN IF NOT EXISTS status TEXT,
  ADD COLUMN IF NOT EXISTS enrolled_by UUID,
  ADD COLUMN IF NOT EXISTS revoked_by UUID,
  ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),
  ADD COLUMN IF NOT EXISTS revoked_at TIMESTAMPTZ;

-- Backfill status from the legacy boolean, then lock it down.
UPDATE staff_face_enrollments
   SET status = CASE WHEN active THEN 'active' ELSE 'revoked' END
 WHERE status IS NULL;

ALTER TABLE staff_face_enrollments
  ALTER COLUMN status SET DEFAULT 'active',
  ALTER COLUMN status SET NOT NULL;

ALTER TABLE staff_face_enrollments
  ADD CONSTRAINT staff_face_enrollments_status_check CHECK (status IN ('active', 'revoked'));

-- 2. One ACTIVE enrollment per (org, school, user) — rebuild the partial unique
--    index against `status` BEFORE dropping `active` (the old index's predicate
--    depends on that column). ------------------------------------------------------
DROP INDEX IF EXISTS idx_staff_face_active;

-- Legacy boolean superseded by `status` — its sole consumer
-- (staff_check_in_repository.ts) is updated in this same change.
ALTER TABLE staff_face_enrollments DROP COLUMN IF EXISTS active;

CREATE UNIQUE INDEX idx_staff_face_active
  ON staff_face_enrollments (organization_id, school_id, user_id)
  WHERE status = 'active';

-- 3. embedding: JSONB -> plain REAL[] (privacy-preserving float vector, no pgvector) ---
-- Postgres forbids subqueries in an ALTER..USING transform expression
-- ("cannot use subquery in transform expression" — verified live on the dev
-- DB), so the conversion goes through a temporary IMMUTABLE helper whose
-- body may use one; dropped immediately after.
CREATE FUNCTION _mig_jsonb_to_real_array(v JSONB) RETURNS REAL[]
  LANGUAGE sql IMMUTABLE AS
  $fn$ SELECT ARRAY(SELECT jsonb_array_elements_text(v)::real) $fn$;

ALTER TABLE staff_face_enrollments
  ALTER COLUMN embedding TYPE REAL[]
  USING _mig_jsonb_to_real_array(embedding);

DROP FUNCTION _mig_jsonb_to_real_array(JSONB);

-- embedding_dim -> embedding_dims (naming) + tightened bounds (64..1024).
ALTER TABLE staff_face_enrollments RENAME COLUMN embedding_dim TO embedding_dims;
ALTER TABLE staff_face_enrollments DROP CONSTRAINT IF EXISTS face_enrollment_dim_check;
ALTER TABLE staff_face_enrollments
  ADD CONSTRAINT face_enrollment_dim_check CHECK (embedding_dims BETWEEN 64 AND 1024);

-- enrolled_at -> created_at (matches the created_at/updated_at convention used
-- everywhere else in this codebase).
ALTER TABLE staff_face_enrollments RENAME COLUMN enrolled_at TO created_at;

-- 4. RLS: self-only -> standard org+school wall ----------------------------------------
DROP POLICY IF EXISTS face_enroll_self_insert ON staff_face_enrollments;
DROP POLICY IF EXISTS face_enroll_self_update ON staff_face_enrollments;
DROP POLICY IF EXISTS face_enroll_self_read ON staff_face_enrollments;

CREATE POLICY staff_face_enrollments_school_scope ON staff_face_enrollments
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

-- Reaffirmed defensively (already set by 20260820; harmless if replayed against
-- a divergent base).
ALTER TABLE staff_face_enrollments ENABLE ROW LEVEL SECURITY;
ALTER TABLE staff_face_enrollments FORCE ROW LEVEL SECURITY;

-- Revocation is an UPDATE (status -> 'revoked'); no DELETE grant — the row stays
-- as an audit record.
GRANT SELECT, INSERT, UPDATE ON staff_face_enrollments TO erp_tenant;
