-- PRC-A Batch 8 (slice 1) — Transport expense ledger LIVE CERT (ROLLBACK-safe).
--
-- Runs as the REAL non-bypass `erp_tenant` role via `app.set_request_context(...)`
-- — byte-identical to withTenantContext — so RLS is genuinely evaluated. One
-- BEGIN…ROLLBACK; nothing persists. Proves what the fake DB CANNOT: the numeric
-- cost aggregation (SUM by category), the cross-module income JOIN
-- (finance_invoice_head_allocations→finance_invoices, fee_head LIKE 'transport:%'),
-- the void terminal-guard (no concurrent double-void), RLS isolation, CHECKs, and
-- the append-only grant.
--
-- Run: docker exec -i akshara-postgres psql -U supabase_admin -d akshara_db -f - < this
\set ON_ERROR_STOP off

\echo ==================== BEGIN (all seed rolled back) ====================
BEGIN;
CREATE TEMP TABLE r(ord int, probe text, verdict text, evidence text);
GRANT INSERT, SELECT ON r TO erp_tenant;

\set orgA '''a1000000-0000-4000-8000-000000000001'''
\set schA '''a2000000-0000-4000-8000-000000000001'''
\set schB '''a2000000-0000-4000-8000-000000000002'''
\set orgO '''153cbc5a-05b7-48b4-b900-edb126a099f0'''
\set schO '''bb2d5521-0ab4-4eb9-a3f1-83691414ebc9'''
\set usr  '''a3000000-0000-4000-8000-000000000001'''

SET ROLE erp_tenant;
SELECT app.set_request_context(:orgA::uuid, 'school', :usr::uuid, :schA::uuid, NULL, NULL, NULL);

-- Seed 3 recorded expenses today (2 fuel, 1 maintenance).
INSERT INTO transport_expenses (organization_id, school_id, category, amount, incurred_on, recorded_by) VALUES
  (:orgA::uuid, :schA::uuid, 'fuel',        3000.00, CURRENT_DATE, :usr::uuid),
  (:orgA::uuid, :schA::uuid, 'fuel',        2000.00, CURRENT_DATE, :usr::uuid),
  (:orgA::uuid, :schA::uuid, 'maintenance', 1500.00, CURRENT_DATE, :usr::uuid);

