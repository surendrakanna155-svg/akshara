-- PRC-A Batch 9 — Upload malware-scan ledger LIVE CERT (ROLLBACK-safe).
--
-- Runs as the REAL erp_tenant role via app.set_request_context(...), one
-- BEGIN…ROLLBACK. Proves the scan-result ledger the fake DB can't: the status
-- CHECK, idempotent record (a re-confirm can't clobber/downgrade a verdict), the
-- pending-guarded verdict update (no verdict-clobber), RLS isolation, and the
-- append-only grant. (The honest 'skipped' status + serving-gate disposition are
-- unit-certified — 9 tests — since they are pure logic, not SQL.)
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

-- Record an HONEST 'skipped' scan (the dark default) for object k1.
INSERT INTO upload_scan_results (organization_id, school_id, bucket, object_key, module, status, engine, requested_by)
VALUES (:orgA::uuid, :schA::uuid, 'school-memories', 'k1', 'memories', 'skipped', 'none', :usr::uuid);

-- ── PROBE 1 — a dark upload is recorded 'skipped', never 'clean' ─────────────
INSERT INTO r
SELECT 1, 'a dark (un-scanned) upload is recorded honest ''skipped'', not ''clean''',
  CASE WHEN status='skipped' THEN 'PASS' ELSE 'FAIL' END,
  'k1 status = '||status||' (expect skipped)'
FROM upload_scan_results WHERE organization_id=:orgA::uuid AND object_key='k1';

-- ── PROBE 2 — status CHECK rejects an out-of-vocabulary verdict ──────────────
DO $$
DECLARE ok int := 0;
BEGIN
  BEGIN INSERT INTO upload_scan_results (organization_id, school_id, bucket, object_key, module, status, engine, requested_by)
        VALUES ('a1000000-0000-4000-8000-000000000001','a2000000-0000-4000-8000-000000000001',
                'school-memories','k_bad','memories','malicious','none','a3000000-0000-4000-8000-000000000001');
  EXCEPTION WHEN check_violation THEN ok := 1; END;
  INSERT INTO r VALUES (2, 'status CHECK rejects an unknown verdict',
    CASE WHEN ok=1 THEN 'PASS' ELSE 'FAIL' END, 'status=malicious rejected = '||ok::text||' (expect 1)');
END $$;

-- ── PROBE 3 — idempotent record: a re-confirm can't clobber the row ──────────
INSERT INTO upload_scan_results (organization_id, school_id, bucket, object_key, module, status, engine, requested_by)
VALUES (:orgA::uuid, :schA::uuid, 'school-memories', 'k1', 'memories', 'clean', 'none', :usr::uuid)
ON CONFLICT (organization_id, object_key) DO NOTHING;
INSERT INTO r
SELECT 3, 'idempotent record: a re-confirm neither duplicates nor downgrades the verdict',
  CASE WHEN cnt=1 AND status='skipped' THEN 'PASS' ELSE 'FAIL' END,
  'k1 rows='||cnt::text||' status='||status||' (expect 1 / skipped — the re-record was a no-op)'
FROM (
  SELECT count(*) AS cnt, max(status) AS status FROM upload_scan_results
   WHERE organization_id=:orgA::uuid AND object_key='k1'
) q;

-- ── PROBE 4 — verdict guard: a pending scan resolves once, no clobber ────────
INSERT INTO upload_scan_results (organization_id, school_id, bucket, object_key, module, status, engine, requested_by)
VALUES (:orgA::uuid, :schA::uuid, 'school-memories', 'k2', 'memories', 'pending', 'clamav', :usr::uuid);
DO $$
DECLARE first_v int; second_v int;
BEGIN
  -- verbatim setScanVerdict: status='pending' guard
  WITH v AS (
    UPDATE upload_scan_results SET status='infected', detail='EICAR', scanned_at=timezone('utc',now())
     WHERE organization_id='a1000000-0000-4000-8000-000000000001' AND object_key='k2' AND status='pending'
     RETURNING 1
  ) SELECT count(*) INTO first_v FROM v;
  WITH v AS (
    UPDATE upload_scan_results SET status='clean'
     WHERE organization_id='a1000000-0000-4000-8000-000000000001' AND object_key='k2' AND status='pending'
     RETURNING 1
  ) SELECT count(*) INTO second_v FROM v;
  INSERT INTO r VALUES (4, 'verdict guard: a pending scan resolves once; a stale second verdict is a no-op',
    CASE WHEN first_v=1 AND second_v=0 THEN 'PASS' ELSE 'FAIL' END,
    'first verdict rows='||first_v::text||' second rows='||second_v::text||' (expect 1 then 0)');
END $$;

-- ── PROBE 5 — RLS isolation ─────────────────────────────────────────────────
SELECT app.set_request_context(:orgA::uuid, 'school', :usr::uuid, :schB::uuid, NULL, NULL, NULL);
INSERT INTO r SELECT 5, 'RLS: a sibling school cannot see another school''s scan rows',
  CASE WHEN count(*)=0 THEN 'PASS' ELSE 'FAIL' END,
  'school-A scans visible to school B = '||count(*)::text||' (expect 0)'
FROM upload_scan_results;

SELECT app.set_request_context(:orgO::uuid, 'school', :usr::uuid, :schO::uuid, NULL, NULL, NULL);
INSERT INTO r SELECT 6, 'RLS: a different tenant cannot see the scan rows',
  CASE WHEN count(*)=0 THEN 'PASS' ELSE 'FAIL' END,
  'school-A scans visible to org O = '||count(*)::text||' (expect 0)'
FROM upload_scan_results;

SELECT app.set_request_context(:orgA::uuid, 'school', :usr::uuid, :schA::uuid, NULL, NULL, NULL);
INSERT INTO r SELECT 7, 'RLS control: the owning school sees its own scan rows',
  CASE WHEN count(*)=2 THEN 'PASS' ELSE 'FAIL' END,
  'school-A scans visible to school A = '||count(*)::text||' (expect 2: k1 + k2)'
FROM upload_scan_results;

-- ── PROBE 8 — append-only: erp_tenant has NO DELETE ─────────────────────────
DO $$
DECLARE denied int := 0;
BEGIN
  BEGIN DELETE FROM upload_scan_results WHERE organization_id='a1000000-0000-4000-8000-000000000001';
  EXCEPTION WHEN insufficient_privilege THEN denied := 1; END;
  INSERT INTO r VALUES (8, 'append-only: erp_tenant cannot DELETE a scan record',
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
SELECT 'RESIDUE scans' AS probe, count(*) AS rows FROM upload_scan_results WHERE object_key IN ('k1','k2');
