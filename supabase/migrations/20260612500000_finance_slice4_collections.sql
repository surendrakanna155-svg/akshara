-- v6.1 Sprint 3 Phase 4B4A — Finance Collections & Receipts
-- Architecture: v6.1-Finance-Implementation-Mapping.md

CREATE TABLE finance_collections (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id UUID NOT NULL REFERENCES organizations (id),
  school_id UUID NOT NULL REFERENCES schools (id),
  student_id UUID NOT NULL REFERENCES students (id),
  invoice_id UUID NOT NULL REFERENCES finance_invoices (id),
  student_account_id UUID NOT NULL REFERENCES finance_student_accounts (id),
  receipt_number TEXT NOT NULL,
  collection_date DATE NOT NULL DEFAULT CURRENT_DATE,
  payment_method TEXT NOT NULL,
  reference_number TEXT,
  amount_collected NUMERIC(12, 2) NOT NULL
    CHECK (amount_collected > 0),
  notes TEXT,
  collection_status TEXT NOT NULL DEFAULT 'completed'
    CHECK (collection_status IN ('draft', 'completed', 'cancelled')),
  collected_by UUID NOT NULL REFERENCES users (id),
  created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now())
);

CREATE TABLE finance_receipts (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id UUID NOT NULL REFERENCES organizations (id),
  school_id UUID NOT NULL REFERENCES schools (id),
  collection_id UUID NOT NULL REFERENCES finance_collections (id),
  receipt_number TEXT NOT NULL UNIQUE,
  receipt_date DATE NOT NULL DEFAULT CURRENT_DATE,
  amount NUMERIC(12, 2) NOT NULL CHECK (amount > 0),
  generated_by UUID NOT NULL REFERENCES users (id),
  created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now())
);

CREATE INDEX idx_finance_collections_org_school
  ON finance_collections (organization_id, school_id);
CREATE INDEX idx_finance_collections_invoice
  ON finance_collections (invoice_id);
CREATE INDEX idx_finance_collections_student_account
  ON finance_collections (student_account_id);
CREATE INDEX idx_finance_collections_status_date
  ON finance_collections (school_id, collection_status, collection_date DESC);

CREATE INDEX idx_finance_receipts_org_school
  ON finance_receipts (organization_id, school_id);
CREATE INDEX idx_finance_receipts_collection
  ON finance_receipts (collection_id);

CREATE TRIGGER finance_collections_updated_at
  BEFORE UPDATE ON finance_collections
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

ALTER TABLE finance_collections ENABLE ROW LEVEL SECURITY;
ALTER TABLE finance_collections FORCE ROW LEVEL SECURITY;
ALTER TABLE finance_receipts ENABLE ROW LEVEL SECURITY;
ALTER TABLE finance_receipts FORCE ROW LEVEL SECURITY;

CREATE POLICY finance_collections_school_scope ON finance_collections
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

CREATE POLICY finance_receipts_school_scope ON finance_receipts
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

GRANT SELECT, INSERT, UPDATE ON finance_collections TO erp_tenant;
GRANT SELECT, INSERT ON finance_receipts TO erp_tenant;

-- Isolation probe fixtures (School A / School B) — visibility only
INSERT INTO finance_collections (
  id, organization_id, school_id, student_id, invoice_id, student_account_id,
  receipt_number, collection_date, payment_method, amount_collected,
  collection_status, collected_by
) VALUES
  (
    'ba000000-0000-4000-8000-000000000001',
    'a1000000-0000-4000-8000-000000000001',
    'a2000000-0000-4000-8000-000000000001',
    'a4000000-0000-4000-8000-000000000001',
    'b9000000-0000-4000-8000-000000000001',
    'b8100000-0000-4000-8000-000000000001',
    'RCPT-PROBE-A-2026',
    CURRENT_DATE,
    'cash',
    5000.00,
    'completed',
    'a3000000-0000-4000-8000-000000000001'
  ),
  (
    'ba000000-0000-4000-8000-000000000002',
    'a1000000-0000-4000-8000-000000000001',
    'a2000000-0000-4000-8000-000000000002',
    'a4000000-0000-4000-8000-000000000002',
    'b9000000-0000-4000-8000-000000000002',
    'b8100000-0000-4000-8000-000000000002',
    'RCPT-PROBE-B-2026',
    CURRENT_DATE,
    'upi',
    6000.00,
    'completed',
    'a3000000-0000-4000-8000-000000000001'
  );

INSERT INTO finance_receipts (
  id, organization_id, school_id, collection_id,
  receipt_number, receipt_date, amount, generated_by
) VALUES
  (
    'ba100000-0000-4000-8000-000000000001',
    'a1000000-0000-4000-8000-000000000001',
    'a2000000-0000-4000-8000-000000000001',
    'ba000000-0000-4000-8000-000000000001',
    'RCPT-PROBE-A-2026',
    CURRENT_DATE,
    5000.00,
    'a3000000-0000-4000-8000-000000000001'
  ),
  (
    'ba100000-0000-4000-8000-000000000002',
    'a1000000-0000-4000-8000-000000000001',
    'a2000000-0000-4000-8000-000000000002',
    'ba000000-0000-4000-8000-000000000002',
    'RCPT-PROBE-B-2026',
    CURRENT_DATE,
    6000.00,
    'a3000000-0000-4000-8000-000000000001'
  );
