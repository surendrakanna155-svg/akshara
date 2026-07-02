-- HR-8 · Automatic Employee Provisioning — idempotency guarantee.
--
-- Onboarding (teacher/staff import commit) now auto-provisions an `employees`
-- projection row for each imported user, AFTER ensureSchoolMembership. To make
-- that provisioning safely idempotent (re-import = no duplicate) it relies on
-- `INSERT ... ON CONFLICT (organization_id, school_id, user_id) DO NOTHING`,
-- which requires a UNIQUE constraint on exactly those columns.
--
-- The v9.6 foundation created only a NON-unique index on
-- (organization_id, school_id, user_id) WHERE user_id IS NOT NULL. This
-- migration upgrades that to a PARTIAL UNIQUE index so at most one employee row
-- per (org, school, user). Rows with user_id IS NULL (e.g. manually-added
-- employees never linked to a login) are intentionally excluded from the
-- constraint and may coexist freely.
--
-- 🔴 This changes ONLY the HR projection (`employees`). The canonical identity
-- source of truth — `users` + `school_memberships(role)` — is untouched.

-- 1. Dedupe any pre-existing duplicates so the unique index can be created. -----
--    Keep the EARLIEST row per (org, school, user) (created_at, then id as a
--    stable tie-break); the later duplicates are removed. Before deleting, move
--    any role assignments that hang off a losing row onto the surviving row so
--    the ON DELETE CASCADE does not drop real role history. Re-pointed rows that
--    would collide with an existing (employee_id, role_code) on the survivor are
--    simply dropped (the survivor already carries that role).
WITH ranked AS (
  SELECT
    id,
    organization_id,
    school_id,
    user_id,
    first_value(id) OVER (
      PARTITION BY organization_id, school_id, user_id
      ORDER BY created_at ASC, id ASC
    ) AS keep_id
  FROM employees
  WHERE user_id IS NOT NULL
),
losers AS (
  SELECT id AS loser_id, keep_id
  FROM ranked
  WHERE id <> keep_id
)
-- 1a. Move role assignments from losers to the survivor (skip exact dup roles).
UPDATE employee_role_assignments era
SET employee_id = l.keep_id
FROM losers l
WHERE era.employee_id = l.loser_id
  AND NOT EXISTS (
    SELECT 1 FROM employee_role_assignments existing
    WHERE existing.employee_id = l.keep_id
      AND existing.role_code = era.role_code
  );

-- 1b. Delete the losing employee rows (their remaining dup role rows cascade).
WITH ranked AS (
  SELECT
    id,
    first_value(id) OVER (
      PARTITION BY organization_id, school_id, user_id
      ORDER BY created_at ASC, id ASC
    ) AS keep_id
  FROM employees
  WHERE user_id IS NOT NULL
)
DELETE FROM employees e
USING ranked r
WHERE e.id = r.id
  AND r.id <> r.keep_id;

-- 2. Replace the non-unique index with a PARTIAL UNIQUE index. -----------------
--    The unique index also serves lookups by (org, school, user_id), so the old
--    non-unique index is redundant and is dropped.
DROP INDEX IF EXISTS idx_employees_user;

CREATE UNIQUE INDEX idx_employees_user
  ON employees (organization_id, school_id, user_id)
  WHERE user_id IS NOT NULL;
