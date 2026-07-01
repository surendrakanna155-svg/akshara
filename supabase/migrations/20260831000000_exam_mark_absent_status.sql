-- EXM-D6 — Absent / "AB" (and Medical Leave "ML", Debarred "DB") status on exam
-- mark entries.
--
-- A student can be absent (or on medical leave / debarred) for an exam. The
-- adopted default (owner decision): show a display code ("AB"/"ML"/"DB") on the
-- report card, EXCLUDE the row from the class total/average/percent and from
-- class rank (a non-present student is not ranked and does not affect anyone
-- else's rank), and from pass/fail + grade distribution.
--
-- Modelling choice (owner directive):
--   * status = 'present'  → marks_obtained is REQUIRED (actual, bounds-checked).
--   * status != 'present' → marks_obtained is NULL (no meaningful score).
-- So `marks_obtained` is made NULLABLE. The existing marks-bounds CHECK
-- (marks_obtained >= 0 AND marks_obtained <= max_marks) still holds: a NULL
-- comparison evaluates to UNKNOWN, which does NOT violate a CHECK — a NULL row
-- passes. The unique (org, school, exam_id, student_id) constraint, the
-- row_version optimistic-concurrency trigger, and the published-immutability
-- guard (UPDATE ... WHERE published = false) are all left intact.
--
-- Additive + backward-compatible: every existing row defaults to status
-- 'present' and keeps its (non-null) marks, so present students are unchanged and
-- any code that ignores `status` behaves exactly as before.

-- 1) Attendance status column + enum guard.
ALTER TABLE exam_mark_entries
  ADD COLUMN IF NOT EXISTS status TEXT NOT NULL DEFAULT 'present';

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'exam_mark_entries_status_check'
  ) THEN
    ALTER TABLE exam_mark_entries
      ADD CONSTRAINT exam_mark_entries_status_check
      CHECK (status IN ('present', 'absent', 'medical_leave', 'debarred')) NOT VALID;
  END IF;
END $$;

-- 2) A non-present student has no score → marks_obtained must be nullable.
--    The marks-bounds CHECK (added in 20260814000000) is UNKNOWN (i.e. passes)
--    for a NULL marks_obtained, so it stays in force for present students.
ALTER TABLE exam_mark_entries
  ALTER COLUMN marks_obtained DROP NOT NULL;
