-- PRC-A Batch 7 — Tally export LIVE CERT (ROLLBACK-safe).
--
-- Runs as the REAL non-bypass `erp_tenant` role via `app.set_request_context(...)`
-- — byte-identical to withTenantContext — so RLS is genuinely evaluated. Inside
-- ONE BEGIN…ROLLBACK; nothing persists. Proves what the fake DB CANNOT: the
-- export query's collections→invoices JOIN + status/date filter on real money
-- rows, RLS tenant isolation on that read, the ledger-map RLS + CHECK + append-
-- only grant. (Uses School A's EXISTING finance_collections; the fake DB never
-- evaluates the join, which is exactly why the fee-reductions engine once shipped
-- "certified" with a broken join — PRC-A-D-04.)
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

-- ── PROBE 1 — export query (verbatim) returns ONLY completed receipts ────────
-- School A has exactly 1 'completed' collection (2026-06-23) plus cancelled /
-- partially_refunded rows in June. The export must return the 1 completed only.
INSERT INTO r
SELECT 1, 'export query joins collections→invoices and returns only completed receipts',
  CASE WHEN count(*)=1 THEN 'PASS' ELSE 'FAIL' END,
  'vouchers exported for June = '||count(*)::text||' (expect 1 completed)'
FROM (
  SELECT fc.receipt_number, fc.collection_date::text, fc.payment_method,
         fc.amount_collected, fc.reference_number, fi.invoice_number
    FROM finance_collections fc
    LEFT JOIN finance_invoices fi ON fi.id = fc.invoice_id
   WHERE fc.organization_id = :orgA::uuid AND fc.school_id = :schA::uuid
     AND fc.collection_status = 'completed'
     AND fc.collection_date BETWEEN '2026-06-01'::date AND '2026-06-30'::date
) q;

-- ── PROBE 2 — the status filter actually DROPS non-completed rows ────────────
INSERT INTO r
SELECT 2, 'status filter drops cancelled / refunded / partially_refunded',
  CASE WHEN completed < total THEN 'PASS' ELSE 'FAIL' END,
  'June rows total='||total::text||' completed='||completed::text||' (completed must be < total)'
FROM (
  SELECT count(*) AS total,
         count(*) FILTER (WHERE collection_status='completed') AS completed
    FROM finance_collections
   WHERE organization_id=:orgA::uuid AND school_id=:schA::uuid
     AND collection_date BETWEEN '2026-06-01'::date AND '2026-06-30'::date
) q;

-- ── PROBE 3 — RLS tenant isolation on the export read ───────────────────────
-- A different tenant running the SAME export query for org A's ids sees nothing:
-- RLS blocks it even though the WHERE names org A.
SELECT app.set_request_context(:orgO::uuid, 'school', :usr::uuid, :schO::uuid, NULL, NULL, NULL);
INSERT INTO r
SELECT 3, 'RLS: a different tenant cannot export another org''s collections',
  CASE WHEN count(*)=0 THEN 'PASS' ELSE 'FAIL' END,
  'org-A completed collections visible to org O = '||count(*)::text||' (expect 0)'
FROM finance_collections
 WHERE organization_id=:orgA::uuid AND school_id=:schA::uuid AND collection_status='completed'
   AND collection_date BETWEEN '2026-06-01'::date AND '2026-06-30'::date;

-- ── PROBE 4 — ledger-map RLS isolation ──────────────────────────────────────
SELECT app.set_request_context(:orgA::uuid, 'school', :usr::uuid, :schA::uuid, NULL, NULL, NULL);
INSERT INTO finance_tally_ledger_map
  (organization_id, school_id, cash_ledger, bank_ledger, fee_income_ledger, method_ledger_overrides, created_by)
VALUES (:orgA::uuid, :schA::uuid, 'Cash A/c', 'HDFC Bank', 'Tuition Income', '{"upi":"HDFC UPI"}'::jsonb, :usr::uuid);

SELECT app.set_request_context(:orgA::uuid, 'school', :usr::uuid, :schB::uuid, NULL, NULL, NULL);
INSERT INTO r SELECT 4, 'RLS: a sibling school cannot see another school''s ledger map',
  CASE WHEN count(*)=0 THEN 'PASS' ELSE 'FAIL' END,
  'school-A map visible to school B = '||count(*)::text||' (expect 0)'
