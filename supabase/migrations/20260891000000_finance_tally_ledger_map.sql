-- PRC-A Batch 7 — Tally / accounting export (owner-future-idea 11).
--
-- The audit found: zero accounting-export coverage. Schools re-key every fee
-- receipt into Tally by hand. This adds a Tally-importable Receipt-voucher export
-- built off the EXISTING finance_collections ledger (status='completed'), plus a
-- per-school ledger-name map so the exported vouchers land on the right Tally
-- ledgers.
--
-- DESIGN — honest scope:
--   * Each completed collection → ONE Tally Receipt voucher: Dr <cash/bank ledger
--     by payment method>, Cr <fee income ledger>. Correct double-entry.
--   * There is NO per-collection head split in the schema (finance_collections
--     carries a single amount_collected; head-wise paid amounts live only at the
--     INVOICE level in finance_invoice_head_allocations). Deriving a per-receipt
--     per-head credit would fabricate precision the data does not have, so the
--     export credits a single configurable Fee Income ledger — head-level GL is
--     deliberately out of scope, not faked.
--   * The export is READ-only off certified money data; it never mutates finance.

CREATE TABLE finance_tally_ledger_map (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id UUID NOT NULL REFERENCES organizations (id),
  school_id UUID NOT NULL REFERENCES schools (id),
  -- Tally ledger names the vouchers post to. Defaults are the conventional Tally
  -- ledger names so an unconfigured school still gets an importable file.
  cash_ledger TEXT NOT NULL DEFAULT 'Cash',
  bank_ledger TEXT NOT NULL DEFAULT 'Bank',
  fee_income_ledger TEXT NOT NULL DEFAULT 'Fee Income',
  -- Optional per-payment-method overrides, e.g. {"upi":"HDFC Bank","card":"HDFC Bank"}.
  -- A method not present here falls back to cash_ledger (cash) or bank_ledger (all
  -- non-cash methods).
  method_ledger_overrides JSONB NOT NULL DEFAULT '{}'::jsonb,
  -- Optional Tally company name stamped into the export header (SVCURRENTCOMPANY).
  company_name TEXT,
  is_active BOOLEAN NOT NULL DEFAULT true,
  created_by UUID,
  created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),
  CONSTRAINT finance_tally_ledger_map_ledgers_nonempty CHECK (
    length(btrim(cash_ledger)) > 0
    AND length(btrim(bank_ledger)) > 0
    AND length(btrim(fee_income_ledger)) > 0
  )
);

CREATE UNIQUE INDEX idx_finance_tally_ledger_map_school
  ON finance_tally_ledger_map (organization_id, school_id);

CREATE TRIGGER finance_tally_ledger_map_updated_at
  BEFORE UPDATE ON finance_tally_ledger_map FOR EACH ROW EXECUTE FUNCTION set_updated_at();

ALTER TABLE finance_tally_ledger_map ENABLE ROW LEVEL SECURITY;
ALTER TABLE finance_tally_ledger_map FORCE ROW LEVEL SECURITY;

-- School-scoped manage, mirroring the finance operational scoping (a school
-- session sees/edits only its own school's map; cross-school/cross-tenant rows
-- are invisible).
CREATE POLICY finance_tally_ledger_map_school_manage ON finance_tally_ledger_map
  FOR ALL USING (
    organization_id = app_current_tenant_id()
    AND app_current_scope() = 'school'
    AND school_id = app_current_school_id()
  ) WITH CHECK (
    organization_id = app_current_tenant_id()
    AND app_current_scope() = 'school'
    AND school_id = app_current_school_id()
  );

-- No DELETE: the map is retired via is_active, keeping the configured ledger
-- names as an audit record (consistent with the append-only bias across PRC-A).
GRANT SELECT, INSERT, UPDATE ON finance_tally_ledger_map TO erp_tenant;

-- RBAC: reuse the EXISTING viewFinance (read/export) + manageFinance (configure)
-- permissions — the export is a finance read and the map is a finance setting;
-- no new slug is minted.
