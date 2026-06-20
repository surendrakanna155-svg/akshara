-- Teacher read-model per-teacher scoping.
--
-- `teacher_entities` (the denormalized mobile read-model) was only school-scoped:
-- any teacher/staff with school scope could read EVERY teacher's snapshot rows
-- (dashboard, attendance, exam marks, messages...). Its siblings parent_entities
-- and student_entities already carry an owner column (student_id) and an RLS
-- filter keyed to the logged-in user. This brings teacher_entities to parity by
-- adding `teacher_id` (the teacher's user id = JWT sub) to the key + RLS, so a
-- teacher only ever sees their own rows. Mirrors the authoritative
-- exam_mark_entries subject-teacher scoping, just at the read-model layer.

-- 1. Add the owner column (nullable first so existing rows can be backfilled).
ALTER TABLE teacher_entities ADD COLUMN teacher_id UUID;

-- 2. Backfill seeded rows to the seeded teacher (STAFF_A). Cross-school probe
--    rows are also pinned to STAFF_A — the school_id check already denies them,
--    so the owner value is immaterial there.
UPDATE teacher_entities
SET teacher_id = 'a3000000-0000-4000-8000-000000000001'
WHERE teacher_id IS NULL;

-- 3. Lock it down.
ALTER TABLE teacher_entities ALTER COLUMN teacher_id SET NOT NULL;

-- 4. Re-key the table to include the owner (matches student_entities shape).
ALTER TABLE teacher_entities DROP CONSTRAINT teacher_entities_pkey;
ALTER TABLE teacher_entities
  ADD PRIMARY KEY (organization_id, school_id, teacher_id, entity_type, id);

DROP INDEX IF EXISTS idx_teacher_entities_org_school_type;
CREATE INDEX idx_teacher_entities_scope
  ON teacher_entities (organization_id, school_id, teacher_id, entity_type);

-- 5. Replace the school-wide policy with a per-teacher one. Teachers keep
--    scope='school'; the new clause limits each session to its own rows.
DROP POLICY IF EXISTS teacher_entities_school_scope ON teacher_entities;

CREATE POLICY teacher_entities_teacher_scope ON teacher_entities
  FOR ALL USING (
    organization_id = app_current_tenant_id()
    AND app_current_scope() = 'school'
    AND school_id = app_current_school_id()
    AND teacher_id = app_current_user_id()
  ) WITH CHECK (
    organization_id = app_current_tenant_id()
    AND app_current_scope() = 'school'
    AND school_id = app_current_school_id()
    AND teacher_id = app_current_user_id()
  );
