\set ON_ERROR_STOP on
BEGIN;

-- PRC-A LIVE PROBE — the 2nd-fee-structure account-resolution P0 (commit 4bc1046b).
-- Seeds a real tuition + transport structure/assignment chain for ONE student,
-- then contrasts the OLD join with the NEW one. Everything is inside this
-- transaction and ROLLED BACK: nothing persists.
-- This is the JOIN semantics the backend fake DB structurally cannot evaluate.

CREATE TEMP TABLE probe_result(ord int, step text, detail text);

CREATE TEMP TABLE ctx AS
SELECT s.organization_id AS org, s.id AS school,
       (SELECT u.id FROM users u LIMIT 1) AS actor
FROM schools s LIMIT 1;

INSERT INTO students (id, organization_id, school_id, student_code, display_name, status)
SELECT gen_random_uuid(), org, school,
       'ZZ-PROBE-'||substr(gen_random_uuid()::text,1,8), 'ZZ_Probe Student', 'active'
FROM ctx;

CREATE TEMP TABLE stu AS
SELECT s.id AS student_id, s.organization_id AS org, s.school_id AS school, ctx.actor AS actor
FROM students s, ctx WHERE s.display_name = 'ZZ_Probe Student' ORDER BY s.created_at DESC LIMIT 1;

-- TWO fee structures: tuition (assigned FIRST) and transport (TRN-9, later).
INSERT INTO finance_fee_structures (id, organization_id, school_id, name, academic_year, status, created_by)
SELECT gen_random_uuid(), org, school, 'ZZ_Probe Tuition',   '2026-27', 'active', actor FROM stu;
INSERT INTO finance_fee_structures (id, organization_id, school_id, name, academic_year, status, created_by)
SELECT gen_random_uuid(), org, school, 'ZZ_Probe Transport', '2026-27', 'active', actor FROM stu;

CREATE TEMP TABLE fs AS
SELECT
  (SELECT id FROM finance_fee_structures WHERE name='ZZ_Probe Tuition'   ORDER BY created_at DESC LIMIT 1) AS tuition,
  (SELECT id FROM finance_fee_structures WHERE name='ZZ_Probe Transport' ORDER BY created_at DESC LIMIT 1) AS transport;

INSERT INTO finance_fee_assignments
  (id, organization_id, school_id, student_id, fee_structure_id, academic_year, assignment_status, assigned_by)
SELECT gen_random_uuid(), stu.org, stu.school, stu.student_id, fs.tuition,   '2026-27', 'active', stu.actor FROM stu, fs;
INSERT INTO finance_fee_assignments
  (id, organization_id, school_id, student_id, fee_structure_id, academic_year, assignment_status, assigned_by)
SELECT gen_random_uuid(), stu.org, stu.school, stu.student_id, fs.transport, '2026-27', 'active', stu.actor FROM stu, fs;

CREATE TEMP TABLE asg AS
SELECT
  (SELECT fa.id FROM finance_fee_assignments fa JOIN fs ON fa.fee_structure_id = fs.tuition   LIMIT 1) AS a1,
  (SELECT fa.id FROM finance_fee_assignments fa JOIN fs ON fa.fee_structure_id = fs.transport LIMIT 1) AS a2;

-- THE ACCOUNT: get-or-create at the FIRST assignment => fee_assignment_id frozen
-- to A1 forever. The table is UNIQUE (student_id, academic_year) => ONE account,
-- which TRN-9 reuses for the transport structure too.
INSERT INTO finance_student_accounts
  (organization_id, school_id, student_id, fee_assignment_id, academic_year,
   total_fee, amount_paid, outstanding_amount, status)
SELECT stu.org, stu.school, stu.student_id, asg.a1, '2026-27', 50000, 0, 50000, 'open' FROM stu, asg;

-- THE TRANSPORT INVOICE: carries A2, not A1.
INSERT INTO finance_invoices
  (organization_id, school_id, student_id, fee_assignment_id, academic_year,
   invoice_number, due_date, subtotal_amount, discount_amount, total_amount, outstanding_amount, created_by)
SELECT stu.org, stu.school, stu.student_id, asg.a2, '2026-27',
       'ZZ-PROBE-INV-'||substr(gen_random_uuid()::text,1,8), CURRENT_DATE + 30, 8000, 0, 8000, 8000, stu.actor
FROM stu, asg;

INSERT INTO probe_result
SELECT 1, 'Premise', 'ONE account per (student, academic_year); its fee_assignment_id is frozen to the FIRST assignment (A1=tuition). The transport invoice carries A2.';

-- OLD (BROKEN) join — keyed on fee_assignment_id.
INSERT INTO probe_result
SELECT 2, 'OLD join  fsa.fee_assignment_id = fi.fee_assignment_id',
       'rows = '||count(*)::text||CASE WHEN count(*)=0
         THEN '   <== P0 REPRODUCED ON REAL POSTGRES: the transport invoice resolves to NO account (payment not collectible, late fee silently never accrues, concession 422)'
         ELSE '   <== unexpected' END
FROM finance_student_accounts fsa
JOIN finance_invoices fi ON fsa.fee_assignment_id = fi.fee_assignment_id
WHERE fi.invoice_number LIKE 'ZZ-PROBE-INV-%';

-- NEW (FIXED) join — keyed on the real business key.
INSERT INTO probe_result
SELECT 3, 'NEW join  student_id + academic_year',
       'rows = '||count(*)::text||CASE WHEN count(*)=1
         THEN '   <== FIX CONFIRMED ON REAL POSTGRES: the transport invoice resolves to the student''s account'
         ELSE '   <== unexpected' END
FROM finance_student_accounts fsa
JOIN finance_invoices fi
  ON fsa.student_id = fi.student_id AND fsa.academic_year = fi.academic_year
WHERE fi.invoice_number LIKE 'ZZ-PROBE-INV-%';

SELECT step, detail FROM probe_result ORDER BY ord;

ROLLBACK;
