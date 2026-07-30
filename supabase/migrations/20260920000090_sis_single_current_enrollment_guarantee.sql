-- ICA-E1 (P1) — single current-enrollment DB guarantee.
--
-- Root cause: sis_student_enrollments enforces at-most-one CURRENT placement per
-- student only in the APPLICATION. createEnrollment / updateEnrollment /
-- promoteStudentsBulk clear the prior is_current row, THEN insert (or flip) the
-- new one — a read-then-write with no row lock (sis_enrollments_repository.ts:
-- clearCurrentEnrollmentsForStudent + INSERT). Under READ COMMITTED, two
-- concurrent enroll/promote transactions for ONE student each clear on their own
-- snapshot (neither sees the other's uncommitted row) and each insert an
-- is_current = true row; both commit → TWO current enrollments for one student.
-- Downstream then silently picks the WRONG placement: report cards, class
-- rosters, transfer certificates, and getCurrentEnrollmentId() (which resolves
-- ties with ORDER BY created_at DESC LIMIT 1) all assume a single current row.
-- The pre-existing partial index idx_sis_student_enrollments_current
-- (school_id, student_id) WHERE is_current = true is NON-unique — it accelerates
-- current-row reads but enforces NOTHING.
--
-- The application fix (sis_enrollments_repository.ts) now catches the unique
-- violation this index raises and surfaces a clean CurrentEnrollmentConflictError
-- (a retryable 409) instead of a raw 500. This migration adds the DATABASE
-- invariant that makes "<= 1 current enrollment per student" un-bypassable even
-- if the application guard is ever regressed:
--
--   * a PARTIAL UNIQUE index on (school_id, student_id) WHERE is_current = true.
--     The column set + school scoping MATCH the existing non-unique partial index
--     idx_sis_student_enrollments_current (so this is not a semantically different
--     constraint — just the unique promotion of the same predicate). A student
--     belongs to exactly one school (students.school_id; student_profiles has
--     UNIQUE(student_id)), so "one current per (school, student)" is exactly "one
--     current per student". The racing loser's INSERT / UPDATE raises 23505, which
--     the repository replays as a conflict rather than committing a duplicate.
--
-- Forward-only, additive, idempotent (IF NOT EXISTS). No new grants/RLS: the index
-- rides the existing sis_student_enrollments privileges + school-scope policy.
--
-- SELF-HEAL PRE-STEP: a partial UNIQUE index CANNOT be built if any student
-- already has > 1 current enrollment. The canonical trunk is not yet deployed, so
-- no such duplicates are expected — but this migration is defensive so the CREATE
-- can never fail on legacy/racy data. The idempotent UPDATE below keeps only the
-- LATEST current row per (school_id, student_id) — newest by created_at, ties
-- broken by id — and demotes every OLDER current row to is_current = false BEFORE
-- the index is created. Re-running the migration is a no-op once at most one
-- current row remains per student. (This mirrors getCurrentEnrollmentId's
-- ORDER BY created_at DESC tie-break, so the heal keeps the same row the app
-- would have resolved to.)

UPDATE sis_student_enrollments e
SET is_current = false,
    updated_at = timezone('utc', now())
WHERE e.is_current = true
  AND EXISTS (
    SELECT 1
    FROM sis_student_enrollments newer
    WHERE newer.school_id = e.school_id
      AND newer.student_id = e.student_id
      AND newer.is_current = true
      AND (
        newer.created_at > e.created_at
        OR (newer.created_at = e.created_at AND newer.id > e.id)
      )
  );

CREATE UNIQUE INDEX IF NOT EXISTS sis_student_enrollments_one_current_uq
  ON sis_student_enrollments (school_id, student_id) WHERE is_current = true;
