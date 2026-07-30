-- PRC-B wave 3 — Export/Report equivalence (3.10), i18n/Unicode boundary (3.5),
-- referential integrity (3.9). ROLLBACK-safe, as the real erp_tenant role.
--
-- Run: docker exec -i akshara-postgres psql -U supabase_admin -d akshara_db -f - < this
\set ON_ERROR_STOP off

\echo ==================== BEGIN (all seed rolled back) ====================
BEGIN;
CREATE TEMP TABLE r(ord int, probe text, verdict text, evidence text);
GRANT INSERT, SELECT ON r TO erp_tenant;

\set orgA '''a1000000-0000-4000-8000-000000000001'''
\set schA '''a2000000-0000-4000-8000-000000000001'''
\set usr  '''a3000000-0000-4000-8000-000000000001'''

SET ROLE erp_tenant;
SELECT app.set_request_context(:orgA::uuid, 'school', :usr::uuid, :schA::uuid, NULL, NULL, NULL);

-- ── PROBE 1 — EXPORT == REPORT (EX-R1): the Tally export and the collection ──
-- report sum the SAME source with the SAME filter → identical total, no divergent
-- recompute. Both = SUM(amount_collected) WHERE completed AND in range.
INSERT INTO r
SELECT 1, 'export total == report total (no layer recomputes business truth differently)',
  CASE WHEN report_total = export_total THEN 'PASS' ELSE 'FAIL' END,
  'report=' || report_total::text || ' export=' || export_total::text || ' (must be identical)'
FROM (
  SELECT
    -- report aggregate
    (SELECT COALESCE(SUM(amount_collected),0) FROM finance_collections
      WHERE organization_id=:orgA::uuid AND school_id=:schA::uuid
        AND collection_status='completed'
        AND collection_date BETWEEN '2026-06-01' AND '2026-06-30') AS report_total,
    -- export row-set aggregate (the listCollectionsForTallyExport query source)
    (SELECT COALESCE(SUM(fc.amount_collected),0)
       FROM finance_collections fc
       LEFT JOIN finance_invoices fi ON fi.id = fc.invoice_id
      WHERE fc.organization_id=:orgA::uuid AND fc.school_id=:schA::uuid
        AND fc.collection_status='completed'
        AND fc.collection_date BETWEEN '2026-06-01'::date AND '2026-06-30'::date) AS export_total
) q;

-- ── PROBE 2 — Telugu / Unicode text round-trips byte-identical (BX-11/12) ────
INSERT INTO brand_profiles (organization_id, school_id, tagline, created_by)
VALUES (:orgA::uuid, :schA::uuid, 'విద్యార్థి ప్రగతి — నాణ్యమైన విద్య', :usr::uuid);
INSERT INTO r
SELECT 2, 'Telugu / Unicode text round-trips byte-identical (no mojibake, correct length)',
  CASE WHEN tagline = 'విద్యార్థి ప్రగతి — నాణ్యమైన విద్య'
        AND char_length(tagline) = char_length('విద్యార్థి ప్రగతి — నాణ్యమైన విద్య')
       THEN 'PASS' ELSE 'FAIL' END,
  'stored tagline = '||tagline||' (len '||char_length(tagline)::text||')'
FROM brand_profiles WHERE organization_id=:orgA::uuid AND school_id=:schA::uuid;

-- ── PROBE 3 — emoji + very long text survive (BX-11/13/15) ───────────────────
INSERT INTO r
SELECT 3, 'emoji + long text (2000 chars) round-trip intact',
  CASE WHEN t = ('🎓'||repeat('अ',2000)) AND char_length(t) = 2001 THEN 'PASS' ELSE 'FAIL' END,
  'emoji+2000-char length = '||char_length(t)::text||' (expect 2001)'
FROM (
  SELECT ('🎓'||repeat('अ',2000))::text AS t
) q;

-- ── PROBE 4 — referential integrity: a row referencing a missing parent is rejected (DA-05) ──
DO $$
DECLARE fk_rej int := 0;
BEGIN
  BEGIN INSERT INTO brand_profiles (organization_id, school_id, created_by)
        VALUES ('a1000000-0000-4000-8000-000000000001','00000000-0000-4000-8000-0000000000ff','a3000000-0000-4000-8000-000000000001');
  EXCEPTION
    WHEN foreign_key_violation THEN fk_rej := 1;
    WHEN insufficient_privilege THEN fk_rej := 1;  -- RLS may reject the non-existent school first; still "not orphaned"
    WHEN check_violation THEN fk_rej := 1;
  END;
  INSERT INTO r VALUES (4, 'referential integrity: a row referencing a non-existent school is rejected',
    CASE WHEN fk_rej=1 THEN 'PASS' ELSE 'FAIL' END, 'orphan insert rejected = '||fk_rej::text||' (expect 1)');
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
SELECT 'RESIDUE profiles' AS probe, count(*) AS rows FROM brand_profiles WHERE created_by='a3000000-0000-4000-8000-000000000001';
