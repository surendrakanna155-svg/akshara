-- PRA-P1-08 (S1) — gapless per-school, per-financial-year receipt sequence.
--
-- Owner-approved Option A. The legacy random receipt number (RCPT-<year>-<uuid>)
-- is not orderable, gap-ridden by construction and org-wide, which fails the
-- statutory requirement for a per-school sequential receipt register. This table
-- backs a monotonic per-(school, financial-year) counter.
--
-- Migration number: deliberately placed at 20260900000000 to stay CLEAR of the
-- Data-Reliability / PRC lane's 20260877–20260890 band, so a later merge of the
-- feature/erp-pra-remediation branch cannot collide with those migrations.
--
-- Design (see finance_collections_repository.allocateReceiptNumber):
--   * The number is allocated INSIDE the collection's transaction, immediately
--     before the collection row is written — a rollback undoes the increment, so
--     a failed collection never burns a number.
--   * Numbers are NEVER reused. A cancelled collection keeps its receipt_number
--     (status 'cancelled'), so a voided number stays permanently on record.
--   * Roll-out is feature-gated per school via the finance_settings
--     'receipts.receipt_sequencing' flag (default off) — when off, the legacy
--     random number is used, so existing receipts are untouched and both formats
--     coexist under the existing UNIQUE(receipt_number) constraint.

CREATE TABLE IF NOT EXISTS finance_receipt_sequences (
  organization_id UUID NOT NULL REFERENCES organizations (id),
  school_id UUID NOT NULL REFERENCES schools (id),
  -- Indian financial year label, e.g. '2026-27' (April–March).
  fiscal_year TEXT NOT NULL,
  next_number BIGINT NOT NULL DEFAULT 1 CHECK (next_number >= 1),
  created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),
  PRIMARY KEY (organization_id, school_id, fiscal_year)
);

ALTER TABLE finance_receipt_sequences ENABLE ROW LEVEL SECURITY;
ALTER TABLE finance_receipt_sequences FORCE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS finance_receipt_sequences_access ON finance_receipt_sequences;
CREATE POLICY finance_receipt_sequences_access ON finance_receipt_sequences
  FOR ALL
  USING (
    organization_id = app_current_tenant_id()
    AND school_id = app_current_school_id()
    AND app_current_scope() = 'school'
  )
  WITH CHECK (
    organization_id = app_current_tenant_id()
    AND school_id = app_current_school_id()
    AND app_current_scope() = 'school'
  );

-- erp_tenant needs SELECT/INSERT/UPDATE (the atomic INSERT ... ON CONFLICT DO
-- UPDATE allocation); never DELETE (numbers are permanent).
GRANT SELECT, INSERT, UPDATE ON finance_receipt_sequences TO erp_tenant;
