-- Attendance integrity hardening (owner completion gates #1-#8).
--
-- The teacher marking path (upsertAttendanceSession) previously:
--   * overwrote a SUBMITTED session on re-submit (bypassing corrections),
--   * keyed the session on (class_label, date, taken_by) with NO DB uniqueness,
--     so two teachers / a concurrent submit could create duplicate sessions,
--   * had no period dimension.
-- This migration makes the session natural key enforceable and adds the columns
-- the hardened repository needs. Immutability, holiday/year-closure blocks and
-- roster reconciliation are enforced in code (finance-style guards) on top of it.

-- Period dimension (default '' = whole-day attendance; a real period label makes
-- period-wise attendance a distinct session per the owner's "unless intentionally
-- configured").
ALTER TABLE attendance_sessions
  ADD COLUMN IF NOT EXISTS period_label TEXT NOT NULL DEFAULT '';

-- When the session was submitted (immutability + audit).
ALTER TABLE attendance_sessions
  ADD COLUMN IF NOT EXISTS submitted_at TIMESTAMPTZ;

-- Collapse any pre-existing duplicates before the unique index: keep the newest
-- (a submitted one wins over a draft) per natural key; drop the losers' records
-- first (no ON DELETE CASCADE on attendance_records), then the loser sessions.
DELETE FROM attendance_records WHERE session_id IN (
  SELECT id FROM (
    SELECT id, row_number() OVER (
      PARTITION BY organization_id, school_id, class_label, session_date, period_label
      ORDER BY (status = 'submitted') DESC, updated_at DESC, created_at DESC
    ) AS rn
    FROM attendance_sessions
  ) ranked WHERE ranked.rn > 1
);
DELETE FROM attendance_sessions WHERE id IN (
  SELECT id FROM (
    SELECT id, row_number() OVER (
      PARTITION BY organization_id, school_id, class_label, session_date, period_label
      ORDER BY (status = 'submitted') DESC, updated_at DESC, created_at DESC
    ) AS rn
    FROM attendance_sessions
  ) ranked WHERE ranked.rn > 1
);

-- #2 / #3 — exactly one session per (school, class, date, period). Makes the
-- upsert race-safe (ON CONFLICT) and forbids duplicate sessions at the DB.
CREATE UNIQUE INDEX IF NOT EXISTS uq_attendance_sessions_class_date_period
  ON attendance_sessions (organization_id, school_id, class_label, session_date, period_label);