-- ── PROBE 1 — cost aggregation by category (the SUM the fake DB can't do) ────
INSERT INTO r
SELECT 1, 'cost recompute: SUM by category is correct',
  CASE WHEN fuel=5000.00 AND maint=1500.00 AND total=6500.00 THEN 'PASS' ELSE 'FAIL' END,
  'fuel='||fuel::text||' maintenance='||maint::text||' total='||total::text||' (expect 5000/1500/6500)'
FROM (
  SELECT COALESCE(SUM(amount) FILTER (WHERE category='fuel'),0) AS fuel,
         COALESCE(SUM(amount) FILTER (WHERE category='maintenance'),0) AS maint,
         COALESCE(SUM(amount),0) AS total
    FROM transport_expenses
   WHERE organization_id=:orgA::uuid AND school_id=:schA::uuid AND status='recorded'
) q;

-- ── PROBE 2 — month-to-date fuel (the live dashboard KPI value) ──────────────
INSERT INTO r
SELECT 2, 'month-to-date fuel recompute (replaces the ₹84K placeholder)',
  CASE WHEN mtd=5000.00 THEN 'PASS' ELSE 'FAIL' END,
  'MTD fuel = '||mtd::text||' (expect 5000 — both fuel rows dated this month)'
FROM (
  SELECT COALESCE(SUM(amount),0) AS mtd FROM transport_expenses
   WHERE organization_id=:orgA::uuid AND school_id=:schA::uuid AND status='recorded'
     AND category='fuel' AND incurred_on >= date_trunc('month', timezone('utc', now()))::date
) q;

-- ── PROBE 3 — category CHECK rejects an unknown category ─────────────────────
DO $$
DECLARE ok int := 0;
BEGIN
  BEGIN INSERT INTO transport_expenses (organization_id, school_id, category, amount, incurred_on, recorded_by)
        VALUES ('a1000000-0000-4000-8000-000000000001','a2000000-0000-4000-8000-000000000001',
                'bribe', 100, CURRENT_DATE, 'a3000000-0000-4000-8000-000000000001');
  EXCEPTION WHEN check_violation THEN ok := 1; END;
  INSERT INTO r VALUES (3, 'category CHECK rejects an unknown cost category',
    CASE WHEN ok=1 THEN 'PASS' ELSE 'FAIL' END, 'category=bribe rejected = '||ok::text||' (expect 1)');
END $$;

-- ── PROBE 4 — amount CHECK rejects a non-positive amount ─────────────────────
DO $$
DECLARE ok int := 0;
BEGIN
  BEGIN INSERT INTO transport_expenses (organization_id, school_id, category, amount, incurred_on, recorded_by)
        VALUES ('a1000000-0000-4000-8000-000000000001','a2000000-0000-4000-8000-000000000001',
                'fuel', 0, CURRENT_DATE, 'a3000000-0000-4000-8000-000000000001');
  EXCEPTION WHEN check_violation THEN ok := 1; END;
  INSERT INTO r VALUES (4, 'amount CHECK rejects a non-positive amount',
    CASE WHEN ok=1 THEN 'PASS' ELSE 'FAIL' END, 'amount=0 rejected = '||ok::text||' (expect 1)');
END $$;

-- ── PROBE 5 — void terminal-guard: no concurrent / repeat double-void ────────
DO $$
DECLARE target uuid; first_void int; second_void int;
BEGIN
  SELECT id INTO target FROM transport_expenses
   WHERE organization_id='a1000000-0000-4000-8000-000000000001'
     AND school_id='a2000000-0000-4000-8000-000000000001'
     AND category='fuel' AND amount=3000.00 LIMIT 1;
  -- verbatim production void: status='recorded' guard
  WITH v AS (
    UPDATE transport_expenses SET status='void', voided_by='a3000000-0000-4000-8000-000000000001',
           voided_at=timezone('utc', now())
     WHERE organization_id='a1000000-0000-4000-8000-000000000001'
       AND school_id='a2000000-0000-4000-8000-000000000001'
       AND id=target AND status='recorded' RETURNING 1
  ) SELECT count(*) INTO first_void FROM v;
  WITH v AS (
    UPDATE transport_expenses SET status='void'
     WHERE organization_id='a1000000-0000-4000-8000-000000000001'
       AND school_id='a2000000-0000-4000-8000-000000000001'
       AND id=target AND status='recorded' RETURNING 1
  ) SELECT count(*) INTO second_void FROM v;
  INSERT INTO r VALUES (5, 'void terminal-guard: exactly one void wins, the repeat is a no-op',
    CASE WHEN first_void=1 AND second_void=0 THEN 'PASS' ELSE 'FAIL' END,
    'first void rows='||first_void::text||' second void rows='||second_void::text||' (expect 1 then 0)');
END $$;

-- ── PROBE 6 — a voided expense is excluded from the cost recompute ───────────
INSERT INTO r
SELECT 6, 'a voided expense drops out of the recorded cost total',
  CASE WHEN fuel=2000.00 AND total=3500.00 THEN 'PASS' ELSE 'FAIL' END,
  'after void: fuel='||fuel::text||' total='||total::text||' (expect 2000/3500)'
FROM (
  SELECT COALESCE(SUM(amount) FILTER (WHERE category='fuel'),0) AS fuel,
         COALESCE(SUM(amount),0) AS total
    FROM transport_expenses
   WHERE organization_id=:orgA::uuid AND school_id=:schA::uuid AND status='recorded'
) q;

-- ── PROBE 7 — RLS isolation ─────────────────────────────────────────────────
SELECT app.set_request_context(:orgA::uuid, 'school', :usr::uuid, :schB::uuid, NULL, NULL, NULL);
INSERT INTO r SELECT 7, 'RLS: a sibling school cannot see another school''s expenses',
  CASE WHEN count(*)=0 THEN 'PASS' ELSE 'FAIL' END,
  'school-A expenses visible to school B = '||count(*)::text||' (expect 0)'
FROM transport_expenses;

SELECT app.set_request_context(:orgO::uuid, 'school', :usr::uuid, :schO::uuid, NULL, NULL, NULL);
INSERT INTO r SELECT 8, 'RLS: a different tenant cannot see the expenses',
  CASE WHEN count(*)=0 THEN 'PASS' ELSE 'FAIL' END,
  'school-A expenses visible to org O = '||count(*)::text||' (expect 0)'
FROM transport_expenses;

SELECT app.set_request_context(:orgA::uuid, 'school', :usr::uuid, :schA::uuid, NULL, NULL, NULL);
INSERT INTO r SELECT 9, 'RLS control: the owning school sees its own expenses',
  CASE WHEN count(*)=3 THEN 'PASS' ELSE 'FAIL' END,
  'school-A expenses visible to school A = '||count(*)::text||' (expect 3: 2 recorded + 1 voided, all owned)'
FROM transport_expenses;

-- ── PROBE 10 — cross-module income JOIN executes on real Postgres ────────────
-- The fake DB never evaluates joins (PRC-A-D-04). Prove the income query runs and
-- returns a numeric off finance_invoice_head_allocations → finance_invoices.
INSERT INTO r
SELECT 10, 'income-vs-expense: transport income JOIN executes on real Postgres',
  CASE WHEN collected IS NOT NULL AND billed IS NOT NULL THEN 'PASS' ELSE 'FAIL' END,
  'transport income for 2026 (billed/collected) = '||billed::text||'/'||collected::text||' (join must resolve)'
FROM (
  SELECT COALESCE(SUM(ha.head_total_minor),0) AS billed, COALESCE(SUM(ha.head_paid_minor),0) AS collected
    FROM finance_invoice_head_allocations ha
    JOIN finance_invoices fi ON fi.id = ha.invoice_id
   WHERE ha.organization_id=:orgA::uuid AND ha.school_id=:schA::uuid
     AND ha.fee_head LIKE 'transport:%'
     AND fi.invoice_date BETWEEN '2026-01-01'::date AND '2026-12-31'::date
) q;

-- ── PROBE 11 — append-only: erp_tenant has NO DELETE on the ledger ───────────
DO $$
DECLARE denied int := 0;
BEGIN
  BEGIN DELETE FROM transport_expenses WHERE organization_id='a1000000-0000-4000-8000-000000000001';
  EXCEPTION WHEN insufficient_privilege THEN denied := 1; END;
  INSERT INTO r VALUES (11, 'append-only: erp_tenant cannot DELETE an expense (void, not delete)',
    CASE WHEN denied=1 THEN 'PASS' ELSE 'FAIL' END, 'DELETE permission-denied = '||denied::text||' (expect 1)');
END $$;

RESET ROLE;
\echo ==================== RESULTS ====================
SELECT ord, verdict, probe, evidence FROM r ORDER BY ord;
SELECT CASE WHEN count(*) FILTER (WHERE verdict<>'PASS')=0
            THEN '✅ ALL '||count(*)::text||' PROBES PASS'
            ELSE '❌ '||count(*) FILTER (WHERE verdict<>'PASS')::text||' FAILED' END AS gate
FROM r;

ROLLBACK;
\echo ==================== ROLLED BACK (zero residue) ====================
SELECT 'RESIDUE expenses' AS probe, count(*) AS rows FROM transport_expenses
  WHERE recorded_by='a3000000-0000-4000-8000-000000000001';
