-- ============================================================================
-- UX REVIEW DEMO SEED  (Akshara ERP — temporary, reversible)
-- ----------------------------------------------------------------------------
-- Creates ONE login-able account per role for a manual UI/UX review, linked
-- into the existing (proven) staging school so every dashboard resolves.
--
-- TARGET: database `akshara_tenant_test` ONLY (the isolated VPS test tenant).
--         This script must NEVER run against production `akshara_db`.
-- CONTAINER (reused, never modified/deleted):
--   org    a1000000-0000-4000-8000-000000000001  (Akshara Staging Organization)
--   school a2000000-0000-4000-8000-000000000001  (Akshara Staging School)
--   year   ce100000-0000-4000-8000-000000000001  (2026-27, current)
--   class5 cf100000-0000-4000-8000-000000000001 / section A d0100000-0000-4000-8000-000000000001
--
-- All rows created here use the sentinel prefix `de..0000-...` and the markers
--   email  LIKE '%@uxreview.demo'   phone LIKE '+9199001000%'   name  LIKE 'UXR %'
-- so teardown.sql can remove them precisely with zero risk to existing data.
--
-- Idempotent: safe to re-run (ON CONFLICT DO NOTHING).
-- Owner phone is passed in:  psql -v owner_phone="+91XXXXXXXXXX"
-- ============================================================================

\set ON_ERROR_STOP on

-- Hard guard: refuse to run anywhere but the test tenant.
DO $$
BEGIN
  IF current_database() <> 'akshara_tenant_test' THEN
    RAISE EXCEPTION 'REFUSING TO SEED: current_database()=% (expected akshara_tenant_test). This demo seed must never touch production.', current_database();
  END IF;
END $$;

-- Default owner phone if the caller did not pass one (placeholder until provided).
\if :{?owner_phone}
\else
  \set owner_phone '+919900100001'
\endif

BEGIN;

-- ---------------------------------------------------------------------------
-- 1) USERS (public.users) — 8 accounts
-- ---------------------------------------------------------------------------
INSERT INTO users (id, phone, email, display_name) VALUES
  ('de3f0000-0000-4000-8000-000000000001', :'owner_phone', 'owner@uxreview.demo',     'UXR Owner (Super Admin)'),
  ('de3f0000-0000-4000-8000-000000000002', '+919900100002', 'principal@uxreview.demo', 'UXR Principal'),
  ('de3f0000-0000-4000-8000-000000000003', '+919900100003', 'teacher@uxreview.demo',   'UXR Teacher'),
  ('de3f0000-0000-4000-8000-000000000004', '+919900100004', 'finance@uxreview.demo',   'UXR Finance'),
  ('de3f0000-0000-4000-8000-000000000005', '+919900100005', 'hr@uxreview.demo',        'UXR HR Manager'),
  ('de3f0000-0000-4000-8000-000000000006', '+919900100006', 'office@uxreview.demo',    'UXR Office Staff'),
  ('de3f0000-0000-4000-8000-000000000007', '+919900100007', 'parent@uxreview.demo',    'UXR Parent'),
  ('de3f0000-0000-4000-8000-000000000008', '+919900100008', 'student@uxreview.demo',   'UXR Student')
ON CONFLICT (id) DO NOTHING;

-- ---------------------------------------------------------------------------
-- 2) OWNER — organization owner + school super admin
-- ---------------------------------------------------------------------------
INSERT INTO organization_memberships (id, user_id, organization_id, role) VALUES
  ('de6f0000-0000-4000-8000-000000000001', 'de3f0000-0000-4000-8000-000000000001',
   'a1000000-0000-4000-8000-000000000001', 'organizationOwner')
ON CONFLICT (id) DO NOTHING;

-- ---------------------------------------------------------------------------
-- 3) STAFF SCHOOL MEMBERSHIPS (owner + principal + teacher + finance + hr + office)
--    legacy .role column AND school_membership_roles.role_slug are both set,
--    matching how the edge resolves primaryRole / role_slugs.
-- ---------------------------------------------------------------------------
INSERT INTO school_memberships (id, user_id, school_id, role, member_display_name) VALUES
  ('de5f0000-0000-4000-8000-000000000001', 'de3f0000-0000-4000-8000-000000000001', 'a2000000-0000-4000-8000-000000000001', 'superAdmin',   'UXR Owner (Super Admin)'),
  ('de5f0000-0000-4000-8000-000000000002', 'de3f0000-0000-4000-8000-000000000002', 'a2000000-0000-4000-8000-000000000001', 'principal',    'UXR Principal'),
  ('de5f0000-0000-4000-8000-000000000003', 'de3f0000-0000-4000-8000-000000000003', 'a2000000-0000-4000-8000-000000000001', 'teacher',      'UXR Teacher'),
  ('de5f0000-0000-4000-8000-000000000004', 'de3f0000-0000-4000-8000-000000000004', 'a2000000-0000-4000-8000-000000000001', 'financeAdmin', 'UXR Finance'),
  ('de5f0000-0000-4000-8000-000000000005', 'de3f0000-0000-4000-8000-000000000005', 'a2000000-0000-4000-8000-000000000001', 'hrManager',    'UXR HR Manager'),
  ('de5f0000-0000-4000-8000-000000000006', 'de3f0000-0000-4000-8000-000000000006', 'a2000000-0000-4000-8000-000000000001', 'officeStaff',  'UXR Office Staff')
ON CONFLICT (id) DO NOTHING;