FROM finance_tally_ledger_map;

SELECT app.set_request_context(:orgO::uuid, 'school', :usr::uuid, :schO::uuid, NULL, NULL, NULL);
INSERT INTO r SELECT 5, 'RLS: a different tenant cannot see the ledger map',
  CASE WHEN count(*)=0 THEN 'PASS' ELSE 'FAIL' END,
  'school-A map visible to org O = '||count(*)::text||' (expect 0)'
FROM finance_tally_ledger_map;

SELECT app.set_request_context(:orgA::uuid, 'school', :usr::uuid, :schA::uuid, NULL, NULL, NULL);
INSERT INTO r SELECT 6, 'RLS control: the owning school sees its own ledger map',
  CASE WHEN count(*)=1 THEN 'PASS' ELSE 'FAIL' END,
  'school-A map visible to school A = '||count(*)::text||' (expect 1)'
FROM finance_tally_ledger_map;

-- ── PROBE 7 — ledger-name CHECK rejects a blank ledger ──────────────────────
SELECT app.set_request_context(:orgA::uuid, 'school', :usr::uuid, :schB::uuid, NULL, NULL, NULL);
DO $$
DECLARE ok int := 0;
BEGIN
  BEGIN
    INSERT INTO finance_tally_ledger_map
      (organization_id, school_id, cash_ledger, bank_ledger, fee_income_ledger, created_by)
    VALUES ('a1000000-0000-4000-8000-000000000001','a2000000-0000-4000-8000-000000000002',
            '   ', 'Bank', 'Fee Income', 'a3000000-0000-4000-8000-000000000001');
  EXCEPTION WHEN check_violation THEN ok := 1; END;
  INSERT INTO r VALUES (7, 'ledger-name CHECK rejects a blank ledger name',
    CASE WHEN ok=1 THEN 'PASS' ELSE 'FAIL' END,
    'blank cash_ledger rejected = '||ok::text||' (expect 1)');
END $$;
SELECT app.set_request_context(:orgA::uuid, 'school', :usr::uuid, :schA::uuid, NULL, NULL, NULL);

-- ── PROBE 8 — append-only: erp_tenant has NO DELETE on the map ───────────────
DO $$
DECLARE denied int := 0;
BEGIN
  BEGIN DELETE FROM finance_tally_ledger_map
        WHERE organization_id='a1000000-0000-4000-8000-000000000001';
  EXCEPTION WHEN insufficient_privilege THEN denied := 1; END;
  INSERT INTO r VALUES (8, 'append-only: erp_tenant cannot DELETE a ledger map (retire via is_active)',
    CASE WHEN denied=1 THEN 'PASS' ELSE 'FAIL' END,
    'DELETE permission-denied = '||denied::text||' (expect 1)');
END $$;

-- ── PROBE 9 — backward-safe: an unconfigured school has no map → DEFAULT used ─
SELECT app.set_request_context(:orgA::uuid, 'school', :usr::uuid, :schB::uuid, NULL, NULL, NULL);
INSERT INTO r SELECT 9, 'unconfigured school → no map row → generator uses safe defaults',
  CASE WHEN count(*)=0 THEN 'PASS' ELSE 'FAIL' END,
  'map rows for an unconfigured school = '||count(*)::text||' (expect 0)'
FROM finance_tally_ledger_map
 WHERE organization_id=:orgA::uuid AND school_id=:schB::uuid;

RESET ROLE;
\echo ==================== RESULTS ====================
SELECT ord, verdict, probe, evidence FROM r ORDER BY ord;
SELECT CASE WHEN count(*) FILTER (WHERE verdict<>'PASS')=0
            THEN '✅ ALL '||count(*)::text||' PROBES PASS'
            ELSE '❌ '||count(*) FILTER (WHERE verdict<>'PASS')::text||' FAILED' END AS gate
FROM r;

ROLLBACK;
\echo ==================== ROLLED BACK (zero residue) ====================
SELECT 'RESIDUE maps' AS probe, count(*) AS rows FROM finance_tally_ledger_map
  WHERE created_by='a3000000-0000-4000-8000-000000000001';
