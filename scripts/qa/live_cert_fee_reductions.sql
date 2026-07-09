-- finance_fee_reductions LIVE CERT (non-destructive) — akshara_tenant_test.
-- Everything runs inside ONE transaction that is ROLLED BACK; nothing persists.
\set ON_ERROR_STOP on
\set org        '''a1000000-0000-4000-8000-000000000001'''
\set school     '''a2000000-0000-4000-8000-000000000002'''
\set otherschool '''a2000000-0000-4000-8000-000000000001'''
\set student    '''a4000000-0000-4000-8000-000000000002'''
\set invoice    '''b9000000-0000-4000-8000-000000000002'''
\set account    '''b8100000-0000-4000-8000-000000000002'''
\set sch         '''135f8c43-0572-41d3-9d04-80a987551600'''
\set disc        '''5d706a5a-844f-43e7-806c-39f0336d07fe'''
\set maker      '''a3000000-0000-4000-8000-000000000001'''
\set seed       '''cafe0000-0000-4000-8000-000000000001'''

BEGIN;

-- Seed one VALID pending scholarship reduction as postgres (RLS bypassed on seed).
INSERT INTO finance_fee_reductions
  (id, organization_id, school_id, source_kind, scholarship_id, student_id,
   invoice_id, student_account_id, reduction_kind, percent, status, created_by)
VALUES
  (:seed, :org, :school, 'scholarship', :sch, :student,
   :invoice, :account, 'percent', 10, 'pending', :maker);

-- ── C1 · RLS school-scope (run AS erp_tenant; postgres bypasses RLS) ──────────
SET LOCAL ROLE erp_tenant;
SELECT set_config('app.tenant_id', 'a1000000-0000-4000-8000-000000000001', true);
SELECT set_config('app.scope',     'school', true);
SELECT set_config('app.school_id', 'a2000000-0000-4000-8000-000000000002', true);
SELECT 'C1a same-school/school-scope (expect 1)' AS probe, count(*) AS rows
  FROM finance_fee_reductions WHERE id = :seed;
SELECT set_config('app.school_id', 'a2000000-0000-4000-8000-000000000001', true);
SELECT 'C1b other-school (expect 0)' AS probe, count(*) AS rows
  FROM finance_fee_reductions WHERE id = :seed;
SELECT set_config('app.school_id', 'a2000000-0000-4000-8000-000000000002', true);
SELECT set_config('app.scope',     'parent', true);
SELECT 'C1c parent-scope (expect 0)' AS probe, count(*) AS rows
  FROM finance_fee_reductions WHERE id = :seed;
RESET ROLE;

