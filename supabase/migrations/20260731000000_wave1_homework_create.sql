-- Wave 1 / TCH-1 — Teacher homework CREATE persistence.
--
-- Homework is created by a teacher (school scope) and must be delivered to
-- students as `homework_item` entities in `student_entities` (which the student
-- read path already surfaces). The existing `student_entities` RLS only allows
-- the student themselves (student scope) to touch their rows, so a teacher
-- cannot deliver homework. This adds a BOUNDED school-scope policy limited to
-- the `homework_item` entity type, so a teacher may create/update homework
-- items for students in their own school — and nothing else on that table.
--
-- Students still read their own homework via the existing student-scope policy;
-- this policy only widens INSERT/UPDATE/SELECT for the homework_item type to the
-- school scope (same org + school), leaving all other student entity types
-- (dashboard/attendance/exams/profile snapshots, notices, probes) student-only.

CREATE POLICY student_entities_school_homework ON student_entities
  FOR ALL
  USING (
    organization_id = app_current_tenant_id()
    AND app_current_scope() = 'school'
    AND school_id = app_current_school_id()
    AND entity_type = 'homework_item'
  )
  WITH CHECK (
    organization_id = app_current_tenant_id()
    AND app_current_scope() = 'school'
    AND school_id = app_current_school_id()
    AND entity_type = 'homework_item'
  );
