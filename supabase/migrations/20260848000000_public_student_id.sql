-- Akshara Identity Platform — Public Student ID (PSID).
--
-- Owner-approved (2026-07-03, identity cluster). PSID is a SEPARATE, permanent,
-- human-facing public identifier for a student. Format:
--
--     <SCHOOL_CODE>-<RUNNING_NUMBER>
--
-- where RUNNING_NUMBER is a 4-digit zero-padded, PER-SCHOOL sequential value that
-- is NEVER reused (e.g. DPSKKP-0001). SCHOOL_CODE is the existing schools.code
-- column. The UUID student_profiles.id stays the ONLY primary key; PSID does NOT
-- replace admission_number. PSID is set ONCE at profile creation and is IMMUTABLE
-- thereafter (mirrors the admission_number set-once rule, 20260847000000).
--
-- This migration:
--   1. Adds student_profiles.public_student_id + a partial-unique index (global
--      uniqueness; partial so pre-backfill NULLs are allowed).
--   2. Creates school_public_id_counters — the per-school never-reused sequence
--      source, school-scope RLS + erp_tenant DML grants.
--   3. Backfills existing profiles idempotently, ordered by created_at then id,
--      and advances each school's counter past the highest assigned number.
--   4. Installs a BEFORE UPDATE immutability trigger (PSID never changes once set).
--
-- Idempotent: ADD COLUMN IF NOT EXISTS, CREATE ... IF NOT EXISTS, ON CONFLICT
-- guards, and a backfill that only touches rows still NULL — re-applying assigns
-- nothing new.

-- ─── 1. PSID column + global partial-unique index ────────────────────────────

ALTER TABLE student_profiles
  ADD COLUMN IF NOT EXISTS public_student_id TEXT;

-- Globally unique (schools.code is unique per org, RUNNING_NUMBER is per-school
-- sequential, so <code>-<seq> is unique across the platform). Partial so many
-- rows may legitimately be NULL before/around backfill (e.g. schools with no
-- code yet).
CREATE UNIQUE INDEX IF NOT EXISTS uq_student_profiles_public_student_id
  ON student_profiles (public_student_id)
  WHERE public_student_id IS NOT NULL;

-- ─── 2. Per-school never-reused counter ──────────────────────────────────────

CREATE TABLE IF NOT EXISTS school_public_id_counters (
  organization_id UUID NOT NULL REFERENCES organizations (id),
  school_id UUID NOT NULL REFERENCES schools (id),
  next_seq INTEGER NOT NULL DEFAULT 1,
  created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),
  PRIMARY KEY (organization_id, school_id)
);

DROP TRIGGER IF EXISTS school_public_id_counters_updated_at ON school_public_id_counters;
CREATE TRIGGER school_public_id_counters_updated_at
  BEFORE UPDATE ON school_public_id_counters
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

ALTER TABLE school_public_id_counters ENABLE ROW LEVEL SECURITY;
ALTER TABLE school_public_id_counters FORCE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS school_public_id_counters_school_scope ON school_public_id_counters;
CREATE POLICY school_public_id_counters_school_scope ON school_public_id_counters
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

GRANT SELECT, INSERT, UPDATE ON school_public_id_counters TO erp_tenant;

-- ─── 3. Idempotent backfill ──────────────────────────────────────────────────
--
-- For every school with a non-empty schools.code, assign PSIDs to existing
-- student_profiles that are still NULL, ordered by created_at then id, then set
-- each school's counter next_seq = (max assigned seq + 1). Schools whose code IS
-- NULL/empty are SKIPPED (their students stay NULL) — PSID requires a school code
-- (the school-code precondition). Guarded so re-running assigns nothing new:
--   - the row_number() ranking starts AFTER any already-assigned PSIDs by seeding
--     the offset from the current counter (COALESCE(next_seq, 1) - 1), and
--   - only rows WHERE public_student_id IS NULL are updated,
-- so a second run finds no NULL rows to assign and leaves counters untouched.

WITH school_offsets AS (
  -- Existing high-water mark per school (0 when no counter row yet). Ensures a
  -- re-run — or a partial prior backfill — never re-issues a number.
  SELECT
    s.id AS school_id,
    s.organization_id,
    s.code AS school_code,
    COALESCE(c.next_seq, 1) - 1 AS assigned_high
  FROM schools s
  LEFT JOIN school_public_id_counters c
    ON c.school_id = s.id AND c.organization_id = s.organization_id
  WHERE s.code IS NOT NULL AND btrim(s.code) <> ''
),
ranked AS (
  SELECT
    sp.id AS profile_id,
    so.school_code,
    so.assigned_high
      + row_number() OVER (
          PARTITION BY sp.school_id
          ORDER BY sp.created_at, sp.id
        ) AS seq
  FROM student_profiles sp
  INNER JOIN school_offsets so
    ON so.school_id = sp.school_id
    AND so.organization_id = sp.organization_id
  WHERE sp.public_student_id IS NULL
),
assigned AS (
  UPDATE student_profiles sp
  SET public_student_id = r.school_code || '-' || lpad(r.seq::text, 4, '0')
  FROM ranked r
  WHERE sp.id = r.profile_id
  RETURNING sp.organization_id, sp.school_id, r.seq
)
INSERT INTO school_public_id_counters (organization_id, school_id, next_seq)
SELECT organization_id, school_id, max(seq) + 1
FROM assigned
GROUP BY organization_id, school_id
ON CONFLICT (organization_id, school_id)
  DO UPDATE SET
    next_seq = GREATEST(school_public_id_counters.next_seq, EXCLUDED.next_seq),
    updated_at = timezone('utc', now());

-- ─── 4. Immutability trigger (PSID set-once) ─────────────────────────────────
--
-- Defense-in-depth mirror of reject_admission_number_change() (20260847000000).
-- Once a non-empty public_student_id is assigned it cannot change to a DIFFERENT
-- value. NULL/first-time assignment (this is a BEFORE UPDATE trigger, so a fresh
-- INSERT never fires it) and idempotent same-value writes are permitted via
-- IS DISTINCT FROM. Guards against any direct/rogue UPDATE (psql, a future code
-- path, a bad migration). Idempotent (CREATE OR REPLACE + DROP/CREATE TRIGGER).

CREATE OR REPLACE FUNCTION reject_public_student_id_change()
RETURNS TRIGGER AS $$
BEGIN
  IF OLD.public_student_id IS NOT NULL
     AND OLD.public_student_id IS DISTINCT FROM NEW.public_student_id THEN
    RAISE EXCEPTION 'public_student_id_immutable: public_student_id is set-once and cannot be changed (current: %, attempted: %).',
      OLD.public_student_id, NEW.public_student_id
      USING ERRCODE = 'check_violation';
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS student_profiles_reject_public_student_id_change ON student_profiles;

CREATE TRIGGER student_profiles_reject_public_student_id_change
  BEFORE UPDATE ON student_profiles
  FOR EACH ROW EXECUTE FUNCTION reject_public_student_id_change();