-- ── C2/C3 · CHECK + partial-unique guardrails (each MUST raise) ───────────────
DO $$
BEGIN
  -- each nested block expects a specific SQLSTATE (check/unique violation)
  -- C2.1 source_ck: scholarship kind but discount_rule_id also set
  BEGIN
    INSERT INTO finance_fee_reductions(organization_id,school_id,source_kind,scholarship_id,discount_rule_id,student_id,invoice_id,student_account_id,reduction_kind,percent,status,created_by)
    VALUES ('a1000000-0000-4000-8000-000000000001','a2000000-0000-4000-8000-000000000002','scholarship','135f8c43-0572-41d3-9d04-80a987551600','5d706a5a-844f-43e7-806c-39f0336d07fe','a4000000-0000-4000-8000-000000000002','b9000000-0000-4000-8000-000000000002','b8100000-0000-4000-8000-000000000002','percent',10,'pending','a3000000-0000-4000-8000-000000000001');
    RAISE WARNING 'C2.1 source_ck: FAIL (insert allowed)';
  EXCEPTION WHEN check_violation THEN RAISE NOTICE 'C2.1 source_ck: PASS'; END;

  -- C2.2 value_ck: percent = 0
  BEGIN
    INSERT INTO finance_fee_reductions(organization_id,school_id,source_kind,scholarship_id,student_id,invoice_id,student_account_id,reduction_kind,percent,status,created_by)
    VALUES ('a1000000-0000-4000-8000-000000000001','a2000000-0000-4000-8000-000000000002','scholarship','135f8c43-0572-41d3-9d04-80a987551600','a4000000-0000-4000-8000-000000000002','b9000000-0000-4000-8000-000000000002','b8100000-0000-4000-8000-000000000002','percent',0,'pending','a3000000-0000-4000-8000-000000000001');
    RAISE WARNING 'C2.2 value_ck percent=0: FAIL (insert allowed)';
  EXCEPTION WHEN check_violation THEN RAISE NOTICE 'C2.2 value_ck percent=0: PASS'; END;

  -- C2.3 value_ck: percent = 150 (>100)
  BEGIN
    INSERT INTO finance_fee_reductions(organization_id,school_id,source_kind,scholarship_id,student_id,invoice_id,student_account_id,reduction_kind,percent,status,created_by)
    VALUES ('a1000000-0000-4000-8000-000000000001','a2000000-0000-4000-8000-000000000002','scholarship','135f8c43-0572-41d3-9d04-80a987551600','a4000000-0000-4000-8000-000000000002','b9000000-0000-4000-8000-000000000002','b8100000-0000-4000-8000-000000000002','percent',150,'pending','a3000000-0000-4000-8000-000000000001');
    RAISE WARNING 'C2.3 value_ck percent=150: FAIL (insert allowed)';
  EXCEPTION WHEN check_violation THEN RAISE NOTICE 'C2.3 value_ck percent=150: PASS'; END;

  -- C2.4 value_ck: both percent and fixed_amount set
  BEGIN
    INSERT INTO finance_fee_reductions(organization_id,school_id,source_kind,scholarship_id,student_id,invoice_id,student_account_id,reduction_kind,percent,fixed_amount,status,created_by)
    VALUES ('a1000000-0000-4000-8000-000000000001','a2000000-0000-4000-8000-000000000002','scholarship','135f8c43-0572-41d3-9d04-80a987551600','a4000000-0000-4000-8000-000000000002','b9000000-0000-4000-8000-000000000002','b8100000-0000-4000-8000-000000000002','percent',10,500,'pending','a3000000-0000-4000-8000-000000000001');
    RAISE WARNING 'C2.4 value_ck both set: FAIL (insert allowed)';
  EXCEPTION WHEN check_violation THEN RAISE NOTICE 'C2.4 value_ck both set: PASS'; END;

  -- C2.5 applied_nonneg_ck: applied_amount = -1
  BEGIN
    INSERT INTO finance_fee_reductions(organization_id,school_id,source_kind,scholarship_id,student_id,invoice_id,student_account_id,reduction_kind,percent,applied_amount,status,created_by)
    VALUES ('a1000000-0000-4000-8000-000000000001','a2000000-0000-4000-8000-000000000002','scholarship','135f8c43-0572-41d3-9d04-80a987551600','a4000000-0000-4000-8000-000000000002','b9000000-0000-4000-8000-000000000002','b8100000-0000-4000-8000-000000000002','percent',10,-1,'pending','a3000000-0000-4000-8000-000000000001');
    RAISE WARNING 'C2.5 applied_nonneg_ck: FAIL (insert allowed)';
  EXCEPTION WHEN check_violation THEN RAISE NOTICE 'C2.5 applied_nonneg_ck: PASS'; END;

  -- C3 partial-unique: 2nd LIVE reduction for same (invoice, scholarship)
  BEGIN
    INSERT INTO finance_fee_reductions(organization_id,school_id,source_kind,scholarship_id,student_id,invoice_id,student_account_id,reduction_kind,percent,status,created_by)
    VALUES ('a1000000-0000-4000-8000-000000000001','a2000000-0000-4000-8000-000000000002','scholarship','135f8c43-0572-41d3-9d04-80a987551600','a4000000-0000-4000-8000-000000000002','b9000000-0000-4000-8000-000000000002','b8100000-0000-4000-8000-000000000002','percent',20,'pending','a3000000-0000-4000-8000-000000000001');
    RAISE WARNING 'C3 partial-unique 2nd-live: FAIL (insert allowed)';
  EXCEPTION WHEN unique_violation THEN RAISE NOTICE 'C3 partial-unique 2nd-live: PASS'; END;

  -- C3b partial predicate: a REVERSED duplicate is allowed (does not block)
  BEGIN
    INSERT INTO finance_fee_reductions(organization_id,school_id,source_kind,scholarship_id,student_id,invoice_id,student_account_id,reduction_kind,percent,status,created_by)
    VALUES ('a1000000-0000-4000-8000-000000000001','a2000000-0000-4000-8000-000000000002','scholarship','135f8c43-0572-41d3-9d04-80a987551600','a4000000-0000-4000-8000-000000000002','b9000000-0000-4000-8000-000000000002','b8100000-0000-4000-8000-000000000002','percent',20,'reversed','a3000000-0000-4000-8000-000000000001');
    RAISE NOTICE 'C3b reversed-duplicate allowed: PASS';
  EXCEPTION WHEN unique_violation THEN RAISE WARNING 'C3b reversed-duplicate: FAIL (blocked)'; END;
END $$;

ROLLBACK;
SELECT 'ROLLED BACK — nothing persisted' AS cleanup;
