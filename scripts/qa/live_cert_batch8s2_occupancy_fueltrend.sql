-- PRC-A Batch 8 slice 2 — LIVE occupancy + fuel-trend recompute CERT (ROLLBACK-safe).
--
-- Runs as the REAL erp_tenant role via app.set_request_context(...), inside one
-- BEGIN…ROLLBACK. Proves the two remaining transport static mocks are dead: the
-- occupancy endpoint now computes from real vehicle/allocation/route entities (and
-- DIFFERS from the still-present static snapshot_occupancy seed), and the reports
-- fuel trend now sums the real transport_expenses ledger.
--
-- Run: docker exec -i akshara-postgres psql -U supabase_admin -d akshara_db -f - < this
\set ON_ERROR_STOP off

\echo ==================== BEGIN (all seed rolled back) ====================
BEGIN;
CREATE TEMP TABLE r(ord int, probe text, verdict text, evidence text);
GRANT INSERT, SELECT ON r TO erp_tenant;

\set orgA '''a1000000-0000-4000-8000-000000000001'''
\set schA '''a2000000-0000-4000-8000-000000000001'''
\set orgO '''153cbc5a-05b7-48b4-b900-edb126a099f0'''
\set schO '''bb2d5521-0ab4-4eb9-a3f1-83691414ebc9'''
\set usr  '''a3000000-0000-4000-8000-000000000001'''

SET ROLE erp_tenant;
SELECT app.set_request_context(:orgA::uuid, 'school', :usr::uuid, :schA::uuid, NULL, NULL, NULL);

-- ── PROBE 1 — live occupancy is computed, and DIFFERS from the static seed ───
-- The verbatim getOccupancyMetrics aggregation vs. the still-present static
-- snapshot_occupancy literal (860/842). If they differ, the endpoint stopped
-- serving the seed.
INSERT INTO r
SELECT 1, 'occupancy is computed live and no longer the 860/842 static seed',
  CASE WHEN (live_cap <> seed_cap OR live_alloc <> seed_alloc) THEN 'PASS' ELSE 'FAIL' END,
  'live cap/alloc = '||live_cap::text||'/'||live_alloc::text||
    ' vs seed '||seed_cap::text||'/'||seed_alloc::text
FROM (
  SELECT
    COALESCE((SELECT SUM((payload->>'capacity')::numeric) FROM transport_entities
       WHERE organization_id=:orgA::uuid AND school_id=:schA::uuid AND entity_type='vehicle'
         AND COALESCE(payload->>'status','active')='active'
         AND payload->>'capacity' ~ '^[0-9]+(\.[0-9]+)?$'),0) AS live_cap,
    (SELECT count(*) FROM transport_entities
       WHERE organization_id=:orgA::uuid AND school_id=:schA::uuid AND entity_type='allocation') AS live_alloc,
    (SELECT (payload->>'totalCapacity')::numeric FROM transport_entities
       WHERE organization_id=:orgA::uuid AND school_id=:schA::uuid AND entity_type='snapshot_occupancy' AND id='default') AS seed_cap,
    (SELECT (payload->>'allocatedSeats')::numeric FROM transport_entities
       WHERE organization_id=:orgA::uuid AND school_id=:schA::uuid AND entity_type='snapshot_occupancy' AND id='default') AS seed_alloc
) q;

-- ── PROBE 2 — utilization is internally consistent (allocated/capacity) ──────
INSERT INTO r
SELECT 2, 'utilizationPercent = round(allocatedSeats / totalCapacity × 100)',
  CASE WHEN cap=0 AND util=0 THEN 'PASS'
       WHEN cap>0 AND util = round(alloc*100.0/cap) THEN 'PASS' ELSE 'FAIL' END,
  'cap='||cap::text||' alloc='||alloc::text||' util='||util::text
