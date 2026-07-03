-- SIS-1 Certificate Issuance + SIS-D1 Transfer-Certificate (TC) engine.
--
-- Owner-approved (SIS-D1 default = "Yes to all"):
--   * Bonafide / Study / Conduct certificates are a RECORDED ISSUANCE — the
--     certificate DATA is sourced live from the existing student APIs and a row
--     is written to an immutable issuance register. No status change.
--   * The TRANSFER certificate is the TC engine and does three things in ONE
--     transaction, all audited:
--       (a) enforces a Finance NO-DUES gate (sum of open finance_student_accounts
--           outstanding must be 0 — the SAME authoritative per-year balance the
--           defaulters report reads),
--       (b) allocates a per-school SEQUENTIAL TC serial from a never-reused
--           counter (mirrors the PSID counter, 20260848000000), and
--       (c) auto-sets the student's SIS status -> transferred (via the status
--           codec's terminal-transition guard).
--
-- This migration:
--   1. sis_certificate_issues — the immutable issuance register (one row per
--      issued certificate). SELECT/INSERT only (no UPDATE/DELETE grant) — a
--      register is append-only. School-scope FORCE RLS.
--   2. school_tc_counters — the per-school TC serial counter, never reused,
--      same RLS/grant shape as school_public_id_counters.
--
-- Idempotent: CREATE ... IF NOT EXISTS, DROP/CREATE for triggers/policies.

-- ─── 1. Immutable certificate issuance register ──────────────────────────────

CREATE TABLE IF NOT EXISTS sis_certificate_issues (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id UUID NOT NULL REFERENCES organizations (id),
  school_id UUID NOT NULL REFERENCES schools (id),
  student_id UUID NOT NULL REFERENCES students (id),
  certificate_type TEXT NOT NULL
    CHECK (certificate_type IN ('bonafide', 'study', 'conduct', 'transfer')),
  serial_no TEXT,
  reason TEXT,
  issued_by UUID NOT NULL REFERENCES users (id),
  issued_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now())
);

CREATE INDEX IF NOT EXISTS idx_sis_certificate_issues_school_student
  ON sis_certificate_issues (school_id, student_id);

-- The TC serial is per-school unique when present (never reused). Partial so the
-- many bonafide/study/conduct rows (serial_no NULL) are unaffected.
CREATE UNIQUE INDEX IF NOT EXISTS uq_sis_certificate_issues_tc_serial
  ON sis_certificate_issues (school_id, serial_no)
  WHERE serial_no IS NOT NULL;

ALTER TABLE sis_certificate_issues ENABLE ROW LEVEL SECURITY;
ALTER TABLE sis_certificate_issues FORCE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS sis_certificate_issues_school_scope ON sis_certificate_issues;
CREATE POLICY sis_certificate_issues_school_scope ON sis_certificate_issues
  FOR ALL
  USING (
    organization_id = app_current_tenant_id()
    AND app_current_scope() = 'school'
    AND school_id = app_current_school_id()
  )
  WITH CHECK (
    organization_id = app_current_tenant_id()
    AND app_current_scope() = 'school'
    AND school_id = app_current_school_id()
  );

-- Issuances are an immutable register: SELECT + INSERT only. No UPDATE/DELETE
-- grant — a recorded certificate cannot be edited or removed.
GRANT SELECT, INSERT ON sis_certificate_issues TO erp_tenant;

-- ─── 2. Per-school never-reused TC serial counter ────────────────────────────
--
-- Mirrors school_public_id_counters exactly (20260848000000): a single row per
-- (org, school) whose next_seq is advanced by an atomic INSERT ... ON CONFLICT
-- DO UPDATE. The DO UPDATE takes a row-level lock, serializing concurrent TC
-- allocations for the same school so every serial is DISTINCT with no gaps.

CREATE TABLE IF NOT EXISTS school_tc_counters (
  organization_id UUID NOT NULL REFERENCES organizations (id),
  school_id UUID NOT NULL REFERENCES schools (id),
  next_seq INTEGER NOT NULL DEFAULT 1,
  created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),
  PRIMARY KEY (organization_id, school_id)
);

DROP TRIGGER IF EXISTS school_tc_counters_updated_at ON school_tc_counters;
CREATE TRIGGER school_tc_counters_updated_at
  BEFORE UPDATE ON school_tc_counters
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

ALTER TABLE school_tc_counters ENABLE ROW LEVEL SECURITY;
ALTER TABLE school_tc_counters FORCE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS school_tc_counters_school_scope ON school_tc_counters;
CREATE POLICY school_tc_counters_school_scope ON school_tc_counters
  FOR ALL
  USING (
    organization_id = app_current_tenant_id()
    AND app_current_scope() = 'school'
    AND school_id = app_current_school_id()
  )
  WITH CHECK (
    organization_id = app_current_tenant_id()
    AND app_current_scope() = 'school'
    AND school_id = app_current_school_id()
  );

GRANT SELECT, INSERT, UPDATE ON school_tc_counters TO erp_tenant;
