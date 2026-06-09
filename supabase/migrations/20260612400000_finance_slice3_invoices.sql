-- v6.1 Sprint 3 Phase 4B3A — Finance Invoices (core foundation)
-- Architecture: v6.1-Finance-Invoices-Mapping.md

CREATE TABLE finance_invoices (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id UUID NOT NULL REFERENCES organizations (id),
  school_id UUID NOT NULL REFERENCES schools (id),
  student_id UUID NOT NULL REFERENCES students (id),
  fee_assignment_id UUID NOT NULL REFERENCES finance_fee_assignments (id),
  academic_year TEXT NOT NULL,
  invoice_number TEXT NOT NULL,
  invoice_date DATE NOT NULL DEFAULT CURRENT_DATE,
  due_date DATE NOT NULL,
  subtotal_amount NUMERIC(12, 2) NOT NULL DEFAULT 0,
  discount_amount NUMERIC(12, 2) NOT NULL DEFAULT 0,
  total_amount NUMERIC(12, 2) NOT NULL DEFAULT 0,
  outstanding_amount NUMERIC(12, 2) NOT NULL DEFAULT 0,
  invoice_status TEXT NOT NULL DEFAULT 'draft'
    CHECK (invoice_status IN ('draft', 'issued', 'partially_paid', 'paid', 'cancelled')),
  created_by UUID NOT NULL REFERENCES users (id),
  created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),
  UNIQUE (fee_assignment_id),
  UNIQUE (school_id, invoice_number)
);

CREATE INDEX idx_finance_invoices_org_school
  ON finance_invoices (organization_id, school_id);
CREATE INDEX idx_finance_invoices_student
  ON finance_invoices (student_id);
CREATE INDEX idx_finance_invoices_assignment
  ON finance_invoices (fee_assignment_id);
CREATE INDEX idx_finance_invoices_status_due
  ON finance_invoices (school_id, invoice_status, due_date);

CREATE TRIGGER finance_invoices_updated_at
  BEFORE UPDATE ON finance_invoices
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

ALTER TABLE finance_invoices ENABLE ROW LEVEL SECURITY;
ALTER TABLE finance_invoices FORCE ROW LEVEL SECURITY;

CREATE POLICY finance_invoices_school_scope ON finance_invoices
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

GRANT SELECT, INSERT, UPDATE ON finance_invoices TO erp_tenant;

-- Migration-safe backfill: exactly one issued invoice per existing fee assignment (4B2 → 4B3A).
-- Idempotent via NOT EXISTS; preserves probe fixture IDs for isolation tests.
INSERT INTO finance_invoices (
  id, organization_id, school_id, student_id, fee_assignment_id,
  academic_year, invoice_number, invoice_date, due_date,
  subtotal_amount, discount_amount, total_amount, outstanding_amount,
  invoice_status, created_by
)
SELECT
  CASE fa.id::text
    WHEN 'b8000000-0000-4000-8000-000000000001'
      THEN 'b9000000-0000-4000-8000-000000000001'::uuid
    WHEN 'b8000000-0000-4000-8000-000000000002'
      THEN 'b9000000-0000-4000-8000-000000000002'::uuid
    ELSE gen_random_uuid()
  END,
  fa.organization_id,
  fa.school_id,
  fa.student_id,
  fa.id,
  fa.academic_year,
  CASE fa.id::text
    WHEN 'b8000000-0000-4000-8000-000000000001' THEN 'INV-PROBE-A-2026'
    WHEN 'b8000000-0000-4000-8000-000000000002' THEN 'INV-PROBE-B-2026'
    ELSE 'INV-' || replace(fa.academic_year, '-', '') || '-' || upper(substr(replace(fa.id::text, '-', ''), 1, 8))
  END,
  CURRENT_DATE,
  CURRENT_DATE + 30,
  COALESCE(fsa.total_fee, 0),
  0,
  COALESCE(fsa.total_fee, 0),
  COALESCE(fsa.outstanding_amount, fsa.total_fee, 0),
  'issued',
  fa.assigned_by
FROM finance_fee_assignments fa
LEFT JOIN finance_student_accounts fsa
  ON fsa.fee_assignment_id = fa.id
 AND fsa.organization_id = fa.organization_id
 AND fsa.school_id = fa.school_id
WHERE NOT EXISTS (
  SELECT 1 FROM finance_invoices fi WHERE fi.fee_assignment_id = fa.id
);
