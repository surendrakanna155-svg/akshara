-- Unify student identity — referential integrity for operational student rows.
--
-- Batch 6 (2026-06-24). Several core operational tables carried a bare
-- `student_id UUID NOT NULL` with NO foreign key to `students` — meaning marks,
-- attendance, payments, homework, timeline events and material distributions
-- could be written for, or left dangling against, a student id that does not
-- exist, and were never cleaned up when a student record was removed. This is
-- the concrete "student identity" fragmentation: the same student keyed across
-- modules with nothing guaranteeing the key resolves.
--
-- This migration adds the missing `student_id → students(id) ON DELETE CASCADE`
-- foreign keys, matching the dominant convention already used by
-- student_profiles / student_guardians / sis_student_enrollments (12 existing
-- ON DELETE CASCADE student FKs). Every target was verified to hold ZERO orphan
-- rows on the live database before this was written, so validation is clean.
--
-- Scope is deliberately the CORE operational tables. Read-cache / snapshot /
-- analytics tables (parent_entities, student_entities, *_summaries,
-- intel_*_snapshots) intentionally keep a bare student_id: they are rebuilt
-- projections, not source-of-truth rows, and a hard FK there would couple
-- re-sync ordering to deletes. The admissions lead→application→enrollment→
-- student chain is already FK-enforced end to end and needs no change.

DO $$
DECLARE
  target TEXT;
  targets TEXT[] := ARRAY[
    'exam_mark_entries',
    'exam_remarks',
    'attendance_records',
    'homework_submissions',
    'payment_requests',
    'inv_student_distributions',
    'student_timeline_events',
    'edu_homework_student_targets'
  ];
BEGIN
  FOREACH target IN ARRAY targets LOOP
    -- Skip tables not present in this deployment (partial-deploy safe).
    IF to_regclass(target) IS NULL THEN
      CONTINUE;
    END IF;
    -- Idempotent: add the FK only if it is not already there.
    IF NOT EXISTS (
      SELECT 1 FROM pg_constraint
      WHERE conname = target || '_student_id_fkey'
    ) THEN
      EXECUTE format(
        'ALTER TABLE %I ADD CONSTRAINT %I '
        || 'FOREIGN KEY (student_id) REFERENCES students (id) ON DELETE CASCADE',
        target, target || '_student_id_fkey'
      );
    END IF;
  END LOOP;
END $$;
