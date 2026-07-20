-- PRC-A Batch 3 — AI credit wallet LIVE CERT (ROLLBACK-safe probes).
--
-- Runs as the REAL non-bypass `erp_tenant` role via `app.set_request_context(...)`
-- — byte-identical to what `withTenantContext` does in production, so RLS is
-- genuinely evaluated, not simulated. Everything is inside ONE BEGIN…ROLLBACK,
-- so prod is left untouched (a residue check runs after, as supabase_admin).
--
-- Proves what the fake DB structurally CANNOT: the balance projection SQL, the
-- pending-vs-consumed reserved filter, real RLS org-isolation, the DB sign
-- CHECK, and the append-only (no UPDATE/DELETE) immutability grant.
-- The double-spend concurrency proof is a SEPARATE script (needs two backends):
--   scripts/qa/live_cert_batch3_double_spend.sh
--
-- Run: docker exec -i akshara-postgres psql -U supabase_admin -d akshara_db -f - < this
\set ON_ERROR_STOP off

\echo ==================== BEGIN (all seed rolled back) ====================
BEGIN;
SET ROLE erp_tenant;

-- Context = orgA (the seed tenant). userId is a throwaway uuid; the wallet RLS
-- only checks organization_id = app_current_tenant_id().
SELECT app.set_request_context(
  'a1000000-0000-4000-8000-000000000001'::uuid, 'organization',
  'a3000000-0000-4000-8000-000000000001'::uuid, NULL::uuid, NULL::uuid, NULL::uuid, NULL::uuid);

-- ── Seed under real RLS (WITH CHECK org = current tenant must pass) ──────────
INSERT INTO ai_credit_entries(organization_id, entry_type, units, reason) VALUES
  ('a1000000-0000-4000-8000-000000000001','top_up',    100,'b3cert seed'),
  ('a1000000-0000-4000-8000-000000000001','adjustment', -10,'b3cert seed'),
  ('a1000000-0000-4000-8000-000000000001','expiry',      -5,'b3cert seed');
-- granted = 100 - 10 - 5 = 85
INSERT INTO ai_call_log(organization_id, outcome, credits_debited) VALUES
  ('a1000000-0000-4000-8000-000000000001','ok',30);
