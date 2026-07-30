-- PRA-P0-24 (S7) — REAL payroll → Finance expense posting.
--
-- The S0 honesty-delete removed the false "payroll posts to Finance" UI claim;
-- this migration ships the actual ledger record. When a payroll run is PROCESSED
-- (disbursed) the run's totals are posted here as a per-school payroll
-- EXPENSE / DEMAND record — no cash movement, and the student-fee finance ledger
-- is never touched.
--
-- Why a new hr-owned table (not the inventory→finance tables): the inventory
-- precedent (approvePurchaseOrder → finance_ap_commitments + inventory_finance_
-- postings) is NOT reusable — its vendor_id / purchase_order_id are NOT NULL FKs
-- to UUID rows, whereas a payroll run lives in a JSONB snapshot keyed by a
-- free-form TEXT id ('pay_1') and has neither a vendor nor a UUID run row.
--
-- Idempotency: UNIQUE (organization_id, school_id, payroll_run_id) backs the
-- repo's INSERT ... ON CONFLICT DO NOTHING, so a re-process (already refused by
-- the 409 re-process guard in applyPayrollRun) can never double-post.
--
-- RLS / grants mirror the per-school hr_entities + finance_invoices tables
-- (school scope). Migration number 20260900000019 is the next free slot in the
-- feature/erp-pra-remediation band (…015–018 used), clear of the Data-Reliability
-- / PRC 20260877–20260890 band so a later merge cannot collide.

CREATE TABLE IF NOT EXISTS payroll_finance_postings (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id UUID NOT NULL REFERENCES organizations (id),
  school_id UUID NOT NULL REFERENCES schools (id),
  -- Payroll runs are JSONB-snapshot rows keyed by a free-form id, not a UUID.
  payroll_run_id TEXT NOT NULL,
  period TEXT NOT NULL DEFAULT '',
  -- gross = Σ(basic + allowances); net = Σ(net take-home). Both recorded so the
  -- expense (gross cost) and the disbursed amount (net) are each on record.
  gross_amount NUMERIC(14, 2) NOT NULL DEFAULT 0 CHECK (gross_amount >= 0),
  net_amount NUMERIC(14, 2) NOT NULL DEFAULT 0 CHECK (net_amount >= 0),
  employee_count INTEGER NOT NULL DEFAULT 0 CHECK (employee_count >= 0),
  -- Expense/demand record only (no cash movement). 'reversed' is reserved for a
  -- future correction flow; postings are never deleted.
  status TEXT NOT NULL DEFAULT 'posted'
    CHECK (status IN ('posted', 'reversed')),
  posted_by UUID REFERENCES users (id),
  posted_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),
  created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),
  UNIQUE (organization_id, school_id, payroll_run_id)
);

CREATE INDEX IF NOT EXISTS idx_payroll_finance_postings_school
  ON payroll_finance_postings (school_id, status);

CREATE TRIGGER payroll_finance_postings_updated_at
  BEFORE UPDATE ON payroll_finance_postings
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

ALTER TABLE payroll_finance_postings ENABLE ROW LEVEL SECURITY;
ALTER TABLE payroll_finance_postings FORCE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS payroll_finance_postings_school_scope ON payroll_finance_postings;
CREATE POLICY payroll_finance_postings_school_scope ON payroll_finance_postings
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

-- erp_tenant needs SELECT/INSERT/UPDATE (the ON CONFLICT DO NOTHING post + a
-- future reversal UPDATE); never DELETE — postings are permanent.
GRANT SELECT, INSERT, UPDATE ON payroll_finance_postings TO erp_tenant;
