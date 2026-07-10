-- Adaptive AI — P3-AI-2 / W2.S: Universal School Search — scale indexes (P1-5).
--
-- The Entity Resolver's match-priority fetch (search_repository.ts) uses
-- lower(<id-field>) LIKE 'prefix%' for the high-priority structured paths and a
-- lower(name) LIKE '%contains%' fallback for the lowest-priority path. Neither
-- was index-backed: the code/admission#/roll uniques are on the RAW columns (so
-- lower(col) LIKE … can't use them), and the leading-wildcard name-contains
-- needs trigram. This closes both so search stays fast at the locked 10k–100k
-- records/school target (decision 10/12 — the pg_trgm step deferred by 20260871).
--
-- Additive/dormant: creates indexes only, touches no data, changes no results.
-- NOTE (prod-scale): on very large existing tables prefer CREATE INDEX
-- CONCURRENTLY (outside a txn) to avoid a write lock; kept plain for the
-- migration runner, matching 20260871/20260872.

CREATE EXTENSION IF NOT EXISTS pg_trgm;

-- ── Students — functional lower() prefix indexes for the structured paths ──────
CREATE INDEX IF NOT EXISTS idx_students_school_code_lower
  ON students (school_id, lower(student_code) text_pattern_ops);
CREATE INDEX IF NOT EXISTS idx_student_profiles_school_admission_lower
  ON student_profiles (school_id, lower(admission_number) text_pattern_ops);
CREATE INDEX IF NOT EXISTS idx_student_profiles_school_public_id_lower
  ON student_profiles (school_id, lower(public_student_id) text_pattern_ops);
-- Roll match is exact equality (lower(roll) = q) → plain functional index.
CREATE INDEX IF NOT EXISTS idx_sis_enroll_school_roll_lower
  ON sis_student_enrollments (school_id, lower(roll_number));

-- ── Trigram GIN for the name-CONTAINS fallback (leading-wildcard LIKE '%x%') ───
CREATE INDEX IF NOT EXISTS idx_students_display_name_trgm
  ON students USING gin (lower(display_name) gin_trgm_ops);

-- ── Staff ─────────────────────────────────────────────────────────────────────
CREATE INDEX IF NOT EXISTS idx_employees_school_code_lower
  ON employees (school_id, lower(employee_code) text_pattern_ops);
CREATE INDEX IF NOT EXISTS idx_employees_display_name_trgm
  ON employees USING gin (lower(display_name) gin_trgm_ops);

-- ── Admissions leads ──────────────────────────────────────────────────────────
CREATE INDEX IF NOT EXISTS idx_admissions_student_name_trgm
  ON admissions_leads USING gin (lower(student_name) gin_trgm_ops);
CREATE INDEX IF NOT EXISTS idx_admissions_parent_name_trgm
  ON admissions_leads USING gin (lower(parent_name) gin_trgm_ops);
