-- Batch 5 (privacy fix): scope parent/student access to attendance_records.
--
-- The original `attendance_records_school` policy was FOR ALL with
-- scope IN ('school','parent','student') and no per-student restriction, so ANY
-- parent or student in the school could read (and even write) EVERY student's
-- attendance — a privacy leak flagged in Batch 3.
--
-- Fix: school scope (teachers/admins) keeps full read+write; parent/student get
-- SELECT only, restricted to the caller's OWN children (via student_guardians)
-- or their OWN record. Mirrors the Batch 4 parent/student finance read policies.

DROP POLICY IF EXISTS attendance_records_school ON attendance_records;

-- School staff (teachers/admins): full read+write within their school.
CREATE POLICY attendance_records_school ON attendance_records
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

-- Parent: read only their linked children's records. Student: read only own.
CREATE POLICY attendance_records_parent_student_read ON attendance_records
  FOR SELECT
  USING (
    organization_id = app_current_tenant_id()
    AND school_id = app_current_school_id()
    AND (
      (
        app_current_scope() = 'parent'
        AND student_id IN (
          SELECT student_id FROM student_guardians
          WHERE guardian_user_id = app_current_parent_user_id()
            AND school_id = app_current_school_id()
        )
      )
      OR (
        app_current_scope() = 'student'
        AND student_id = app_current_student_id()
      )
    )
  );
