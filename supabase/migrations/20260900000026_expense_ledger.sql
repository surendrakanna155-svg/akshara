-- W4 (Owner decision #4, FINAL) — canonical Expense Ledger.
--
-- A SINGLE source-of-truth expense ledger that aggregates real expenses from the
-- modules that already record cost (Payroll, Inventory purchases, Transport) and
-- is open for future adapters (Maintenance, Utilities, other). This is what
-- replaces the honestly-empty `expenseBreakdown: []` on the management dashboard
-- (PRA-P1-48) and underpins PRC-A caps 90–100.
--
-- DESIGN — an APPEND-ONLY audit ledger (stricter than transport_expenses):
--   * transport_expenses corrects a row by VOIDing it (needs UPDATE); this ledger
--     is a pure derived audit trail — an entry is NEVER updated or deleted, so the
--     grant is SELECT + INSERT only (no UPDATE, no DELETE). A wrong post is
--     superseded by a corrected re-post at the source, never mutated here.
--   * Idempotent per source expense: UNIQUE (organization_id, school_id,
--     source_module, source_ref) backs the repo's INSERT ... ON CONFLICT DO
--     NOTHING, so re-posting the same source expense (e.g. a payroll re-run
--     replay, or a nightly backfill) can never double-count.
--   * Amounts are the finance-standard NUMERIC rupees — the SAME unit every source
--     already stores (transport_expenses.amount, payroll_finance_postings.gross_
--     amount, purchase_orders.total_amount) — so no scaling / minor-unit
--     conversion is applied.
--   * RLS / grants mirror the per-school payroll_finance_postings + transport_
--     expenses tables (org + scope='school' + school). Migration number
--     20260900000026 is the next free slot after …019 in this band (…020–025 are
--     unused), clear of the Data-Reliability / PRC 20260877–20260890 band.

CREATE TABLE IF NOT EXISTS expense_ledger_entries (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id UUID NOT NULL REFERENCES organizations (id),
  school_id UUID NOT NULL REFERENCES schools (id),
  -- Which module the expense was incurred in. Enum-ish free-list kept tight so the
  -- by-source breakdown buckets reliably; 'maintenance'/'utilities'/'other' are
  -- declared now for future adapters (no adapter ships in this migration).
  source_module TEXT NOT NULL CHECK (source_module IN (
    'payroll', 'inventory', 'transport', 'maintenance', 'utilities', 'other'
  )),
  -- The id of the originating record in the source module (a transport_expenses
  -- uuid, a payroll_run_id TEXT, a purchase_orders uuid, …). TEXT so a free-form
  -- source id (payroll 'pay_1') and a uuid source id both fit. Half of the
  -- idempotency key.
  source_ref TEXT NOT NULL,
  -- Human/analytics expense category for the by-category breakdown (e.g. 'salary',
  -- 'fuel', 'procurement'). Distinct from source_module: many categories can share
  -- a module (transport → fuel/maintenance/insurance/…).
  category TEXT NOT NULL CHECK (length(trim(category)) > 0),
  amount NUMERIC(14, 2) NOT NULL CHECK (amount >= 0),
  incurred_on DATE NOT NULL,
  description TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),
  -- Idempotency: one ledger entry per (source expense) within a tenant/school.
  UNIQUE (organization_id, school_id, source_module, source_ref)
);

-- Covering index for the period aggregation (total / breakdown over a date range).
CREATE INDEX IF NOT EXISTS idx_expense_ledger_entries_period
  ON expense_ledger_entries (organization_id, school_id, incurred_on);

-- Covering index for the by-source breakdown + per-source backfill lookups.
CREATE INDEX IF NOT EXISTS idx_expense_ledger_entries_source
  ON expense_ledger_entries (organization_id, school_id, source_module);

ALTER TABLE expense_ledger_entries ENABLE ROW LEVEL SECURITY;
ALTER TABLE expense_ledger_entries FORCE ROW LEVEL SECURITY;

-- Identical scope to payroll_finance_postings / transport_expenses: a school
-- session sees/inserts only its own school's entries; cross-school / cross-tenant
-- rows are invisible.
DROP POLICY IF EXISTS expense_ledger_entries_school_scope ON expense_ledger_entries;
CREATE POLICY expense_ledger_entries_school_scope ON expense_ledger_entries
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

-- APPEND-ONLY: SELECT + INSERT only. Deliberately NO UPDATE and NO DELETE — this
-- is an immutable audit ledger. (Compare transport_expenses, which grants UPDATE
-- for its void flow; this ledger has no void — it is derived and corrected at the
-- source.)
GRANT SELECT, INSERT ON expense_ledger_entries TO erp_tenant;
