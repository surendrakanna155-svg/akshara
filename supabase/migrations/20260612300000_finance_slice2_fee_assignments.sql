-- v6.1 Sprint 3 Phase 4B2 — Finance Slice 2: Fee Assignments + Student Accounts
-- Architecture: v6.1-Finance-Implementation-Mapping.md §6

CREATE TABLE finance_fee_assignments (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id UUID NOT NULL REFERENCES organizations (id),
  school_id UUID NOT NULL REFERENCES schools (id),
  student_id UUID NOT NULL REFERENCES students (id),
  fee_structure_id UUID NOT NULL REFERENCES finance_fee_structures (id),
  academic_year TEXT NOT NULL,
  assignment_status TEXT NOT NULL DEFAULT 'active'
    CHECK (assignment_status IN ('active', 'cancelled')),
  assigned_by UUID NOT NULL REFERENCES users (id),
  assigned_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),
  created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),
  UNIQUE (student_id, fee_structure_id, academic_year)
);

CREATE INDEX idx_finance_fee_assignments_org_school
  ON finance_fee_assignments (organization_id, school_id);
CREATE INDEX idx_finance_fee_assignments_student
  ON finance_fee_assignments (student_id);
CREATE INDEX idx_finance_fee_assignments_structure
  ON finance_fee_assignments (fee_structure_id);

CREATE TRIGGER finance_fee_assignments_updated_at
  BEFORE UPDATE ON finance_fee_assignments
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE TABLE finance_student_accounts (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id UUID NOT NULL REFERENCES organizations (id),
  school_id UUID NOT NULL REFERENCES schools (id),
  student_id UUID NOT NULL REFERENCES students (id),
  fee_assignment_id UUID NOT NULL REFERENCES finance_fee_assignments (id),
  academic_year TEXT NOT NULL,
  total_fee NUMERIC(12, 2) NOT NULL DEFAULT 0,
  amount_paid NUMERIC(12, 2) NOT NULL DEFAULT 0,
  outstanding_amount NUMERIC(12, 2) NOT NULL DEFAULT 0,
  status TEXT NOT NULL DEFAULT 'open'
    CHECK (status IN ('open', 'closed')),
  created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),
  UNIQUE (student_id, academic_year)
);

CREATE INDEX idx_finance_student_accounts_org_school
  ON finance_student_accounts (organization_id, school_id);
CREATE INDEX idx_finance_student_accounts_student
  ON finance_student_accounts (student_id);
CREATE INDEX idx_finance_student_accounts_assignment
  ON finance_student_accounts (fee_assignment_id);

CREATE TRIGGER finance_student_accounts_updated_at
  BEFORE UPDATE ON finance_student_accounts
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

ALTER TABLE finance_fee_assignments ENABLE ROW LEVEL SECURITY;
ALTER TABLE finance_fee_assignments FORCE ROW LEVEL SECURITY;
ALTER TABLE finance_student_accounts ENABLE ROW LEVEL SECURITY;
ALTER TABLE finance_student_accounts FORCE ROW LEVEL SECURITY;

CREATE POLICY finance_fee_assignments_school_scope ON finance_fee_assignments
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

CREATE POLICY finance_student_accounts_school_scope ON finance_student_accounts
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

GRANT SELECT, INSERT, UPDATE ON finance_fee_assignments TO erp_tenant;
GRANT SELECT, INSERT, UPDATE ON finance_student_accounts TO erp_tenant;

-- Isolation probe fixtures (School A / School B)
INSERT INTO finance_fee_assignments (
  id, organization_id, school_id, student_id, fee_structure_id,
  academic_year, assignment_status, assigned_by
) VALUES
  (
    'b8000000-0000-4000-8000-000000000001',
    'a1000000-0000-4000-8000-000000000001',
    'a2000000-0000-4000-8000-000000000001',
    'a4000000-0000-4000-8000-000000000001',
    'b7000000-0000-4000-8000-000000000001',
    '2026-27', 'active',
    'a3000000-0000-4000-8000-000000000001'
  ),
  (
    'b8000000-0000-4000-8000-000000000002',
    'a1000000-0000-4000-8000-000000000001',
    'a2000000-0000-4000-8000-000000000002',
    'a4000000-0000-4000-8000-000000000002',
    'b7000000-0000-4000-8000-000000000002',
    '2026-27', 'active',
    'a3000000-0000-4000-8000-000000000001'
  );

INSERT INTO finance_student_accounts (
  id, organization_id, school_id, student_id, fee_assignment_id,
  academic_year, total_fee, amount_paid, outstanding_amount, status
) VALUES
  (
    'b8100000-0000-4000-8000-000000000001',
    'a1000000-0000-4000-8000-000000000001',
    'a2000000-0000-4000-8000-000000000001',
    'a4000000-0000-4000-8000-000000000001',
    'b8000000-0000-4000-8000-000000000001',
    '2026-27', 50000.00, 0, 50000.00, 'open'
  ),
  (
    'b8100000-0000-4000-8000-000000000002',
    'a1000000-0000-4000-8000-000000000001',
    'a2000000-0000-4000-8000-000000000002',
    'a4000000-0000-4000-8000-000000000002',
    'b8000000-0000-4000-8000-000000000002',
    '2026-27', 60000.00, 0, 60000.00, 'open'
  );
