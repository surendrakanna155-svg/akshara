-- WEB-005 (ERP-WT-005) LIVE CERT — registrar class-management workflows.
-- Proves the DB operations the handlers depend on, as the REAL erp_tenant role,
-- inside BEGIN..ROLLBACK (ZERO residue). The TS per-row savepoint orchestration
-- is covered by the deno suite; this proves what the fake DB cannot: the
-- enrollment INSERT/UPDATE grants, the UNIQUE(student_id, academic_year)
-- idempotency constraint, and RLS WITH CHECK isolation on WRITES.
-- Seed: School1 a2..01, students a4..01 + d2a75864 both current 2026-27/5/A.
\pset pager off
\set ORG  '''a1000000-0000-4000-8000-000000000001'''
\set SCH1 '''a2000000-0000-4000-8000-000000000001'''
\set SCH2 '''a2000000-0000-4000-8000-000000000002'''
\set USR  '''00000000-0000-4000-8000-0000000000aa'''
\set STU1 '''a4000000-0000-4000-8000-000000000001'''
\set STU2 '''d2a75864-c7eb-47a0-8586-1991a09a1917'''

BEGIN;
CREATE TEMP TABLE res(probe text, detail text, pass boolean) ON COMMIT DROP;
GRANT INSERT, SELECT ON res TO erp_tenant;
SET ROLE erp_tenant;

SELECT set_request_context(:ORG::uuid, 'school', :USR::uuid, :SCH1::uuid);

DO $$
DECLARE
  v_org uuid := 'a1000000-0000-4000-8000-000000000001';
  v_sch uuid := 'a2000000-0000-4000-8000-000000000001';
  v_stu uuid := 'a4000000-0000-4000-8000-000000000001';
  v_stu2 uuid := 'd2a75864-c7eb-47a0-8586-1991a09a1917';
  v_cleared int;
  v_current int;
  v_moved int;
  v_dup boolean := false;
BEGIN
  -- PROMOTION step 1: clear the student's current enrollment (as createEnrollment does).
  UPDATE sis_student_enrollments SET is_current = false, updated_at = now()
   WHERE organization_id = v_org AND school_id = v_sch AND student_id = v_stu AND is_current = true;
  GET DIAGNOSTICS v_cleared = ROW_COUNT;
  INSERT INTO res VALUES ('WEB005 P1 clear-current updates the old enrollment', 'rows=' || v_cleared, v_cleared = 1);

  -- PROMOTION step 2: insert the next-year enrollment.
  INSERT INTO sis_student_enrollments
    (organization_id, school_id, student_id, academic_year, class_name, section_name, is_current, created_by)
  VALUES (v_org, v_sch, v_stu, '2027-28', '6', 'A', true, NULL);
  INSERT INTO res VALUES ('WEB005 P2 next-year enrollment inserts (INSERT+RLS grant)', 'inserted', true);

  -- PROMOTION invariant: student now has exactly one current enrollment = the new year.
  SELECT count(*) INTO v_current FROM sis_student_enrollments
   WHERE organization_id = v_org AND school_id = v_sch AND student_id = v_stu AND is_current = true;
  INSERT INTO res VALUES ('WEB005 P3 exactly one current enrollment after promote', 'current=' || v_current, v_current = 1);

  -- IDEMPOTENCY: a second promote to the SAME year hits UNIQUE(student_id, academic_year).
  BEGIN
    INSERT INTO sis_student_enrollments
      (organization_id, school_id, student_id, academic_year, class_name, section_name, is_current, created_by)
    VALUES (v_org, v_sch, v_stu, '2027-28', '6', 'A', true, NULL);
  EXCEPTION WHEN unique_violation THEN
    v_dup := true;
  END;
  INSERT INTO res VALUES ('WEB005 P4 duplicate year blocked by UNIQUE (idempotency)', 'unique_violation=' || v_dup, v_dup);

  -- RESHUFFLE: move the OTHER student''s current section A -> B.
  UPDATE sis_student_enrollments SET section_name = 'B', updated_at = now()
   WHERE organization_id = v_org AND school_id = v_sch AND student_id = v_stu2 AND is_current = true;
  GET DIAGNOSTICS v_moved = ROW_COUNT;
  INSERT INTO res VALUES ('WEB005 P5 reshuffle updates current section', 'rows=' || v_moved, v_moved = 1);
END $$;

-- ACADEMIC-ASSIGNMENT: current roster join resolves (is_current filter + students join).
INSERT INTO res
SELECT 'WEB005 P6 academic-assignment roster query resolves', 'rows=' || count(*), count(*) >= 2
FROM (
  SELECT se.id, se.class_name, se.section_name, se.roll_number, s.display_name
  FROM sis_student_enrollments se
  LEFT JOIN students s ON s.id = se.student_id AND s.organization_id = se.organization_id AND s.school_id = se.school_id
  WHERE se.organization_id = :ORG::uuid AND se.school_id = :SCH1::uuid AND se.is_current = true
) q;

-- RLS isolation on WRITES: School 2 context cannot insert a School 1 enrollment.
SELECT set_request_context(:ORG::uuid, 'school', :USR::uuid, :SCH2::uuid);
DO $$
DECLARE v_blocked boolean := false;
BEGIN
  BEGIN
    INSERT INTO sis_student_enrollments
      (organization_id, school_id, student_id, academic_year, class_name, is_current, created_by)
    VALUES ('a1000000-0000-4000-8000-000000000001', 'a2000000-0000-4000-8000-000000000001',
            'a4000000-0000-4000-8000-000000000001', '2099-00', '6', true, NULL);
  EXCEPTION WHEN OTHERS THEN
    v_blocked := true;
  END;
  INSERT INTO res VALUES ('WEB005 P7 RLS WITH CHECK blocks cross-school write', 'blocked=' || v_blocked, v_blocked);
END $$;
INSERT INTO res
SELECT 'WEB005 P8 School2 ctx reads 0 School1 enrollments', 'rows=' || count(*), count(*) = 0
FROM sis_student_enrollments WHERE organization_id = :ORG::uuid AND school_id = :SCH1::uuid;

RESET ROLE;
SELECT probe, detail, CASE WHEN pass THEN 'PASS' ELSE 'FAIL' END AS verdict FROM res ORDER BY probe;
SELECT count(*) FILTER (WHERE pass) AS passed, count(*) FILTER (WHERE NOT pass) AS failed, count(*) AS total FROM res;
ROLLBACK;