-- A PENDING hold (counts) and a CONSUMED one (must NOT count — only pending is
-- in-flight; a consumed reservation's cost has already moved to credits_debited).
INSERT INTO ai_call_reservations(organization_id, surface, status, credits_reserved) VALUES
  ('a1000000-0000-4000-8000-000000000001','b3cert','pending', 20),
  ('a1000000-0000-4000-8000-000000000001','b3cert','consumed',50);

-- ── PROBE 1 — the EXACT readWalletBalance projection SQL ─────────────────────
\echo -- PROBE 1: balance projection (expect granted=85 debited=30 reserved=20 available=35)
SELECT 'PROJECTION' AS probe,
  (SELECT coalesce(sum(units),0)           FROM ai_credit_entries    WHERE organization_id='a1000000-0000-4000-8000-000000000001') AS granted,
  (SELECT coalesce(sum(credits_debited),0) FROM ai_call_log          WHERE organization_id='a1000000-0000-4000-8000-000000000001') AS debited,
  (SELECT coalesce(sum(credits_reserved),0)FROM ai_call_reservations WHERE organization_id='a1000000-0000-4000-8000-000000000001' AND status='pending') AS reserved,
  (SELECT coalesce(sum(units),0)           FROM ai_credit_entries    WHERE organization_id='a1000000-0000-4000-8000-000000000001')
  - (SELECT coalesce(sum(credits_debited),0) FROM ai_call_log        WHERE organization_id='a1000000-0000-4000-8000-000000000001')
  - (SELECT coalesce(sum(credits_reserved),0)FROM ai_call_reservations WHERE organization_id='a1000000-0000-4000-8000-000000000001' AND status='pending') AS available;

-- ── PROBE 2 — RLS org-isolation (real erp_tenant, real policy) ───────────────
\echo -- PROBE 2a: switch to orgB — must see 0 of orgA credit rows
SELECT app.set_request_context(
  '153cbc5a-05b7-48b4-b900-edb126a099f0'::uuid, 'organization',
  'a3000000-0000-4000-8000-000000000001'::uuid, NULL::uuid, NULL::uuid, NULL::uuid, NULL::uuid);
SELECT 'RLS_orgB_sees_orgA' AS probe, count(*) AS visible_rows FROM ai_credit_entries;  -- expect 0

\echo -- PROBE 2b: control — back to orgA, must see its own 3 rows (proves the probe is not vacuous)
SELECT app.set_request_context(
  'a1000000-0000-4000-8000-000000000001'::uuid, 'organization',
  'a3000000-0000-4000-8000-000000000001'::uuid, NULL::uuid, NULL::uuid, NULL::uuid, NULL::uuid);
SELECT 'RLS_orgA_control' AS probe, count(*) AS visible_rows FROM ai_credit_entries;  -- expect 3

-- ── PROBE 3 — DB sign CHECK constraint (top_up>0, expiry<0, adjustment<>0) ───
\echo -- PROBE 3: sign constraints — each of the three must be rejected by the DB
DO $$
DECLARE ok int := 0;
BEGIN
  BEGIN INSERT INTO ai_credit_entries(organization_id,entry_type,units,reason)
        VALUES ('a1000000-0000-4000-8000-000000000001','top_up',-5,'bad'); ok:=ok;
  EXCEPTION WHEN check_violation THEN ok:=ok+1; END;
  BEGIN INSERT INTO ai_credit_entries(organization_id,entry_type,units,reason)
        VALUES ('a1000000-0000-4000-8000-000000000001','expiry',5,'bad');
  EXCEPTION WHEN check_violation THEN ok:=ok+1; END;
  BEGIN INSERT INTO ai_credit_entries(organization_id,entry_type,units,reason)
        VALUES ('a1000000-0000-4000-8000-000000000001','adjustment',0,'bad');
  EXCEPTION WHEN check_violation THEN ok:=ok+1; END;
  RAISE NOTICE 'PROBE 3 sign constraints: % / 3 rejected  => %', ok, CASE WHEN ok=3 THEN 'PASS' ELSE 'FAIL' END;
END $$;

-- ── PROBE 4 — append-only immutability (erp_tenant has no UPDATE/DELETE grant)─
\echo -- PROBE 4: immutability — UPDATE and DELETE must both be permission-denied for erp_tenant
DO $$
DECLARE denied int := 0;
BEGIN
  BEGIN UPDATE ai_credit_entries SET units=999 WHERE organization_id='a1000000-0000-4000-8000-000000000001';
  EXCEPTION WHEN insufficient_privilege THEN denied:=denied+1; END;
  BEGIN DELETE FROM ai_credit_entries WHERE organization_id='a1000000-0000-4000-8000-000000000001';
  EXCEPTION WHEN insufficient_privilege THEN denied:=denied+1; END;
  RAISE NOTICE 'PROBE 4 immutability: % / 2 denied  => %', denied, CASE WHEN denied=2 THEN 'PASS' ELSE 'FAIL' END;
END $$;

ROLLBACK;
\echo ==================== ROLLED BACK ====================

-- ── Residue check (fresh, as the owner supabase_admin) ──────────────────────
RESET ROLE;
\echo -- RESIDUE: ai_credit_entries must be 0 (table was empty; nothing committed)
SELECT 'RESIDUE ai_credit_entries' AS probe, count(*) AS rows FROM ai_credit_entries;
SELECT 'RESIDUE ai_call_reservations surface=b3cert' AS probe, count(*) AS rows FROM ai_call_reservations WHERE surface='b3cert';
