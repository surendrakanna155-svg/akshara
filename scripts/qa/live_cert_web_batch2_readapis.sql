-- WEB-004/006/010/001 LIVE CERT — the NEW SQL these read endpoints authored,
-- proven on real Postgres as the REAL erp_tenant role (what the fake DB can't
-- do: JOINs, GROUP BY, grants, RLS). BEGIN..ROLLBACK, zero residue.
-- Seed: org a1..01 / School1 a2..01 (1 stock item, 4 ai calls, 7 collections);
-- School2 a2..02 (1 collection). stock_adjustments + delivery_events empty.
\pset pager off
\set ORG  '''a1000000-0000-4000-8000-000000000001'''
\set SCH1 '''a2000000-0000-4000-8000-000000000001'''
\set SCH2 '''a2000000-0000-4000-8000-000000000002'''
\set USR  '''00000000-0000-4000-8000-0000000000aa'''

BEGIN;
CREATE TEMP TABLE res(probe text, detail text, pass boolean) ON COMMIT DROP;
GRANT INSERT, SELECT ON res TO erp_tenant;
SET ROLE erp_tenant;

SELECT set_request_context(:ORG::uuid, 'school', :USR::uuid, :SCH1::uuid);

-- ── WEB-004: stock levels (join + reorder + valuation + belowReorder) ──
INSERT INTO res
SELECT 'WEB004 P1 stock-levels query resolves (School1)', 'rows=' || count(*), count(*) = 1
FROM (
  SELECT sku, item_name, item_type, quantity_on_hand, reorder_level, weighted_avg_cost,
         quantity_on_hand * weighted_avg_cost AS value,
         quantity_on_hand <= reorder_level AS below_reorder
  FROM inventory_stock_valuations
  WHERE organization_id = :ORG::uuid AND school_id = :SCH1::uuid
  ORDER BY sku ASC LIMIT 500
) q;

-- ── WEB-004: approvals register resolves (empty table → 0, no error) ──
INSERT INTO res
SELECT 'WEB004 P2 approvals query resolves', 'rows=' || count(*), count(*) >= 0
FROM (
  SELECT id, status FROM stock_adjustments
  WHERE organization_id = :ORG::uuid AND school_id = :SCH1::uuid
  ORDER BY created_at DESC LIMIT 200
) q;

-- ── WEB-001: MTD collections (completed, month-to-date) resolves ──
INSERT INTO res
SELECT 'WEB001 P3 MTD-collections query resolves (School1)',
       'cnt=' || coalesce((SELECT count(*)::text FROM finance_collections
          WHERE organization_id = :ORG::uuid AND school_id = :SCH1::uuid
            AND collection_status = 'completed'
            AND collection_date >= date_trunc('month', CURRENT_DATE)), '0'),
       true;

-- ── WEB-001: attendance-today (canonical %) resolves ──
INSERT INTO res
SELECT 'WEB001 P4 attendance-today query resolves', 'rows=' || count(*), count(*) = 1
FROM (
  SELECT (count(*) FILTER (WHERE r.mark IN ('present','late')) + 0.5 * count(*) FILTER (WHERE r.mark = 'half_day'))::float8 AS attended,
         (count(*) - count(*) FILTER (WHERE r.mark = 'excused')) AS denom,
         count(DISTINCT r.session_id) AS sessions
  FROM attendance_records r
  JOIN attendance_sessions s ON s.id = r.session_id
  WHERE r.organization_id = :ORG::uuid AND r.school_id = :SCH1::uuid
    AND s.session_date = CURRENT_DATE AND s.status = 'submitted'
) q;

-- ── WEB-006: AI economics aggregate resolves + real data (4 calls) ──
INSERT INTO res
SELECT 'WEB006 P5 ai_call_log outcome aggregate resolves (School1)', 'calls=' || coalesce(sum(n)::text, '0'), coalesce(sum(n), 0) = 4
FROM (
  SELECT outcome, count(*) AS n, sum(estimated_cost_micros) AS cost
  FROM ai_call_log
  WHERE organization_id = :ORG::uuid AND school_id IS NOT DISTINCT FROM :SCH1::uuid
    AND created_at >= date_trunc('month', CURRENT_DATE)
  GROUP BY outcome
) q;

-- ── WEB-010: comms delivery-events + parent-adoption aggregates resolve ──
INSERT INTO res
SELECT 'WEB010 P6 delivery-events aggregate resolves', 'rows=' || count(*), count(*) >= 0
FROM (
  SELECT status, count(*) AS n FROM communication_delivery_events
  WHERE organization_id = :ORG::uuid AND school_id = :SCH1::uuid
  GROUP BY status
) q;
INSERT INTO res
SELECT 'WEB010 P7 parent-adoption (school_memberships) resolves', 'parents=' ||
       (SELECT count(*)::text FROM school_memberships WHERE school_id = :SCH1::uuid AND role = 'parent'),
       true;

-- ── RLS isolation: switch to School 2 context, each read sees ONLY School 2 ──
SELECT set_request_context(:ORG::uuid, 'school', :USR::uuid, :SCH2::uuid);
INSERT INTO res
SELECT 'ISO P8 stock: School2 context sees 0 (its own)', 'rows=' || count(*), count(*) = 0
FROM inventory_stock_valuations WHERE organization_id = :ORG::uuid AND school_id = :SCH2::uuid;
INSERT INTO res
SELECT 'ISO P9 RLS blocks School1 predicate from School2 ctx', 'rows=' || count(*), count(*) = 0
FROM inventory_stock_valuations WHERE organization_id = :ORG::uuid AND school_id = :SCH1::uuid;
INSERT INTO res
SELECT 'ISO P10 ai_call_log: School2 ctx sees 0', 'rows=' || count(*), count(*) = 0
FROM ai_call_log WHERE organization_id = :ORG::uuid AND school_id = :SCH1::uuid;
INSERT INTO res
SELECT 'ISO P11 finance_collections: School2 sees its 1, not School1 7', 'own=' || count(*), count(*) = 1
FROM finance_collections WHERE organization_id = :ORG::uuid AND school_id = :SCH2::uuid;

RESET ROLE;
SELECT probe, detail, CASE WHEN pass THEN 'PASS' ELSE 'FAIL' END AS verdict FROM res ORDER BY probe;
SELECT count(*) FILTER (WHERE pass) AS passed, count(*) FILTER (WHERE NOT pass) AS failed, count(*) AS total FROM res;
ROLLBACK;
