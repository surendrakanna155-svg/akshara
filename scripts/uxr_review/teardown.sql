-- ============================================================================
-- UX REVIEW DEMO TEARDOWN  (Akshara ERP)
-- ----------------------------------------------------------------------------
-- Removes every row created by seed.sql. Deletes by sentinel id (precise) with
-- a marker-based safety net. Reused container rows (org/school/year/class/
-- section) and all pre-existing data are left untouched.
-- TARGET: `akshara_tenant_test` ONLY.
-- Idempotent: safe to run repeatedly.
-- ============================================================================

\set ON_ERROR_STOP on

DO $$
BEGIN
  IF current_database() <> 'akshara_tenant_test' THEN
    RAISE EXCEPTION 'REFUSING TO TEARDOWN: current_database()=% (expected akshara_tenant_test).', current_database();
  END IF;
END $$;

BEGIN;

-- child rows first (reverse FK order)
DELETE FROM teacher_subject_assignments WHERE id = 'de7f0000-0000-4000-8000-000000000001';
DELETE FROM class_subject_assignments   WHERE id = 'de8f0000-0000-4000-8000-000000000001';
DELETE FROM student_guardians           WHERE id = 'de4f0000-0000-4000-8000-000000000004';
DELETE FROM sis_student_enrollments     WHERE id = 'de4f0000-0000-4000-8000-000000000003';
DELETE FROM student_profiles            WHERE id = 'de4f0000-0000-4000-8000-000000000002';
DELETE FROM students                    WHERE id = 'de4f0000-0000-4000-8000-000000000001';
DELETE FROM academic_subjects           WHERE id = 'de2f0000-0000-4000-8000-000000000001';

DELETE FROM school_membership_roles
  WHERE school_membership_id IN (
    'de5f0000-0000-4000-8000-000000000001','de5f0000-0000-4000-8000-000000000002',
    'de5f0000-0000-4000-8000-000000000003','de5f0000-0000-4000-8000-000000000004',
    'de5f0000-0000-4000-8000-000000000005','de5f0000-0000-4000-8000-000000000006');
DELETE FROM school_memberships
  WHERE id IN (
    'de5f0000-0000-4000-8000-000000000001','de5f0000-0000-4000-8000-000000000002',
    'de5f0000-0000-4000-8000-000000000003','de5f0000-0000-4000-8000-000000000004',
    'de5f0000-0000-4000-8000-000000000005','de5f0000-0000-4000-8000-000000000006');
DELETE FROM organization_memberships WHERE id = 'de6f0000-0000-4000-8000-000000000001';

DELETE FROM users WHERE id IN (
  'de3f0000-0000-4000-8000-000000000001','de3f0000-0000-4000-8000-000000000002',
  'de3f0000-0000-4000-8000-000000000003','de3f0000-0000-4000-8000-000000000004',
  'de3f0000-0000-4000-8000-000000000005','de3f0000-0000-4000-8000-000000000006',
  'de3f0000-0000-4000-8000-000000000007','de3f0000-0000-4000-8000-000000000008');

-- safety net: catch anything tagged with the demo markers that escaped the ids
DELETE FROM student_guardians       WHERE guardian_user_id IN (SELECT id FROM users WHERE email LIKE '%@uxreview.demo');
DELETE FROM teacher_subject_assignments WHERE teacher_user_id IN (SELECT id FROM users WHERE email LIKE '%@uxreview.demo');
DELETE FROM school_membership_roles WHERE school_membership_id IN (SELECT id FROM school_memberships WHERE member_display_name LIKE 'UXR %');
DELETE FROM school_memberships      WHERE member_display_name LIKE 'UXR %';
DELETE FROM organization_memberships WHERE user_id IN (SELECT id FROM users WHERE email LIKE '%@uxreview.demo');
DELETE FROM academic_subjects       WHERE subject_code = 'UXR-ENG';
DELETE FROM users                   WHERE email LIKE '%@uxreview.demo' OR phone LIKE '+9199001000%';

COMMIT;

\echo '--- Remaining UXR rows (should be zero) ---'
SELECT count(*) AS remaining_uxr_users FROM users WHERE email LIKE '%@uxreview.demo' OR phone LIKE '+9199001000%';
