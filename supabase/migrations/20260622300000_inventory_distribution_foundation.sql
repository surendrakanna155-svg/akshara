-- v9.7 Inventory Distribution Engine

CREATE TABLE inv_catalog_items (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id UUID NOT NULL REFERENCES organizations (id),
  school_id UUID NOT NULL REFERENCES schools (id),
  category TEXT NOT NULL
    CHECK (category IN (
      'books', 'uniforms', 'id_cards', 'belts',
      'stationery', 'lab_kits', 'sports_kits'
    )),
  name TEXT NOT NULL,
  sku_code TEXT,
  unit_price INTEGER NOT NULL DEFAULT 0,
  stock_on_hand INTEGER NOT NULL DEFAULT 0,
  status TEXT NOT NULL DEFAULT 'active'
    CHECK (status IN ('active', 'archived')),
  created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now())
);

CREATE INDEX idx_inv_catalog_school_category
  ON inv_catalog_items (organization_id, school_id, category);

CREATE TRIGGER inv_catalog_items_updated_at
  BEFORE UPDATE ON inv_catalog_items
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE TABLE inv_student_distributions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id UUID NOT NULL REFERENCES organizations (id),
  school_id UUID NOT NULL REFERENCES schools (id),
  student_id UUID NOT NULL,
  catalog_item_id UUID NOT NULL REFERENCES inv_catalog_items (id),
  quantity INTEGER NOT NULL DEFAULT 1 CHECK (quantity > 0),
  status TEXT NOT NULL DEFAULT 'available'
    CHECK (status IN (
      'received', 'available', 'distributed', 'parent_acknowledged',
      'replacement_requested', 'payment_pending', 'paid', 'reissued', 'cancelled'
    )),
  distributed_at TIMESTAMPTZ,
  acknowledged_at TIMESTAMPTZ,
  payment_request_id UUID REFERENCES payment_requests (id),
  replacement_of_id UUID REFERENCES inv_student_distributions (id),
  notes TEXT,
  created_by UUID REFERENCES users (id),
  created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now())
);

CREATE INDEX idx_inv_student_dist_student
  ON inv_student_distributions (organization_id, school_id, student_id, status);

CREATE TRIGGER inv_student_distributions_updated_at
  BEFORE UPDATE ON inv_student_distributions
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

ALTER TABLE inv_catalog_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE inv_catalog_items FORCE ROW LEVEL SECURITY;
ALTER TABLE inv_student_distributions ENABLE ROW LEVEL SECURITY;
ALTER TABLE inv_student_distributions FORCE ROW LEVEL SECURITY;

CREATE POLICY inv_catalog_school_scope ON inv_catalog_items
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

CREATE POLICY inv_student_dist_school_scope ON inv_student_distributions
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

CREATE POLICY inv_student_dist_parent_read ON inv_student_distributions
  FOR SELECT
  USING (
    organization_id = app_current_tenant_id()
    AND app_current_scope() = 'parent'
    AND student_id IN (
      SELECT sg.student_id
      FROM student_guardians sg
      WHERE sg.guardian_user_id = app_current_user_id()
        AND sg.organization_id = app_current_tenant_id()
        AND sg.status = 'active'
    )
  );

GRANT SELECT, INSERT, UPDATE, DELETE ON inv_catalog_items TO erp_tenant;
GRANT SELECT, INSERT, UPDATE, DELETE ON inv_student_distributions TO erp_tenant;
