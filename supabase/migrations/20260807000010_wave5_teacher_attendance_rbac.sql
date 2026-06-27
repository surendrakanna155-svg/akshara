-- Journey Wave 5 — MJ-M10 (TEACH-4) + MJ-M11 (ATTEN-3, ATTEN-2)
-- Intra-school RBAC hardening for the teacher pilot write handlers + a
-- parent-scoped attendance-correction path.
--
-- Problem (MJ-M10 / MJ-M11): the pilot teacher write handlers (mark attendance,
-- create/grade homework, update exam marks) authorized ONLY on
-- claims.scope='school' && school_id with NO granular permission, so any
-- school-scoped account (librarian, accountant, HR, transport coordinator …)
-- could mark/overwrite any class's attendance, grade any submission, or edit any
-- mark. There was also no server permission for these actions at all — the
-- teacher role marks attendance via the scope-only path, so we cannot simply
-- gate on the existing manageSis (teachers don't hold it).
--
-- Fix: define three granular teaching permissions and grant them to the roles
-- that legitimately teach/supervise academics; the handlers now require them.
-- Non-teaching staff lose the ability to perform these writes.
--
-- Problem (MJ-M11 / ATTEN-2): a parent's POST attendance-correction was 403'd
-- because attendance_corrections RLS is scope='school' FOR ALL. Fix: add
-- parent-scoped INSERT + SELECT policies restricted to the parent's OWN children
-- (via student_guardians) and to parent-authored ('parent') pending rows.

-- 1. Granular teaching-action permissions. `markAttendance` already exists in
--    the Flutter Permission enum but was never a server permission; `manageHomework`
--    is new on both sides. `manageExamMarks` already exists server-side (exam
--    governance migration) — we reuse it rather than coin a duplicate, keeping the
--    client enum and server slugs aligned (the drift this wave is closing).
INSERT INTO permission_definitions (slug, module, action, scope, description) VALUES
  ('markAttendance', 'SIS', 'manage', 'school', 'Mark class attendance'),
  ('manageHomework', 'Education', 'manage', 'school', 'Create and grade homework')
ON CONFLICT (slug) DO NOTHING;

-- 2. Grant to the roles that teach or supervise academics. Deliberately EXCLUDES
--    non-teaching staff (librarian, officeStaff, finance/hr/inventory/transport/
--    marketing managers, counselor, admissionsCounselor) so they can no longer
--    mark attendance, grade homework, or edit marks (ATTEN-3 / TEACH-4
--    intra-school role separation). schoolAdmin/principal/vicePrincipal retain
--    them as supervisors. `manageExamMarks` was already granted to
--    teacher/schoolAdmin/principal/vicePrincipal/management by the exam-governance
--    migration; here we extend it to the remaining teaching roles (ON CONFLICT
--    DO NOTHING leaves the existing grants untouched).
INSERT INTO role_permissions (role_slug, permission_slug)
SELECT v.role_slug, v.permission_slug
FROM (VALUES
  ('teacher', 'markAttendance'), ('teacher', 'manageHomework'), ('teacher', 'manageExamMarks'),
  ('classTeacher', 'markAttendance'), ('classTeacher', 'manageHomework'), ('classTeacher', 'manageExamMarks'),
  ('coordinator', 'markAttendance'), ('coordinator', 'manageHomework'), ('coordinator', 'manageExamMarks'),
  ('petTeacher', 'markAttendance'), ('petTeacher', 'manageHomework'), ('petTeacher', 'manageExamMarks'),
  ('danceTeacher', 'markAttendance'), ('danceTeacher', 'manageHomework'), ('danceTeacher', 'manageExamMarks'),
  ('musicTeacher', 'markAttendance'), ('musicTeacher', 'manageHomework'), ('musicTeacher', 'manageExamMarks'),
  ('principal', 'markAttendance'), ('principal', 'manageHomework'),
  ('vicePrincipal', 'markAttendance'), ('vicePrincipal', 'manageHomework'),
  ('schoolAdmin', 'markAttendance'), ('schoolAdmin', 'manageHomework')
) AS v(role_slug, permission_slug)
INNER JOIN role_definitions rd ON rd.slug = v.role_slug
INNER JOIN permission_definitions pd ON pd.slug = v.permission_slug
ON CONFLICT DO NOTHING;

-- 2b. ATTEN-2 (client/server drift) — the parent UI gates the correction dialog
--     on Permission.submitAttendanceCorrection, but that permission was never
--     defined or granted server-side, so in live mode the parent JWT lacks it and
--     the client blocks the parent before the request is even sent. Define it and
--     grant it to the parent role. (The server parent route itself is
--     null-permission + RLS-scoped; this only satisfies the client gate + offline
--     matrix, aligning client and server.)
INSERT INTO permission_definitions (slug, module, action, scope, description) VALUES
  ('submitAttendanceCorrection', 'SIS', 'submit', 'school', 'Submit an attendance correction request')
ON CONFLICT (slug) DO NOTHING;

INSERT INTO role_permissions (role_slug, permission_slug)
SELECT v.role_slug, v.permission_slug
FROM (VALUES ('parent', 'submitAttendanceCorrection')) AS v(role_slug, permission_slug)
INNER JOIN role_definitions rd ON rd.slug = v.role_slug
INNER JOIN permission_definitions pd ON pd.slug = v.permission_slug
ON CONFLICT DO NOTHING;

-- 3. ATTEN-2 — parents may submit (and read) attendance corrections for their
--    OWN linked children. The existing FOR ALL school-scope policy rejects
--    scope='parent'; these permissive policies add a tightly-scoped parent path.
--    INSERT is restricted to parent-authored, pending rows whose resolved
--    student_id is linked to the calling parent via student_guardians — so a
--    parent can neither author a correction for someone else's child nor forge a
--    non-'parent' requester_role or a pre-approved status.
CREATE POLICY attendance_corrections_parent_insert ON attendance_corrections
  FOR INSERT
  WITH CHECK (
    organization_id = app_current_tenant_id()
    AND school_id = app_current_school_id()
    AND app_current_scope() = 'parent'
    AND requester_role = 'parent'
    AND status = 'pending'
    AND student_id IN (
      SELECT student_id FROM student_guardians
      WHERE guardian_user_id = app_current_parent_user_id()
        AND school_id = app_current_school_id()
    )
  );

CREATE POLICY attendance_corrections_parent_read ON attendance_corrections
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
