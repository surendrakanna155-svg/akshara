-- WEB-007 (ERP-WT-007) LIVE CERT — GET /finance/student-accounts paginated list.
-- Proves what the fake-DB test harness structurally CANNOT (PRC-A-D-04): the
-- multi-table JOIN + LATERAL projection resolves on real Postgres, RLS isolates
-- the list per school, pagination/COUNT are correct, and the free-text filter
-- predicate is wired. Runs as the REAL erp_tenant role inside BEGIN..ROLLBACK.
--
-- Seed: org a1000000-…-01 has two schools (…-01, …-02), 1 account each.
\pset pager off
\set ORG   '''a1000000-0000-4000-8000-000000000001'''
\set SCH1  '''a2000000-0000-4000-8000-000000000001'''
\set SCH2  '''a2000000-0000-4000-8000-000000000002'''
\set USR   '''00000000-0000-4000-8000-0000000000aa'''

BEGIN;
CREATE TEMP TABLE r(probe text, detail text, pass boolean) ON COMMIT DROP;
GRANT INSERT, SELECT ON r TO erp_tenant;

SET ROLE erp_tenant;

-- ============================ School 1 context ============================
SELECT set_request_context(:ORG::uuid, 'school', :USR::uuid, :SCH1::uuid);

-- P1: the exact list projection resolves for School 1 (the JOIN the fake DB can't evaluate).
INSERT INTO r
SELECT 'P1 list projection resolves for School 1', 'rows=' || count(*), count(*) = 1
FROM (
  SELECT a.id, a.student_id, a.fee_assignment_id, a.academic_year,
         a.total_fee, a.amount_paid, a.outstanding_amount, a.status,
         COALESCE(h.student_name, s.display_name) AS student_name,
         h.admission_number, h.class_label,
         fa.fee_structure_id, fs.name AS fee_structure_name
  FROM finance_student_accounts a
  LEFT JOIN students s
    ON s.id = a.student_id AND s.organization_id = a.organization_id AND s.school_id = a.school_id
  LEFT JOIN finance_fee_assignments fa
    ON fa.id = a.fee_assignment_id AND fa.organization_id = a.organization_id AND fa.school_id = a.school_id
  LEFT JOIN finance_fee_structures fs
    ON fs.id = fa.fee_structure_id AND fs.organization_id = a.organization_id AND fs.school_id = a.school_id
  LEFT JOIN LATERAL (
    SELECT admission_number, class_label, student_name
    FROM admissions_fee_handoffs h2
    WHERE h2.student_id = a.student_id AND h2.organization_id = a.organization_id AND h2.school_id = a.school_id
    ORDER BY h2.created_at DESC LIMIT 1
  ) h ON true
  WHERE a.organization_id = :ORG::uuid AND a.school_id = :SCH1::uuid
  ORDER BY COALESCE(h.student_name, s.display_name) ASC NULLS LAST, a.created_at DESC
  LIMIT 20 OFFSET 0
) q;

-- P2: COUNT (the `total`) matches the page set for School 1.
INSERT INTO r
SELECT 'P2 COUNT total = 1 for School 1', 'count=' || count(*), count(*) = 1
FROM finance_student_accounts a
WHERE a.organization_id = :ORG::uuid AND a.school_id = :SCH1::uuid;

-- P3: RLS isolation — School 1 context but predicate names School 2 → 0 rows
--     (the app filter cannot be used to escape the tenant; RLS forces school 1).
INSERT INTO r
SELECT 'P3 RLS blocks cross-school predicate', 'rows=' || count(*), count(*) = 0
FROM finance_student_accounts a
WHERE a.organization_id = :ORG::uuid AND a.school_id = :SCH2::uuid;

-- P4: pagination — page 2 (offset 20) past a 1-row set → 0 rows, hasMore=false.
INSERT INTO r
SELECT 'P4 pagination offset past end → empty', 'rows=' || count(*), count(*) = 0
FROM (
  SELECT a.id FROM finance_student_accounts a
  WHERE a.organization_id = :ORG::uuid AND a.school_id = :SCH1::uuid
  ORDER BY a.created_at DESC LIMIT 20 OFFSET 20
) q;

-- P5: free-text filter predicate is wired — a non-matching q returns 0 rows.
INSERT INTO r
SELECT 'P5 q filter excludes non-matches', 'rows=' || count(*), count(*) = 0
FROM (
  SELECT a.id
  FROM finance_student_accounts a
  LEFT JOIN students s
    ON s.id = a.student_id AND s.organization_id = a.organization_id AND s.school_id = a.school_id
  LEFT JOIN LATERAL (
    SELECT admission_number
    FROM admissions_fee_handoffs h2
    WHERE h2.student_id = a.student_id AND h2.organization_id = a.organization_id AND h2.school_id = a.school_id
    ORDER BY h2.created_at DESC LIMIT 1
  ) h ON true
  WHERE a.organization_id = :ORG::uuid AND a.school_id = :SCH1::uuid
    AND (s.display_name ILIKE '%zzz_no_such_student_zzz%' OR h.admission_number ILIKE '%zzz_no_such_student_zzz%')
) q;

-- ============================ School 2 context ============================
SELECT set_request_context(:ORG::uuid, 'school', :USR::uuid, :SCH2::uuid);

-- P6: each tenant sees ONLY its own account (School 2 → exactly School 2's row).
INSERT INTO r
SELECT 'P6 School 2 context sees only its 1 account', 'rows=' || count(*), count(*) = 1
FROM finance_student_accounts a
WHERE a.organization_id = :ORG::uuid AND a.school_id = :SCH2::uuid;

-- P7: RLS — School 2 context querying School 1's predicate → 0 rows (symmetric isolation).
INSERT INTO r
SELECT 'P7 RLS blocks reverse cross-school predicate', 'rows=' || count(*), count(*) = 0
FROM finance_student_accounts a
WHERE a.organization_id = :ORG::uuid AND a.school_id = :SCH1::uuid;

RESET ROLE;
SELECT probe, detail, CASE WHEN pass THEN 'PASS' ELSE 'FAIL' END AS verdict FROM r ORDER BY probe;
SELECT count(*) FILTER (WHERE pass) AS passed, count(*) FILTER (WHERE NOT pass) AS failed, count(*) AS total FROM r;
ROLLBACK;
