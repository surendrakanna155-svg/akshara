-- Pilot closure: students must not read exam_mark_entries directly (entity read layer only)

DROP POLICY IF EXISTS exam_mark_entries_school ON exam_mark_entries;

CREATE POLICY exam_mark_entries_school ON exam_mark_entries
  FOR ALL USING (
    organization_id = app_current_tenant_id()
    AND school_id = app_current_school_id()
    AND (
      app_current_scope() = 'school'
      OR (app_current_scope() = 'parent' AND student_id IN (
        SELECT student_id FROM student_guardians
        WHERE guardian_user_id = app_current_parent_user_id()
          AND school_id = app_current_school_id()
      ))
    )
  );
