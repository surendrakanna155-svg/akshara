\set ON_ERROR_STOP off
\pset pager off
BEGIN;
CREATE TEMP TABLE r(ord int, probe text, verdict text, evidence text);

-- ══ PROBE 4 (CORRECTED) — healthStaff permission set ═════════════════════════
-- Expectation corrected: the DESIGN grants healthStaff FOUR permissions — the 3
-- health-specific ones PLUS viewStudentCareAlert (health staff author the care
-- alerts, so they must read them). The earlier "expect exactly 3" assertion was
-- the PROBE's error, not a code defect.
INSERT INTO r
SELECT 1, 'healthStaff resolves to exactly its 4 DESIGNED permissions',
  CASE WHEN perms = ARRAY['administerStudentMedication','manageStudentHealth','viewStudentCareAlert','viewStudentHealthRecord']
       THEN 'PASS' ELSE 'FAIL' END,
  'role_permissions[healthStaff] = '||array_to_string(perms, ', ')
FROM (SELECT array_agg(permission_slug ORDER BY permission_slug) AS perms
      FROM role_permissions WHERE role_slug='healthStaff') x;

-- The security-critical half of owner decision #1: the CLINICAL perms are
-- healthStaff-only. This is what actually keeps teachers out.
INSERT INTO r
SELECT 2, 'manageStudentHealth granted ONLY to healthStaff',
  CASE WHEN roles = ARRAY['healthStaff'] THEN 'PASS' ELSE 'FAIL' END,
  'roles = '||array_to_string(roles, ', ')||' (expect healthStaff only)'
FROM (SELECT array_agg(role_slug ORDER BY role_slug) AS roles FROM role_permissions WHERE permission_slug='manageStudentHealth') a;

INSERT INTO r
SELECT 3, 'administerStudentMedication granted ONLY to healthStaff (separate gate from manage)',
  CASE WHEN roles = ARRAY['healthStaff'] THEN 'PASS' ELSE 'FAIL' END,
  'roles = '||array_to_string(roles, ', ')||' (expect healthStaff only)'
FROM (SELECT array_agg(role_slug ORDER BY role_slug) AS roles FROM role_permissions WHERE permission_slug='administerStudentMedication') b;

INSERT INTO r
SELECT 4, 'NO teaching/admin role holds viewStudentHealthRecord (owner decision #1)',
  CASE WHEN cnt=0 THEN 'PASS' ELSE 'FAIL' END,
  'teaching/admin roles holding the clinical record perm = '||cnt::text||' (expect 0)'
FROM (SELECT count(*) cnt FROM role_permissions
      WHERE permission_slug='viewStudentHealthRecord'
        AND role_slug IN ('teacher','classTeacher','coordinator','officeStaff','schoolAdmin','management','superAdmin','organizationOwner','organizationAdmin')) c;

-- ══ PROBE 5 — UNIQUE CONSTRAINTS (exception-trapped => explicit PASS) ════════
DO $$
DECLARE o uuid; s uuid; st uuid; u uuid;
BEGIN
  SELECT organization_id, id INTO o, s FROM schools ORDER BY id LIMIT 1;
  SELECT id INTO u FROM users ORDER BY id LIMIT 1;
  st := gen_random_uuid();
  INSERT INTO students (id, organization_id, school_id, student_code, display_name, status)
  VALUES (st, o, s, 'ZZ-UQ-1', 'ZZ UQ Student', 'active');

  BEGIN
    INSERT INTO gate_passes (organization_id, school_id, student_id, pass_type, requested_by, scheduled_at, status, reason)
    VALUES (o, s, st, 'early_pickup', u, '2026-08-01 10:00:00+00', 'pending', 'first');
    INSERT INTO gate_passes (organization_id, school_id, student_id, pass_type, requested_by, scheduled_at, status, reason)
    VALUES (o, s, st, 'early_pickup', u, '2026-08-01 10:00:00+00', 'pending', 'DUPLICATE');
    INSERT INTO r VALUES (5, 'uq_gate_passes_open_slot blocks a duplicate OPEN pass', 'FAIL', 'duplicate was ACCEPTED — two live pickup credentials could exist for one child+slot');
  EXCEPTION WHEN unique_violation THEN
    INSERT INTO r VALUES (5, 'uq_gate_passes_open_slot blocks a duplicate OPEN pass', 'PASS', 'Postgres raised unique_violation on the 2nd open pass for the same (org,school,student,scheduled_at) — constraint '||quote_literal(SQLERRM)||'');
  END;

  BEGIN
    INSERT INTO sis_certificate_requests (organization_id, school_id, student_id, certificate_type, purpose, status, requested_by)
    VALUES (o, s, st, 'bonafide', 'first', 'pending', u);
    INSERT INTO sis_certificate_requests (organization_id, school_id, student_id, certificate_type, purpose, status, requested_by)
    VALUES (o, s, st, 'bonafide', 'DUPLICATE', 'pending', u);
    INSERT INTO r VALUES (6, 'uq_sis_certificate_requests_open blocks a duplicate OPEN request', 'FAIL', 'duplicate was ACCEPTED');
  EXCEPTION WHEN unique_violation THEN
    INSERT INTO r VALUES (6, 'uq_sis_certificate_requests_open blocks a duplicate OPEN request', 'PASS', 'Postgres raised unique_violation on the 2nd open bonafide request — '||quote_literal(SQLERRM));
  END;
