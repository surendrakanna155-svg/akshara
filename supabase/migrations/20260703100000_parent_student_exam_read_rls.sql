-- Batch 3 (core school loop): let parents/students READ what they need to see
-- published exam results. Previously exam_sessions and sis_student_enrollments
-- were school-scope only, so the parent results query (which JOINs exam_sessions)
-- returned nothing even though exam_mark_entries already grants per-child access.
--
-- exam_sessions holds only non-sensitive exam metadata (title/subject/date/phase),
-- no per-student marks, so parent/student read of the school's sessions is safe.
-- Enrollments are restricted to the caller's own children / own record.

-- Parent & student may read exam session metadata for their school.
DROP POLICY IF EXISTS exam_sessions_parent_student_read ON exam_sessions;
CREATE POLICY exam_sessions_parent_student_read ON exam_sessions
  FOR SELECT
  USING (
    organization_id = app_current_tenant_id()
    AND school_id = app_current_school_id()
    AND app_current_scope() = ANY (ARRAY['parent', 'student'])
  );

-- Parent may read their linked children's enrollments; student may read their own.
DROP POLICY IF EXISTS sis_student_enrollments_parent_student_read ON sis_student_enrollments;
CREATE POLICY sis_student_enrollments_parent_student_read ON sis_student_enrollments
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
