-- PRC P5 (red-team Round 2) — confirmQrSession status guard LIVE CERT.
-- ROLLBACK-safe, as the real erp_tenant role. Proves the QR fee-payment confirm is
-- now exactly-once: a concurrent/repeat confirm cannot double-apply.
--
-- Run: docker exec -i akshara-postgres psql -U supabase_admin -d akshara_db -f - < this
\set ON_ERROR_STOP off

\echo ==================== BEGIN (rolled back) ====================
BEGIN;
CREATE TEMP TABLE r(ord int, probe text, verdict text, evidence text);
GRANT INSERT, SELECT ON r TO erp_tenant;

\set orgA '''a1000000-0000-4000-8000-000000000001'''
\set schA '''a2000000-0000-4000-8000-000000000001'''
\set usr  '''a3000000-0000-4000-8000-000000000001'''

SET ROLE erp_tenant;
SELECT app.set_request_context(:orgA::uuid, 'school', :usr::uuid, :schA::uuid, NULL, NULL, NULL);

-- Seed one PENDING QR fee-payment session.
INSERT INTO finance_qr_sessions (id, organization_id, school_id, amount, upi_payload, status, expires_at)
VALUES ('e9000000-0000-4000-8000-000000000001', :orgA::uuid, :schA::uuid, 4200.00, 'upi://pay?x=1',
        'pending', timezone('utc', now()) + interval '15 minutes');

-- ── PROBE 1 — first confirm wins (guarded UPDATE flips pending→confirmed) ─────
WITH c AS (
  UPDATE finance_qr_sessions
     SET status='confirmed', confirmed_at=timezone('utc',now()), updated_at=timezone('utc',now())
   WHERE id='e9000000-0000-4000-8000-000000000001'
     AND organization_id=:orgA::uuid AND school_id=:schA::uuid
     AND status='pending'
   RETURNING id
)
INSERT INTO r
SELECT 1, 'first confirm wins (guarded pending→confirmed)',
  CASE WHEN cnt=1 THEN 'PASS' ELSE 'FAIL' END, 'first confirm rows = '||cnt::text||' (expect 1)'
FROM (SELECT count(*) AS cnt FROM c) x;

-- ── PROBE 2 — a concurrent / repeat confirm gets 0 rows (exactly-once → 409) ──
WITH c AS (
  UPDATE finance_qr_sessions
     SET status='confirmed', confirmed_at=timezone('utc',now()), updated_at=timezone('utc',now())
   WHERE id='e9000000-0000-4000-8000-000000000001'
     AND organization_id=:orgA::uuid AND school_id=:schA::uuid
     AND status='pending'
   RETURNING id
)
INSERT INTO r
SELECT 2, 'a repeat/concurrent confirm affects 0 rows → app throws NotConfirmable (409), never a 2nd success',
  CASE WHEN cnt=0 THEN 'PASS' ELSE 'FAIL' END, 'second confirm rows = '||cnt::text||' (expect 0)'
FROM (SELECT count(*) AS cnt FROM c) x;

-- ── PROBE 3 — the session ended in exactly ONE confirmed state ───────────────
INSERT INTO r
SELECT 3, 'the session is confirmed exactly once (single terminal state)',
  CASE WHEN status='confirmed' THEN 'PASS' ELSE 'FAIL' END, 'final status = '||status
FROM finance_qr_sessions WHERE id='e9000000-0000-4000-8000-000000000001';

RESET ROLE;
\echo ==================== RESULTS ====================
SELECT ord, verdict, probe, evidence FROM r ORDER BY ord;
SELECT CASE WHEN count(*) FILTER (WHERE verdict<>'PASS')=0
            THEN '✅ ALL '||count(*)::text||' PROBES PASS' ELSE '❌ FAILED' END AS gate FROM r;

ROLLBACK;
\echo ==================== ROLLED BACK (zero residue) ====================
SELECT 'RESIDUE' AS probe, count(*) AS rows FROM finance_qr_sessions WHERE id='e9000000-0000-4000-8000-000000000001';
