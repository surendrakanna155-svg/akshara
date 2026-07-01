-- ATT-D3 — half-day attendance mark + auto-excuse from approved leave.
--
-- Part A: allow the 'half_day' attendance mark (the 'excused' mark already
--   existed in the original CHECK; we keep it and add half_day).
-- Part B: add machine-readable leave date bounds (from_date / to_date) so an
--   APPROVED leave that covers the attendance date can auto-excuse the student.
--   The existing *_label text columns stay authoritative for display; the new
--   DATE columns are nullable so legacy label-only rows keep working (they
--   simply never trigger the auto-excuse).

-- Part A — extend the attendance mark CHECK to include 'half_day'.
ALTER TABLE attendance_records
  DROP CONSTRAINT IF EXISTS attendance_records_mark_check;
ALTER TABLE attendance_records
  ADD CONSTRAINT attendance_records_mark_check CHECK (
    mark IN ('present', 'absent', 'late', 'excused', 'half_day')
  );

-- Part B — machine-readable leave bounds for auto-excuse. Nullable: legacy rows
-- keep only the human labels and never auto-excuse.
ALTER TABLE mobile_leave_requests
  ADD COLUMN IF NOT EXISTS from_date DATE;
ALTER TABLE mobile_leave_requests
  ADD COLUMN IF NOT EXISTS to_date DATE;

-- Fast lookup for approvedLeaveStudentIdsForToday(): approved leaves for a
-- (org, school, student) whose window covers a given date.
CREATE INDEX IF NOT EXISTS idx_mobile_leave_approved_window
  ON mobile_leave_requests (organization_id, school_id, student_id, from_date, to_date)
  WHERE status = 'approved';
