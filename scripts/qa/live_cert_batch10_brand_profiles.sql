-- PRC-A Batch 10 — Brand profile LIVE CERT (ROLLBACK-safe).
--
-- Runs as the REAL erp_tenant role via app.set_request_context(...), one
-- BEGIN…ROLLBACK. Proves the brand_profiles DB layer the fake DB can't: RLS
-- tenant/school isolation on sensitive per-tenant marketing assets, the JSONB
-- shape CHECKs, idempotent upsert, and the append-only grant. (The minimum-
-- relevant-asset selection + honest dark poster engine are pure logic, unit-
-- certified — 10 tests.)
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

-- ── PROBE 1 — brand profile upsert stores theme (object) + assets (array) ────
INSERT INTO brand_profiles (organization_id, school_id, logo_url, tagline, theme, assets, created_by)
VALUES (:orgA::uuid, :schA::uuid, 'u/logo', 'Excellence in Education',
        '{"primaryColor":"#0a7"}'::jsonb,
        '[{"id":"a1","type":"logo","url":"u/l","tags":[]},{"id":"a2","type":"photo","url":"u/p","tags":["sports"]}]'::jsonb,
        :usr::uuid);
INSERT INTO r
SELECT 1, 'brand profile stores theme (object) + assets (array) round-trip',
  CASE WHEN jsonb_typeof(theme)='object' AND jsonb_typeof(assets)='array' AND jsonb_array_length(assets)=2
       THEN 'PASS' ELSE 'FAIL' END,
  'theme='||jsonb_typeof(theme)||' assets='||jsonb_typeof(assets)||'['||jsonb_array_length(assets)::text||']'
FROM brand_profiles WHERE organization_id=:orgA::uuid AND school_id=:schA::uuid;

-- ── PROBE 2 — assets CHECK rejects a non-array ──────────────────────────────
-- Under school B's OWN context (so RLS passes) with a bad-shape payload → the DB
-- CHECK, not RLS, must reject it.
SELECT app.set_request_context(:orgA::uuid, 'school', :usr::uuid, :schB::uuid, NULL, NULL, NULL);
DO $$
DECLARE ok int := 0;
BEGIN
  BEGIN INSERT INTO brand_profiles (organization_id, school_id, assets, created_by)
        VALUES ('a1000000-0000-4000-8000-000000000001','a2000000-0000-4000-8000-000000000002',
                '{"not":"an array"}'::jsonb, 'a3000000-0000-4000-8000-000000000001');
  EXCEPTION WHEN check_violation THEN ok := 1; END;
  INSERT INTO r VALUES (2, 'assets CHECK rejects a non-array payload',
    CASE WHEN ok=1 THEN 'PASS' ELSE 'FAIL' END, 'object-as-assets rejected = '||ok::text||' (expect 1)');
END $$;
SELECT app.set_request_context(:orgA::uuid, 'school', :usr::uuid, :schA::uuid, NULL, NULL, NULL);

-- ── PROBE 3 — idempotent upsert: one profile per school ─────────────────────
INSERT INTO brand_profiles (organization_id, school_id, logo_url, tagline, theme, assets, created_by)
VALUES (:orgA::uuid, :schA::uuid, 'u/logo2', 'Nurturing Futures', '{}'::jsonb, '[]'::jsonb, :usr::uuid)
ON CONFLICT (organization_id, school_id)
DO UPDATE SET tagline = EXCLUDED.tagline, logo_url = EXCLUDED.logo_url, updated_at = timezone('utc', now());
INSERT INTO r
SELECT 3, 'idempotent upsert keeps one profile per school and updates it',
  CASE WHEN cnt=1 AND tagline='Nurturing Futures' THEN 'PASS' ELSE 'FAIL' END,
  'rows='||cnt::text||' tagline='||tagline||' (expect 1 / updated)'
FROM (
  SELECT count(*) AS cnt, max(tagline) AS tagline FROM brand_profiles
   WHERE organization_id=:orgA::uuid AND school_id=:schA::uuid
) q;

-- ── PROBE 4 — RLS isolation ─────────────────────────────────────────────────
SELECT app.set_request_context(:orgA::uuid, 'school', :usr::uuid, :schB::uuid, NULL, NULL, NULL);
INSERT INTO r SELECT 4, 'RLS: a sibling school cannot see another school''s brand profile',
  CASE WHEN count(*)=0 THEN 'PASS' ELSE 'FAIL' END,
  'school-A profile visible to school B = '||count(*)::text||' (expect 0)'
FROM brand_profiles;

SELECT app.set_request_context(:orgO::uuid, 'school', :usr::uuid, :schO::uuid, NULL, NULL, NULL);
INSERT INTO r SELECT 5, 'RLS: a different tenant cannot see the brand profile',
  CASE WHEN count(*)=0 THEN 'PASS' ELSE 'FAIL' END,
  'school-A profile visible to org O = '||count(*)::text||' (expect 0)'
FROM brand_profiles;

SELECT app.set_request_context(:orgA::uuid, 'school', :usr::uuid, :schA::uuid, NULL, NULL, NULL);
INSERT INTO r SELECT 6, 'RLS control: the owning school sees its own brand profile',
  CASE WHEN count(*)=1 THEN 'PASS' ELSE 'FAIL' END,
  'school-A profile visible to school A = '||count(*)::text||' (expect 1)'
FROM brand_profiles;

-- ── PROBE 7 — append-only: erp_tenant has NO DELETE ─────────────────────────
DO $$
DECLARE denied int := 0;
BEGIN
  BEGIN DELETE FROM brand_profiles WHERE organization_id='a1000000-0000-4000-8000-000000000001';
  EXCEPTION WHEN insufficient_privilege THEN denied := 1; END;
  INSERT INTO r VALUES (7, 'append-only: erp_tenant cannot DELETE a brand profile (retire via is_active)',
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
SELECT 'RESIDUE profiles' AS probe, count(*) AS rows FROM brand_profiles
  WHERE created_by='a3000000-0000-4000-8000-000000000001';
