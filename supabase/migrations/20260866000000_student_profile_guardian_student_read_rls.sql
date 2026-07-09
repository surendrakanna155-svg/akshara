-- P2 gap-sweep follow-up (2026-07-09): student-scope READ policy for
-- student_profiles / student_guardians.
--
-- Both tables carried NO student-scope SELECT policy — student_profiles was
-- 'school'-scope FOR ALL only (20260613000000_sis_slice0_foundation.sql), and
-- student_guardians had only 'school'/'parent' SELECT branches
-- (20260609100000_phase2_rls_scope.sql). A real student token (scope='student')
-- could therefore never read its OWN profile or guardian rows, so the student
-- app's profile fields (admissionNo / dateOfBirth / bloodGroup / parentContacts)
-- silently read back empty even though studentName/classLabel/rollNo populate
-- from students + sis_student_enrollments (which already have a student branch).
-- Root cause was already self-documented at
-- pilot/pilot_operations_repository.ts:1297-1306 ("KNOWN LIMITATION ... the
-- moment that follow-up RLS grant lands ...") — this migration is that grant.
--
-- Mirrors the established, thrice-used house pattern exactly:
--   20260703100000_parent_student_exam_read_rls.sql
--   20260706000000_attendance_records_parent_privacy_rls.sql
-- Additive and non-destructive: the existing school-only (and, for
-- student_guardians, parent) policies are left untouched. Both tables already
-- GRANT SELECT ... TO erp_tenant, so no new grants are required.
--
-- Scope note: this adds the STUDENT branch only (the explicit ask — student
-- profile fields not populating for a logged-in student). student_profiles
-- still has no PARENT read branch (unlike student_guardians, which does); adding
-- parent-read of a child's profile is a separate, deliberate privacy decision
-- and is intentionally out of scope here.

-- A student may read their OWN profile row.
DROP POLICY IF EXISTS student_profiles_student_read ON student_profiles;
CREATE POLICY student_profiles_student_read ON student_profiles
  FOR SELECT
  USING (
    organization_id = app_current_tenant_id()
    AND school_id = app_current_school_id()
    AND app_current_scope() = 'student'
    AND student_id = app_current_student_id()
  );

-- A student may read their OWN guardian rows (parent contacts).
DROP POLICY IF EXISTS student_guardians_student_read ON student_guardians;
CREATE POLICY student_guardians_student_read ON student_guardians
  FOR SELECT
  USING (
    organization_id = app_current_tenant_id()
    AND school_id = app_current_school_id()
    AND app_current_scope() = 'student'
    AND student_id = app_current_student_id()
  );