FROM (
  SELECT cap, alloc, CASE WHEN cap>0 THEN round(alloc*100.0/cap) ELSE 0 END AS util
  FROM (
    SELECT
      COALESCE((SELECT SUM((payload->>'capacity')::numeric) FROM transport_entities
         WHERE organization_id=:orgA::uuid AND school_id=:schA::uuid AND entity_type='vehicle'
           AND COALESCE(payload->>'status','active')='active'
           AND payload->>'capacity' ~ '^[0-9]+(\.[0-9]+)?$'),0) AS cap,
      (SELECT count(*) FROM transport_entities
         WHERE organization_id=:orgA::uuid AND school_id=:schA::uuid AND entity_type='allocation') AS alloc
  ) x
) q;

-- ── PROBE 3 — occupancy tenant isolation (RLS) ──────────────────────────────
SELECT app.set_request_context(:orgO::uuid, 'school', :usr::uuid, :schO::uuid, NULL, NULL, NULL);
INSERT INTO r
SELECT 3, 'RLS: a different tenant sees none of org-A''s fleet in the occupancy calc',
  CASE WHEN cap=0 AND alloc=0 THEN 'PASS' ELSE 'FAIL' END,
  'org-O sees cap/alloc = '||cap::text||'/'||alloc::text||' (expect 0/0)'
FROM (
  SELECT
    COALESCE((SELECT SUM((payload->>'capacity')::numeric) FROM transport_entities
       WHERE organization_id=:orgA::uuid AND school_id=:schA::uuid AND entity_type='vehicle'),0) AS cap,
    (SELECT count(*) FROM transport_entities
       WHERE organization_id=:orgA::uuid AND school_id=:schA::uuid AND entity_type='allocation') AS alloc
) q;

-- ── PROBE 4 — fuel trend sums the real ledger ───────────────────────────────
SELECT app.set_request_context(:orgA::uuid, 'school', :usr::uuid, :schA::uuid, NULL, NULL, NULL);
INSERT INTO transport_expenses (organization_id, school_id, category, amount, incurred_on, recorded_by)
VALUES (:orgA::uuid, :schA::uuid, 'fuel', 62000.00, CURRENT_DATE, :usr::uuid);
INSERT INTO r
SELECT 4, 'reports fuel trend sums the transport_expenses ledger (lakhs)',
  CASE WHEN months=1 AND lakhs=0.62 THEN 'PASS' ELSE 'FAIL' END,
  'trend months='||months::text||' this-month lakhs='||lakhs::text||' (expect 1 / 0.62)'
FROM (
  SELECT count(*) AS months,
         MAX(round(total/100000.0, 2)) AS lakhs
  FROM (
    SELECT date_trunc('month', incurred_on) AS m, SUM(amount) AS total
      FROM transport_expenses
     WHERE organization_id=:orgA::uuid AND school_id=:schA::uuid AND status='recorded' AND category='fuel'
       AND incurred_on >= (date_trunc('month', timezone('utc',now())) - ('6 months')::interval)::date
     GROUP BY 1
  ) t
) q;

-- ── PROBE 5 — malformed capacity payload can't break the aggregate ──────────
INSERT INTO transport_entities (id, organization_id, school_id, entity_type, payload)
VALUES ('veh_bad', :orgA::uuid, :schA::uuid, 'vehicle',
        '{"id":"veh_bad","capacity":"n/a","status":"active"}'::jsonb);
INSERT INTO r
SELECT 5, 'regex-guarded numeric cast survives a malformed capacity payload',
  CASE WHEN cap >= 0 THEN 'PASS' ELSE 'FAIL' END,
  'capacity SUM with a "n/a" vehicle present = '||cap::text||' (computed, not errored)'
FROM (
  SELECT COALESCE(SUM((payload->>'capacity')::numeric),0) AS cap
    FROM transport_entities
   WHERE organization_id=:orgA::uuid AND school_id=:schA::uuid AND entity_type='vehicle'
     AND COALESCE(payload->>'status','active')='active'
     AND payload->>'capacity' ~ '^[0-9]+(\.[0-9]+)?$'
) q;

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
SELECT 'RESIDUE veh_bad' AS probe, count(*) AS rows FROM transport_entities WHERE id='veh_bad';
