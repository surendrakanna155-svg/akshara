-- Adaptive AI — P3-AI-2 / W2.S: Universal School Search — student name-prefix index.
--
-- The Entity Resolver's fast typeahead path matches `lower(display_name) LIKE
-- 'prefix%'`. `text_pattern_ops` makes that prefix match index-usable so search
-- stays fast as a school grows (decision 10: 10k–100k+ records). Scoped by
-- school_id so each tenant's search touches only its own rows. Additive/dormant:
-- creates one index, touches no data. The code-identity fields already carry
-- indexes (students UNIQUE(school_id, student_code); student_profiles
-- (school_id, admission_number) + unique public_student_id), so this closes the
-- one non-indexed hot path.
--
-- NOTE (prod-scale): on a very large existing table prefer CREATE INDEX
-- CONCURRENTLY (run outside a txn) to avoid a write lock; kept plain here for the
-- migration runner. The partial `%contains%` fallback remains a bounded scan
-- (per-school + LIMIT) until the future pg_trgm step (decision 12).

CREATE INDEX IF NOT EXISTS idx_students_school_display_name_lower
  ON students (school_id, lower(display_name) text_pattern_ops);
