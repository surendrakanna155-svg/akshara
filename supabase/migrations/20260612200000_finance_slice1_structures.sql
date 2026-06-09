-- v6.1 Sprint 3 Phase 4B1 — Finance Slice 1: Fee Structures
-- Architecture: v6.1-Finance-Implementation-Mapping.md §3.1 (slice 1)

CREATE TABLE finance_fee_structures (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id UUID NOT NULL REFERENCES organizations (id),
  school_id UUID NOT NULL REFERENCES schools (id),
  name TEXT NOT NULL,
  academic_year TEXT NOT NULL,
  description TEXT,
  status TEXT NOT NULL DEFAULT 'active'
    CHECK (status IN ('active', 'inactive')),
  created_by UUID NOT NULL REFERENCES users (id),
  created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now())
);

CREATE INDEX idx_finance_fee_structures_org_school
  ON finance_fee_structures (organization_id, school_id);
CREATE INDEX idx_finance_fee_structures_org_school_year
  ON finance_fee_structures (organization_id, school_id, academic_year);

CREATE TRIGGER finance_fee_structures_updated_at
  BEFORE UPDATE ON finance_fee_structures
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE TABLE finance_fee_structure_items (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  fee_structure_id UUID NOT NULL REFERENCES finance_fee_structures (id) ON DELETE CASCADE,
  organization_id UUID NOT NULL REFERENCES organizations (id),
  school_id UUID NOT NULL REFERENCES schools (id),
  fee_head TEXT NOT NULL,
  amount NUMERIC(12, 2) NOT NULL,
  sort_order INTEGER NOT NULL DEFAULT 0,
  created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now())
);

CREATE INDEX idx_finance_fee_structure_items_structure
  ON finance_fee_structure_items (fee_structure_id);
CREATE INDEX idx_finance_fee_structure_items_org_school
  ON finance_fee_structure_items (organization_id, school_id);

ALTER TABLE finance_fee_structures ENABLE ROW LEVEL SECURITY;
ALTER TABLE finance_fee_structures FORCE ROW LEVEL SECURITY;
ALTER TABLE finance_fee_structure_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE finance_fee_structure_items FORCE ROW LEVEL SECURITY;

-- School staff only — no org or parent policies (TD-P0-01 / Phase 4B1)
CREATE POLICY finance_fee_structures_school_scope ON finance_fee_structures
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

CREATE POLICY finance_fee_structure_items_school_scope ON finance_fee_structure_items
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

GRANT SELECT, INSERT, UPDATE, DELETE ON finance_fee_structures TO erp_tenant;
GRANT SELECT, INSERT, UPDATE, DELETE ON finance_fee_structure_items TO erp_tenant;

-- Isolation probe fixtures (School A / School B)
INSERT INTO finance_fee_structures (
  id, organization_id, school_id, name, academic_year, description, status, created_by
) VALUES
  (
    'b7000000-0000-4000-8000-000000000001',
    'a1000000-0000-4000-8000-000000000001',
    'a2000000-0000-4000-8000-000000000001',
    'Probe Structure A', '2026-27', 'Classes 1-5', 'active',
    'a3000000-0000-4000-8000-000000000001'
  ),
  (
    'b7000000-0000-4000-8000-000000000002',
    'a1000000-0000-4000-8000-000000000001',
    'a2000000-0000-4000-8000-000000000002',
    'Probe Structure B', '2026-27', 'Classes 6-10', 'active',
    'a3000000-0000-4000-8000-000000000001'
  );

INSERT INTO finance_fee_structure_items (
  id, fee_structure_id, organization_id, school_id, fee_head, amount, sort_order
) VALUES
  (
    'b7100000-0000-4000-8000-000000000001',
    'b7000000-0000-4000-8000-000000000001',
    'a1000000-0000-4000-8000-000000000001',
    'a2000000-0000-4000-8000-000000000001',
    'tuition:Annual Tuition', 50000.00, 0
  ),
  (
    'b7100000-0000-4000-8000-000000000002',
    'b7000000-0000-4000-8000-000000000002',
    'a1000000-0000-4000-8000-000000000001',
    'a2000000-0000-4000-8000-000000000002',
    'tuition:Annual Tuition', 60000.00, 0
  );
