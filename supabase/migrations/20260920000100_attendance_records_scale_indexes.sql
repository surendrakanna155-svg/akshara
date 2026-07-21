-- ICA-C1 (P1, Performance) — attendance_records missing tenant/student indexes.
--
-- Root cause: attendance_records (created in 20260614800000_pilot_operations.sql)
-- has only PRIMARY KEY (id) and UNIQUE (session_id, student_id). Every tenant-
-- scoped hot read filters on (organization_id, school_id[, student_id]) with no
-- supporting index, so each falls back to a sequential scan. This is fine at
-- pilot row counts but gates multi-school scale-out: the risk board runs its
-- attendance sub-select once PER active student (LEFT JOIN LATERAL), turning a
-- seq scan into an O(students × rows) hotspot.
--
-- Predicates served (verified against the live queries on this trunk):
--   1. Parent snapshot overlay — pilot/pilot_operations_repository.ts:929
--        WHERE ar.organization_id = $1 AND ar.school_id = $2 AND ar.student_id = $3
--        -> idx_attendance_records_student  (org, school, student — full match)
--   2. Risk board LATERAL, per active student — intelligence/student_risk_repository.ts:100
--        WHERE ar.student_id = s.id AND ar.organization_id = $1 AND ar.school_id = $2
--        -> idx_attendance_records_student  (all-equality, full match)
--   3. Director dashboard rollup — director/director_repository.ts:135
--        WHERE organization_id = $1 GROUP BY school_id
--        -> idx_attendance_records_org_school  (org leads scan; school ordered for GROUP BY)
--   4. Director single-school card — director/director_repository.ts:724
--        WHERE organization_id = $1 AND school_id = $2
--        -> idx_attendance_records_org_school  (full 2-col match)
--   5. Management class aggregate — management/management_aggregate_repository.ts:119
--        WHERE ar.organization_id = $1 AND ar.school_id = $2 ... GROUP BY class
--        -> idx_attendance_records_org_school  (full 2-col match)
--
-- Column order rationale: all cited filters are equality on organization_id then
-- school_id (the tenant hierarchy), optionally student_id. Leading with
-- (organization_id, school_id) makes the same prefix serve the org+school
-- aggregate reads (3/4/5) while the third column serves the per-student reads
-- (1/2). The narrower (organization_id, school_id) index is a deliberate keep:
-- the aggregate/GROUP BY reads scan a whole org|school range and never touch
-- student_id, so a smaller index is cheaper to scan (fewer pages) and lets the
-- director rollup satisfy GROUP BY school_id from index order without a sort.
--
-- Deliberately NOT indexed here: attendance_sessions.session_date / any date
-- predicate for the session listing — that belongs to ICA-C3 (separate file).
-- Both statements use IF NOT EXISTS for safe re-runs.

CREATE INDEX IF NOT EXISTS idx_attendance_records_student
  ON attendance_records (organization_id, school_id, student_id);

CREATE INDEX IF NOT EXISTS idx_attendance_records_org_school
  ON attendance_records (organization_id, school_id);
