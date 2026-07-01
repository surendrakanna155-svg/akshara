-- EXM-6 — marks-entry deadline on an exam session.
--
-- A coordinator can set a soft deadline by which subject teachers must have
-- entered marks for an exam. This migration ONLY adds the field; it does NOT
-- build a scheduler. The automated teacher reminder rides a future reminder-rule
-- engine on XCT-2 (out of scope here). The app surfaces the deadline as a banner
-- on the marks-entry screen when set.
--
-- Additive + backward-compatible: the column is NULLABLE and defaults to NULL, so
-- every existing exam session is unchanged (no deadline) and any code that
-- ignores the field behaves exactly as before.

ALTER TABLE exam_sessions
  ADD COLUMN IF NOT EXISTS marks_entry_deadline TIMESTAMPTZ NULL;