INSERT INTO school_membership_roles (school_membership_id, role_slug, is_primary) VALUES
  ('de5f0000-0000-4000-8000-000000000001', 'superAdmin',   true),
  ('de5f0000-0000-4000-8000-000000000002', 'principal',    true),
  ('de5f0000-0000-4000-8000-000000000003', 'teacher',      true),
  ('de5f0000-0000-4000-8000-000000000004', 'financeAdmin', true),
  ('de5f0000-0000-4000-8000-000000000005', 'hrManager',    true),
  ('de5f0000-0000-4000-8000-000000000006', 'officeStaff',  true)
ON CONFLICT DO NOTHING;

-- ---------------------------------------------------------------------------
-- 4) TEACHER assignment — subject + class 5 / section A
-- ---------------------------------------------------------------------------
INSERT INTO academic_subjects (id, organization_id, school_id, subject_code, subject_name, category) VALUES
  ('de2f0000-0000-4000-8000-000000000001', 'a1000000-0000-4000-8000-000000000001',
   'a2000000-0000-4000-8000-000000000001', 'UXR-ENG', 'English (UXR Demo)', 'core')
ON CONFLICT (id) DO NOTHING;

INSERT INTO teacher_subject_assignments
  (id, organization_id, school_id, academic_year_id, teacher_user_id, subject_id, class_id, section_id, periods_per_week, is_primary) VALUES
  ('de7f0000-0000-4000-8000-000000000001', 'a1000000-0000-4000-8000-000000000001',
   'a2000000-0000-4000-8000-000000000001', 'ce100000-0000-4000-8000-000000000001',
   'de3f0000-0000-4000-8000-000000000003', 'de2f0000-0000-4000-8000-000000000001',
   'cf100000-0000-4000-8000-000000000001', 'd0100000-0000-4000-8000-000000000001', 5, true)
ON CONFLICT (id) DO NOTHING;

-- also register the subject as taught in class 5A (some class-centric views read this)
INSERT INTO class_subject_assignments
  (id, organization_id, school_id, academic_year_id, class_id, section_id, subject_id, periods_per_week) VALUES
  ('de8f0000-0000-4000-8000-000000000001', 'a1000000-0000-4000-8000-000000000001',
   'a2000000-0000-4000-8000-000000000001', 'ce100000-0000-4000-8000-000000000001',
   'cf100000-0000-4000-8000-000000000001', 'd0100000-0000-4000-8000-000000000001',
   'de2f0000-0000-4000-8000-000000000001', 5)
ON CONFLICT (id) DO NOTHING;

-- ---------------------------------------------------------------------------
-- 5) STUDENT (login-able) + profile + class-5A enrollment
-- ---------------------------------------------------------------------------
INSERT INTO students (id, organization_id, school_id, user_id, student_code, display_name) VALUES
  ('de4f0000-0000-4000-8000-000000000001', 'a1000000-0000-4000-8000-000000000001',
   'a2000000-0000-4000-8000-000000000001', 'de3f0000-0000-4000-8000-000000000008',
   'UXR-2026-0001', 'UXR Student')
ON CONFLICT (id) DO NOTHING;

INSERT INTO student_profiles (id, organization_id, school_id, student_id, admission_number, date_of_birth, gender, public_student_id) VALUES
  ('de4f0000-0000-4000-8000-000000000002', 'a1000000-0000-4000-8000-000000000001',
   'a2000000-0000-4000-8000-000000000001', 'de4f0000-0000-4000-8000-000000000001',
   'UXR-2026-0001', DATE '2015-06-15', 'male', 'UXR-0001')
ON CONFLICT (id) DO NOTHING;

INSERT INTO sis_student_enrollments
  (id, organization_id, school_id, student_id, academic_year, class_name, section_name, roll_number, is_current, academic_year_id, class_id, section_id) VALUES
  ('de4f0000-0000-4000-8000-000000000003', 'a1000000-0000-4000-8000-000000000001',
   'a2000000-0000-4000-8000-000000000001', 'de4f0000-0000-4000-8000-000000000001',
   '2026-27', '5', 'A', '1', true,
   'ce100000-0000-4000-8000-000000000001', 'cf100000-0000-4000-8000-000000000001', 'd0100000-0000-4000-8000-000000000001')
ON CONFLICT (id) DO NOTHING;

-- ---------------------------------------------------------------------------
-- 6) PARENT — guardian link to the demo student
-- ---------------------------------------------------------------------------
INSERT INTO student_guardians (id, organization_id, school_id, student_id, guardian_user_id, relationship, is_primary) VALUES
  ('de4f0000-0000-4000-8000-000000000004', 'a1000000-0000-4000-8000-000000000001',
   'a2000000-0000-4000-8000-000000000001', 'de4f0000-0000-4000-8000-000000000001',
   'de3f0000-0000-4000-8000-000000000007', 'father', true)
ON CONFLICT (id) DO NOTHING;

COMMIT;

-- ---------------------------------------------------------------------------
-- Summary
-- ---------------------------------------------------------------------------
\echo '--- UXR demo accounts now present ---'
SELECT u.display_name, u.phone, COALESCE(smr.role_slug, sg_role.r, st_role.r) AS role
FROM users u
LEFT JOIN school_memberships sm ON sm.user_id = u.id
LEFT JOIN school_membership_roles smr ON smr.school_membership_id = sm.id
LEFT JOIN (SELECT guardian_user_id, 'parent'::text r FROM student_guardians WHERE id='de4f0000-0000-4000-8000-000000000004') sg_role ON sg_role.guardian_user_id = u.id
LEFT JOIN (SELECT user_id, 'student'::text r FROM students WHERE id='de4f0000-0000-4000-8000-000000000001') st_role ON st_role.user_id = u.id
WHERE u.email LIKE '%@uxreview.demo'
ORDER BY u.display_name;