END $$;

-- ══ PROBE 6 — MONEY P0 #2: cancelInvoice LOCKSTEP + double-cancel guard ══════
DO $$
DECLARE o uuid; s uuid; u uuid; st uuid; fsid uuid; faid uuid;
        pre_out numeric; post_out numeric; post_total numeric;
        rel numeric; rows1 int; rows2 int; inv record;
BEGIN
  SELECT organization_id, id INTO o, s FROM schools ORDER BY id LIMIT 1;
  SELECT id INTO u FROM users ORDER BY id LIMIT 1;
  st := gen_random_uuid();
  INSERT INTO students (id, organization_id, school_id, student_code, display_name, status)
  VALUES (st, o, s, 'ZZ-M2-1', 'ZZ Money2 Student', 'active');
  INSERT INTO finance_fee_structures (id, organization_id, school_id, name, academic_year, status, created_by)
  VALUES (gen_random_uuid(), o, s, 'ZZ M2 Tuition', '2026-27', 'active', u) RETURNING id INTO fsid;
  INSERT INTO finance_fee_assignments (id, organization_id, school_id, student_id, fee_structure_id, academic_year, assignment_status, assigned_by)
  VALUES (gen_random_uuid(), o, s, st, fsid, '2026-27', 'active', u) RETURNING id INTO faid;
  -- account carries the raised invoice as a STORED aggregate
  INSERT INTO finance_student_accounts (organization_id, school_id, student_id, fee_assignment_id, academic_year, total_fee, amount_paid, outstanding_amount, status)
  VALUES (o, s, st, faid, '2026-27', 8000, 0, 8000, 'open');
  INSERT INTO finance_invoices (organization_id, school_id, student_id, fee_assignment_id, academic_year, invoice_number, due_date, subtotal_amount, discount_amount, total_amount, outstanding_amount, created_by)
  VALUES (o, s, st, faid, '2026-27', 'ZZ-M2-INV-1', CURRENT_DATE+30, 8000, 0, 8000, 8000, u);

  SELECT outstanding_amount INTO pre_out FROM finance_student_accounts WHERE student_id=st AND academic_year='2026-27';

  -- === the REAL production statements (verbatim from finance_invoices_repository.ts) ===
  UPDATE finance_invoices SET invoice_status='cancelled', updated_at=timezone('utc',now())
   WHERE invoice_number='ZZ-M2-INV-1' AND organization_id=o AND school_id=s
     AND invoice_status NOT IN ('paid','cancelled')
  RETURNING * INTO inv;
  GET DIAGNOSTICS rows1 = ROW_COUNT;
  rel := GREATEST(0, inv.outstanding_amount);
  UPDATE finance_student_accounts SET
      total_fee = GREATEST(0, total_fee - rel),
      outstanding_amount = GREATEST(0, outstanding_amount - rel),
      updated_at = timezone('utc', now())
   WHERE student_id=st AND academic_year='2026-27' AND organization_id=o AND school_id=s;

  SELECT outstanding_amount, total_fee INTO post_out, post_total FROM finance_student_accounts WHERE student_id=st AND academic_year='2026-27';

  INSERT INTO r VALUES (7, 'Money P0 #2 — cancelInvoice releases the account in LOCKSTEP', 
    CASE WHEN pre_out=8000 AND post_out=0 AND post_total=0 THEN 'PASS' ELSE 'FAIL' END,
    'account outstanding BEFORE cancel='||pre_out||' -> AFTER='||post_out||' (expect 0); total_fee after='||post_total||
    ' (expect 0). Without the lockstep the student stays a FALSE DEFAULTER and their no-dues/TC gate stays blocked.');

  -- === concurrent double-cancel: the guard must match 0 rows (no double-release) ===
  UPDATE finance_invoices SET invoice_status='cancelled', updated_at=timezone('utc',now())
   WHERE invoice_number='ZZ-M2-INV-1' AND organization_id=o AND school_id=s
     AND invoice_status NOT IN ('paid','cancelled');
  GET DIAGNOSTICS rows2 = ROW_COUNT;

  INSERT INTO r VALUES (8, 'Money P0 #2 — double-cancel guard (TOCTOU): 2nd cancel matches 0 rows',
    CASE WHEN rows1=1 AND rows2=0 THEN 'PASS' ELSE 'FAIL' END,
    '1st cancel matched '||rows1||' row (expect 1); 2nd cancel matched '||rows2||' rows (expect 0) => the release CANNOT be applied twice. The old unguarded read was TOCTOU: concurrent double-cancel double-released.');
END $$;

SELECT ord, probe, verdict, evidence FROM r ORDER BY ord;
ROLLBACK;
