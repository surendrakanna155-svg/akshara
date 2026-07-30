\set ON_ERROR_STOP off
\pset pager off
BEGIN;
CREATE TEMP TABLE r(ord int, probe text, verdict text, evidence text);

CREATE TEMP TABLE f AS
SELECT (SELECT organization_id FROM schools ORDER BY id LIMIT 1) AS orga,
       (SELECT id FROM schools ORDER BY id LIMIT 1)              AS scha,
       (SELECT id FROM users ORDER BY id LIMIT 1)                AS staff,
       gen_random_uuid() AS stua, gen_random_uuid() AS stub,
       gen_random_uuid() AS teachert, gen_random_uuid() AS sectionx;

INSERT INTO students (id, organization_id, school_id, student_code, display_name, status)
SELECT stua, orga, scha, 'ZZ-A-2', 'ZZ StudentA', 'active' FROM f;
INSERT INTO students (id, organization_id, school_id, student_code, display_name, status)
SELECT stub, orga, scha, 'ZZ-B-2', 'ZZ StudentB', 'active' FROM f;
INSERT INTO users (id, phone, display_name) SELECT teachert, '9990000013', 'ZZ TeacherT' FROM f;

-- Real class + TWO real sections (section_id is a hard FK to sections).
INSERT INTO classes (id, organization_id, school_id, academic_year_id, class_name)
SELECT gen_random_uuid(), orga, scha, (SELECT id FROM academic_years WHERE organization_id=f.orga LIMIT 1), 'ZZ Grade 8' FROM f;
CREATE TEMP TABLE cl AS SELECT id AS class_id FROM classes WHERE class_name='ZZ Grade 8' LIMIT 1;
INSERT INTO sections (id, organization_id, school_id, class_id, section_name)
SELECT sectionx, orga, scha, cl.class_id, 'ZZ-A' FROM f, cl;
INSERT INTO sections (id, organization_id, school_id, class_id, section_name)
SELECT gen_random_uuid(), orga, scha, cl.class_id, 'ZZ-B' FROM f, cl;
CREATE TEMP TABLE sy AS SELECT id AS sectiony FROM sections WHERE section_name='ZZ-B' LIMIT 1;

-- StudentA is on TeacherT's section; StudentB is on a DIFFERENT section.
INSERT INTO sis_student_enrollments (organization_id, school_id, student_id, academic_year, class_name, section_name, is_current, section_id)
SELECT orga, scha, stua, '2026-27', 'ZZ Grade 8', 'ZZ-A', true, sectionx FROM f;
INSERT INTO sis_student_enrollments (organization_id, school_id, student_id, academic_year, class_name, section_name, is_current, section_id)
SELECT orga, scha, stub, '2026-27', 'ZZ Grade 8', 'ZZ-B', true, sy.sectiony FROM f, sy;
INSERT INTO teacher_assignments (organization_id, school_id, teacher_id, section_id, role)
SELECT orga, scha, teachert, sectionx, 'class_teacher' FROM f;

-- ══ PROBE 3 — teacherTeachesStudent (VERBATIM production SQL, branch (a)) ════
INSERT INTO r
SELECT 3, 'teacherTeachesStudent — teacher DOES teach StudentA (roster/section-FK)',
  CASE WHEN c>0 THEN 'PASS' ELSE 'FAIL' END,
  'links found = '||c::text||' (expect >0 => care alert ALLOWED)'
FROM (SELECT count(*) c FROM (
  SELECT 1 FROM sis_student_enrollments e
    JOIN teacher_assignments ta ON ta.section_id = e.section_id
     AND ta.organization_id = e.organization_id AND ta.school_id = e.school_id
   WHERE e.organization_id=(SELECT orga FROM f) AND e.school_id=(SELECT scha FROM f)
     AND e.student_id=(SELECT stua FROM f) AND e.is_current = true
     AND ta.teacher_id=(SELECT teachert FROM f)
) l) q;

INSERT INTO r
SELECT 4, 'teacherTeachesStudent — teacher does NOT teach StudentB (fails CLOSED)',
  CASE WHEN c=0 THEN 'PASS' ELSE 'FAIL' END,
  'links found = '||c::text||' (expect 0 => care alert DENIED for a student they do not teach)'
FROM (SELECT count(*) c FROM (
  SELECT 1 FROM sis_student_enrollments e
    JOIN teacher_assignments ta ON ta.section_id = e.section_id
     AND ta.organization_id = e.organization_id AND ta.school_id = e.school_id
   WHERE e.organization_id=(SELECT orga FROM f) AND e.school_id=(SELECT scha FROM f)
     AND e.student_id=(SELECT stub FROM f) AND e.is_current = true
     AND ta.teacher_id=(SELECT teachert FROM f)
) l) q;

-- ══ PROBE 4 — healthStaff role -> permissions resolution ═════════════════════
INSERT INTO r
SELECT 5, 'healthStaff role resolves to EXACTLY its 3 permissions',
  CASE WHEN perms = ARRAY['administerStudentMedication','manageStudentHealth','viewStudentHealthRecord']
       THEN 'PASS' ELSE 'FAIL' END,
  'role_permissions[healthStaff] = '||array_to_string(perms, ', ')
FROM (SELECT array_agg(permission_slug ORDER BY permission_slug) AS perms
      FROM role_permissions WHERE role_slug='healthStaff') x;

INSERT INTO r
SELECT 6, 'healthStaff must NOT hold viewStudentCareAlert-only teaching perms or any extra',
  CASE WHEN cnt=3 THEN 'PASS' ELSE 'FAIL' END,
  'total permissions granted to healthStaff = '||cnt::text||' (expect exactly 3 — no privilege creep)'
FROM (SELECT count(*) cnt FROM role_permissions WHERE role_slug='healthStaff') y;

INSERT INTO r
SELECT 7, 'viewStudentHealthRecord granted ONLY to healthStaff/principal/vicePrincipal (owner decision #1)',
  CASE WHEN roles = ARRAY['healthStaff','principal','vicePrincipal'] THEN 'PASS' ELSE 'FAIL' END,
  'roles holding viewStudentHealthRecord = '||array_to_string(roles, ', ')||'  (must exclude teacher/classTeacher/coordinator/officeStaff/schoolAdmin/management/superAdmin/org admins)'
FROM (SELECT array_agg(role_slug ORDER BY role_slug) AS roles
      FROM role_permissions WHERE permission_slug='viewStudentHealthRecord') z;

SELECT ord, probe, verdict, evidence FROM r ORDER BY ord;
ROLLBACK;
