-- HR-D2 · Probation-end follow-up — probation_end_date on the employees projection.
--
-- The HR probation follow-up slice tracks, per employee, the date their probation
-- ends so HR can confirm or extend before it lapses (15-day default lead). The
-- canonical read/write path operates on the employee JSONB payload (entity_type
-- 'employee' in hr_entities), consistent with the rest of the employee CRUD +
-- detail. This migration ALSO adds the field to the real `employees` projection so
-- that table stays a faithful, reportable mirror of employee identity for future
-- server-side probation reporting.
--
-- Nullable: only employees actually on probation carry a date; everyone else is
-- NULL (not on probation). No backfill — existing rows have no known probation end.
--
-- 🔴 Touches only the HR projection. The canonical identity source of truth —
-- `users` + `school_memberships(role)` — is untouched.

ALTER TABLE employees
  ADD COLUMN IF NOT EXISTS probation_end_date DATE NULL;

-- A partial index over just the probation rows keeps the "ending within N days"
-- lookup cheap without indexing the (mostly NULL) whole column.
CREATE INDEX IF NOT EXISTS idx_employees_probation_end
  ON employees (organization_id, school_id, probation_end_date)
  WHERE probation_end_date IS NOT NULL;
