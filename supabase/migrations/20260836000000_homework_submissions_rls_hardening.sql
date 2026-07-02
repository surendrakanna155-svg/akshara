-- Homework security hardening — homework_submissions RLS + cross-class scope.
--
-- The pilot homework loop (teacher → student → parent) persists a student's
-- work in `homework_submissions`. RLS was ENABLE+FORCE'd in
-- 20260614800000_pilot_operations.sql, but the original
-- `homework_submissions_scope` policy was a single FOR ALL policy with NO
-- WITH CHECK, so:
--   * a student's INSERT/UPDATE was only constrained by the USING clause on the
--     rows being read/updated — a fresh INSERT has no existing row to test, so
--     the missing WITH CHECK meant the *new* row's student_id was never verified
--     against app_current_student_id(). A student could write a row for another
--     student_id.
--   * school scope was FOR ALL with no per-row WITH CHECK either.
--
-- Fix (mirrors 20260706000000_attendance_records_parent_privacy_rls.sql):
--   * school scope (teachers/admins): full read+write within own org+school,
--     with a matching WITH CHECK so writes cannot escape the tenant/school.
--   * student scope: SELECT + INSERT/UPDATE ONLY their OWN rows
--     (student_id = app_current_student_id()) — enforced on BOTH the read side
--     (USING) and the write side (WITH CHECK), so a student can never read or
--     write another student's submission.
--   * parent scope: SELECT only, restricted to their linked children via
--     student_guardians. No write.
--
-- Idempotent: safe to re-run. RLS is already ENABLE+FORCE from the base
-- migration; we re-assert it defensively in case this runs against a DB where
-- the base migration predates the FORCE.

ALTER TABLE homework_submissions ENABLE ROW LEVEL SECURITY;
ALTER TABLE homework_submissions FORCE ROW LEVEL SECURITY;

-- Replace the loose combined policy with a tightened, split set.
DROP POLICY IF EXISTS homework_submissions_scope ON homework_submissions;
DROP POLICY IF EXISTS homework_submissions_school ON homework_submissions;
DROP POLICY IF EXISTS homework_submissions_student_own ON homework_submissions;
DROP POLICY IF EXISTS homework_submissions_parent_read ON homework_submissions;

-- School staff (teachers/admins): full read+write within their own org+school.
CREATE POLICY homework_submissions_school ON homework_submissions
  FOR ALL
  USING (
    organization_id = app_current_tenant_id()
    AND school_id = app_current_school_id()
    AND app_current_scope() = 'school'
  )
  WITH CHECK (
    organization_id = app_current_tenant_id()
    AND school_id = app_current_school_id()
    AND app_current_scope() = 'school'
  );

-- Student: read + insert/update ONLY their own rows. The WITH CHECK is what
-- blocks a student from writing (or moving) a row to another student_id.
CREATE POLICY homework_submissions_student_own ON homework_submissions
  FOR ALL
  USING (
    organization_id = app_current_tenant_id()
    AND school_id = app_current_school_id()
    AND app_current_scope() = 'student'
    AND student_id = app_current_student_id()
  )
  WITH CHECK (
    organization_id = app_current_tenant_id()
    AND school_id = app_current_school_id()
    AND app_current_scope() = 'student'
    AND student_id = app_current_student_id()
  );

-- Parent: read only their linked children's submissions (no write).
CREATE POLICY homework_submissions_parent_read ON homework_submissions
  FOR SELECT
  USING (
    organization_id = app_current_tenant_id()
    AND school_id = app_current_school_id()
    AND app_current_scope() = 'parent'
    AND student_id IN (
      SELECT student_id FROM student_guardians
      WHERE guardian_user_id = app_current_parent_user_id()
        AND school_id = app_current_school_id()
    )
  );

-- Grants are unchanged from the base migration (INSERT/UPDATE/SELECT for the
-- tenant role); re-assert defensively so this migration is self-contained.
GRANT SELECT, INSERT, UPDATE ON homework_submissions TO erp_tenant;
