-- PRC-A Batch 4 — Storage quota LIVE CERT (ROLLBACK-safe probes).
--
-- Runs as the REAL non-bypass `erp_tenant` role via `app.set_request_context(...)`
-- (identical to withTenantContext), inside ONE BEGIN…ROLLBACK so prod is
-- untouched. Proves what the fake DB structurally CANNOT: the usage projection
-- SQL (signed SUM), real RLS org-isolation, append-only immutability, the
-- delta<>0 CHECK, and the plan storage-limit column round-trip.
--
-- NOT proven here (deliberately): atomic concurrency. Storage enforcement is SOFT
-- check-then-act, identical to the student/school slab limits — a small transient
-- over-quota under concurrency is accepted by design; bytes do not need the
-- wallet's atomic admit. There is therefore no atomic guarantee to certify, and
-- claiming one would be over-reach.
--
-- Run: docker exec -i akshara-postgres psql -U supabase_admin -d akshara_db -f - < this
\set ON_ERROR_STOP off

\echo ==================== BEGIN (all seed rolled back) ====================
BEGIN;
SET ROLE erp_tenant;
SELECT app.set_request_context(
  'a1000000-0000-4000-8000-000000000001'::uuid, 'organization',
  'a3000000-0000-4000-8000-000000000001'::uuid, NULL::uuid, NULL::uuid, NULL::uuid, NULL::uuid);

-- Seed under real RLS: two uploads and one delete.
INSERT INTO storage_usage_entries(organization_id, delta_bytes, category, object_key) VALUES
  ('a1000000-0000-4000-8000-000000000001',  1048576, 'memories', 'o/a.jpg'),   -- +1 MiB
  ('a1000000-0000-4000-8000-000000000001',  2097152, 'memories', 'o/b.mp4'),   -- +2 MiB
  ('a1000000-0000-4000-8000-000000000001', -524288,  'memories', 'o/a.jpg');   -- -0.5 MiB (delete)
-- net = 1048576 + 2097152 - 524288 = 2621440 bytes (2.5 MiB)

-- ── PROBE 1 — usage projection (signed SUM) ──────────────────────────────────
\echo -- PROBE 1: usage projection (expect used=2621440 = 2.5 MiB; the delete is subtracted)
SELECT 'PROJECTION' AS probe,
  (SELECT coalesce(sum(delta_bytes),0) FROM storage_usage_entries
    WHERE organization_id='a1000000-0000-4000-8000-000000000001') AS used_bytes;

-- ── PROBE 2 — RLS org-isolation ──────────────────────────────────────────────
\echo -- PROBE 2a: switch to orgB — must see 0 of orgA usage rows
SELECT app.set_request_context(
  '153cbc5a-05b7-48b4-b900-edb126a099f0'::uuid, 'organization',
  'a3000000-0000-4000-8000-000000000001'::uuid, NULL::uuid, NULL::uuid, NULL::uuid, NULL::uuid);
SELECT 'RLS_orgB_sees_orgA' AS probe, count(*) AS visible_rows FROM storage_usage_entries;  -- expect 0

\echo -- PROBE 2b: control — back to orgA, must see its own 3 rows
SELECT app.set_request_context(
  'a1000000-0000-4000-8000-000000000001'::uuid, 'organization',
  'a3000000-0000-4000-8000-000000000001'::uuid, NULL::uuid, NULL::uuid, NULL::uuid, NULL::uuid);
SELECT 'RLS_orgA_control' AS probe, count(*) AS visible_rows FROM storage_usage_entries;  -- expect 3

-- ── PROBE 3 — delta<>0 CHECK ─────────────────────────────────────────────────
\echo -- PROBE 3: a zero-delta ledger row must be rejected by the DB
DO $$
DECLARE ok int := 0;
BEGIN
  BEGIN INSERT INTO storage_usage_entries(organization_id, delta_bytes, category, object_key)
        VALUES ('a1000000-0000-4000-8000-000000000001', 0, 'x', 'k'); ok:=ok;
  EXCEPTION WHEN check_violation THEN ok:=ok+1; END;
  RAISE NOTICE 'PROBE 3 delta<>0 CHECK: % / 1 rejected => %', ok, CASE WHEN ok=1 THEN 'PASS' ELSE 'FAIL' END;
END $$;

-- ── PROBE 4 — append-only immutability ───────────────────────────────────────
\echo -- PROBE 4: UPDATE and DELETE must both be permission-denied for erp_tenant
DO $$
DECLARE denied int := 0;
BEGIN
  BEGIN UPDATE storage_usage_entries SET delta_bytes=1 WHERE organization_id='a1000000-0000-4000-8000-000000000001';
  EXCEPTION WHEN insufficient_privilege THEN denied:=denied+1; END;
  BEGIN DELETE FROM storage_usage_entries WHERE organization_id='a1000000-0000-4000-8000-000000000001';
  EXCEPTION WHEN insufficient_privilege THEN denied:=denied+1; END;
  RAISE NOTICE 'PROBE 4 immutability: % / 2 denied => %', denied, CASE WHEN denied=2 THEN 'PASS' ELSE 'FAIL' END;
END $$;

ROLLBACK;
\echo ==================== ROLLED BACK ====================

-- ── PROBE 5 — plan storage-limit column round-trips (as owner supabase_admin) ─
-- The limit lives on subscription_plans and is read by resolveSubscription's
-- PLAN_COLUMNS select. Set it in a throwaway txn and read it back the same way.
\echo -- PROBE 5: max_storage_bytes column round-trips through the plan read
BEGIN;
UPDATE subscription_plans SET max_storage_bytes = 5368709120  -- 5 GiB
 WHERE slug = (SELECT slug FROM subscription_plans ORDER BY tier_rank LIMIT 1);
SELECT 'PLAN_LIMIT_readback' AS probe, max_storage_bytes
  FROM subscription_plans ORDER BY tier_rank LIMIT 1;  -- expect 5368709120
ROLLBACK;

-- ── Residue check ────────────────────────────────────────────────────────────
RESET ROLE;
\echo -- RESIDUE: storage_usage_entries=0, no plan carries a limit (all rolled back)
SELECT 'RESIDUE storage_usage_entries' AS probe, count(*) AS rows FROM storage_usage_entries;
SELECT 'RESIDUE plans_with_limit' AS probe, count(*) AS rows FROM subscription_plans WHERE max_storage_bytes IS NOT NULL;
