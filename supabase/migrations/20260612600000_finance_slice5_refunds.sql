-- v6.1 Sprint 3 Phase 4B5 — Finance Refunds Foundation

ALTER TABLE finance_collections DROP CONSTRAINT IF EXISTS finance_collections_collection_status_check;
ALTER TABLE finance_collections ADD CONSTRAINT finance_collections_collection_status_check
  CHECK (collection_status IN (
    'draft', 'completed', 'cancelled', 'partially_refunded', 'refunded'
  ));

CREATE TABLE finance_refunds (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id UUID NOT NULL REFERENCES organizations (id),
  school_id UUID NOT NULL REFERENCES schools (id),
  invoice_id UUID NOT NULL REFERENCES finance_invoices (id),
  collection_id UUID NOT NULL REFERENCES finance_collections (id),
  student_account_id UUID NOT NULL REFERENCES finance_student_accounts (id),
  refund_amount NUMERIC(12, 2) NOT NULL CHECK (refund_amount > 0),
  refund_reason TEXT NOT NULL,
  refund_status TEXT NOT NULL DEFAULT 'pending'
    CHECK (refund_status IN ('pending', 'approved', 'rejected', 'processed')),
  approved_by UUID REFERENCES users (id),
  requested_by UUID NOT NULL REFERENCES users (id),
  approved_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now())
);

CREATE INDEX idx_finance_refunds_org_school
  ON finance_refunds (organization_id, school_id);
CREATE INDEX idx_finance_refunds_collection
  ON finance_refunds (collection_id);
CREATE INDEX idx_finance_refunds_invoice
  ON finance_refunds (invoice_id);
CREATE INDEX idx_finance_refunds_student_account
  ON finance_refunds (student_account_id);
CREATE INDEX idx_finance_refunds_status
  ON finance_refunds (school_id, refund_status, created_at DESC);

CREATE TRIGGER finance_refunds_updated_at
  BEFORE UPDATE ON finance_refunds
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

ALTER TABLE finance_refunds ENABLE ROW LEVEL SECURITY;
ALTER TABLE finance_refunds FORCE ROW LEVEL SECURITY;

CREATE POLICY finance_refunds_school_scope ON finance_refunds
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

GRANT SELECT, INSERT, UPDATE ON finance_refunds TO erp_tenant;

-- Align School A probe collection / invoice / account balances (5000 collected)
UPDATE finance_invoices SET
  outstanding_amount = 45000.00,
  invoice_status = 'partially_paid',
  updated_at = timezone('utc', now())
WHERE id = 'b9000000-0000-4000-8000-000000000001';

UPDATE finance_student_accounts SET
  amount_paid = 5000.00,
  outstanding_amount = 45000.00,
  updated_at = timezone('utc', now())
WHERE id = 'b8100000-0000-4000-8000-000000000001';

-- Processed refund fixture (2000) — balances already applied for probe verification
INSERT INTO finance_refunds (
  id, organization_id, school_id, invoice_id, collection_id, student_account_id,
  refund_amount, refund_reason, refund_status, approved_by, requested_by, approved_at
) VALUES (
  'bb000000-0000-4000-8000-000000000001',
  'a1000000-0000-4000-8000-000000000001',
  'a2000000-0000-4000-8000-000000000001',
  'b9000000-0000-4000-8000-000000000001',
  'ba000000-0000-4000-8000-000000000001',
  'b8100000-0000-4000-8000-000000000001',
  2000.00,
  'Probe processed refund',
  'processed',
  'a3000000-0000-4000-8000-000000000001',
  'a3000000-0000-4000-8000-000000000001',
  timezone('utc', now())
);

UPDATE finance_invoices SET
  outstanding_amount = 47000.00,
  invoice_status = 'partially_paid',
  updated_at = timezone('utc', now())
WHERE id = 'b9000000-0000-4000-8000-000000000001';

UPDATE finance_student_accounts SET
  amount_paid = 3000.00,
  outstanding_amount = 47000.00,
  updated_at = timezone('utc', now())
WHERE id = 'b8100000-0000-4000-8000-000000000001';

UPDATE finance_collections SET
  collection_status = 'partially_refunded',
  updated_at = timezone('utc', now())
WHERE id = 'ba000000-0000-4000-8000-000000000001';

-- Pending refund (School A visibility)
INSERT INTO finance_refunds (
  id, organization_id, school_id, invoice_id, collection_id, student_account_id,
  refund_amount, refund_reason, refund_status, requested_by
) VALUES (
  'bb000000-0000-4000-8000-000000000003',
  'a1000000-0000-4000-8000-000000000001',
  'a2000000-0000-4000-8000-000000000001',
  'b9000000-0000-4000-8000-000000000001',
  'ba000000-0000-4000-8000-000000000001',
  'b8100000-0000-4000-8000-000000000001',
  1000.00,
  'Probe pending refund',
  'pending',
  'a3000000-0000-4000-8000-000000000001'
);

-- School B refund (cross-school isolation)
INSERT INTO finance_refunds (
  id, organization_id, school_id, invoice_id, collection_id, student_account_id,
  refund_amount, refund_reason, refund_status, requested_by
) VALUES (
  'bb000000-0000-4000-8000-000000000002',
  'a1000000-0000-4000-8000-000000000001',
  'a2000000-0000-4000-8000-000000000002',
  'b9000000-0000-4000-8000-000000000002',
  'ba000000-0000-4000-8000-000000000002',
  'b8100000-0000-4000-8000-000000000002',
  1500.00,
  'Probe School B refund',
  'pending',
  'a3000000-0000-4000-8000-000000000001'
);
