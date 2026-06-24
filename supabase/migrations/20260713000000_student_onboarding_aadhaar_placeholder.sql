-- First-time student data onboarding — Aadhaar + placeholder support (Track A)
-- Additive + idempotent. Extends the students identity table and the import-job
-- machinery so we can (a) capture an optional, masked Aadhaar with a hash for
-- dedupe, and (b) generate rollbackable placeholder students.

-- ─── students: optional Aadhaar (masked) + placeholder flag ──────────────────
-- Aadhaar is stored MASKED (only last 4 digits visible, e.g. 'XXXXXXXX1234').
-- aadhaar_hash is the sha256 hex of the full 12-digit number, used for dedupe
-- only. is_placeholder marks skeleton students that have no real parent login.

ALTER TABLE students
  ADD COLUMN IF NOT EXISTS is_placeholder BOOLEAN NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS aadhaar TEXT,
  ADD COLUMN IF NOT EXISTS aadhaar_hash TEXT;

-- Dedupe: one Aadhaar per school (only where present).
CREATE UNIQUE INDEX IF NOT EXISTS uq_students_school_aadhaar_hash
  ON students (school_id, aadhaar_hash)
  WHERE aadhaar_hash IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_students_placeholder
  ON students (school_id)
  WHERE is_placeholder = true;

-- ─── student_profiles: optional mother name ──────────────────────────────────
-- Parsed from the import template; persisted additively so it is not dropped.

ALTER TABLE student_profiles
  ADD COLUMN IF NOT EXISTS mother_name TEXT;

-- ─── onboarding_import_jobs: allow placeholder generation jobs ───────────────
-- Reuse the existing import-job / rollback machinery via a new import_type.

ALTER TABLE onboarding_import_jobs
  DROP CONSTRAINT IF EXISTS onboarding_import_jobs_import_type_check;

ALTER TABLE onboarding_import_jobs
  ADD CONSTRAINT onboarding_import_jobs_import_type_check
    CHECK (import_type IN ('student', 'teacher', 'student_placeholder'));
