-- PRA-P0-09 (S3): add the missing FK on academic_timetable_periods.teacher_id.
--
-- GAP: 20260615050000_academic_timetable_engine.sql:30 declares
--        teacher_id UUID,
--      with NO `REFERENCES`, while the very next line (:31) correctly does
--        teacher_assignment_id UUID REFERENCES teacher_assignments (id).
--      Every other teacher pointer in the schema references users(id) — e.g.
--      teacher_assignments.teacher_id (20260614790000_academic_foundation.sql:147,
--      `teacher_id UUID NOT NULL REFERENCES users (id)`). The writer
--      timetable_repository.ts:246-262 populates teacher_id from
--      teacher_assignments.teacher_id, whose values are users.id
--      (join confirmed at timetable_repository.ts:651-659). So the correct
--      referential target is users(id), and the un-referenced column allowed a
--      timetable period to point at a non-existent / cross-tenant user id.
--
-- ON DELETE: mirror the sibling teacher_assignments.teacher_id FK
--      (20260614790000_academic_foundation.sql:147) which has NO ON DELETE
--      clause => PostgreSQL default NO ACTION. We therefore add NO clause here
--      as well: deleting a users row that is still referenced by a period is
--      blocked, exactly as it is for teacher_assignments.
--
-- ORPHAN PRE-FLIGHT: ADD CONSTRAINT validates existing rows and would fail on a
--      live tenant if any teacher_id has no matching users.id. The column is
--      NULLABLE (schema line 30: `teacher_id UUID,` — no NOT NULL), so we first
--      null out any orphaned pointers, which is a safe no-op on a clean DB.
--
-- INDEX: idx_academic_timetable_periods_teacher already covers teacher_id
--      (20260615050000_academic_timetable_engine.sql:39-40) — no new index needed.

BEGIN;

-- 1. Repair orphans before the FK validates (safe because teacher_id is nullable).
UPDATE academic_timetable_periods
   SET teacher_id = NULL
 WHERE teacher_id IS NOT NULL
   AND teacher_id NOT IN (SELECT id FROM users);

-- 2. Add the FK idempotently (re-run must not error).
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
     WHERE conname = 'academic_timetable_periods_teacher_id_fkey'
  ) THEN
    ALTER TABLE academic_timetable_periods
      ADD CONSTRAINT academic_timetable_periods_teacher_id_fkey
      FOREIGN KEY (teacher_id) REFERENCES users (id);
  END IF;
END $$;

COMMIT;
