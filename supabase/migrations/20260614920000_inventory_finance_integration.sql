-- v7.2 — Inventory–Finance integration (procurement, GRN, valuation, AP posting)

CREATE TABLE purchase_orders (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id UUID NOT NULL REFERENCES organizations (id),
  school_id UUID NOT NULL REFERENCES schools (id),
  vendor_id UUID NOT NULL REFERENCES inventory_vendors (id),
  po_number TEXT NOT NULL,
  status TEXT NOT NULL DEFAULT 'draft'
    CHECK (status IN ('draft', 'approved', 'partially_received', 'received', 'cancelled')),
  total_amount INTEGER NOT NULL DEFAULT 0,
  currency TEXT NOT NULL DEFAULT 'INR',
  requested_by UUID NOT NULL REFERENCES users (id),
  approved_by UUID REFERENCES users (id),
  approved_at TIMESTAMPTZ,
  notes TEXT NOT NULL DEFAULT '',
  created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),
  UNIQUE (organization_id, school_id, po_number)
);

CREATE TABLE purchase_order_lines (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  purchase_order_id UUID NOT NULL REFERENCES purchase_orders (id) ON DELETE CASCADE,
  organization_id UUID NOT NULL REFERENCES organizations (id),
  school_id UUID NOT NULL REFERENCES schools (id),
  sku TEXT NOT NULL,
  description TEXT NOT NULL DEFAULT '',
  quantity INTEGER NOT NULL CHECK (quantity > 0),
  unit_cost INTEGER NOT NULL CHECK (unit_cost >= 0),
  line_total INTEGER NOT NULL CHECK (line_total >= 0),
  quantity_received INTEGER NOT NULL DEFAULT 0 CHECK (quantity_received >= 0),
  created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now())
);

CREATE TABLE goods_receipts (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id UUID NOT NULL REFERENCES organizations (id),
  school_id UUID NOT NULL REFERENCES schools (id),
  purchase_order_id UUID NOT NULL REFERENCES purchase_orders (id),
  grn_number TEXT NOT NULL,
  received_by UUID NOT NULL REFERENCES users (id),
  received_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),
  status TEXT NOT NULL DEFAULT 'posted'
    CHECK (status IN ('draft', 'posted', 'cancelled')),
  created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),
  UNIQUE (organization_id, school_id, grn_number)
);

CREATE TABLE goods_receipt_lines (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  goods_receipt_id UUID NOT NULL REFERENCES goods_receipts (id) ON DELETE CASCADE,
  purchase_order_line_id UUID NOT NULL REFERENCES purchase_order_lines (id),
  organization_id UUID NOT NULL REFERENCES organizations (id),
  school_id UUID NOT NULL REFERENCES schools (id),
  quantity_received INTEGER NOT NULL CHECK (quantity_received > 0),
  created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now())
);

CREATE TABLE inventory_stock_valuations (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id UUID NOT NULL REFERENCES organizations (id),
  school_id UUID NOT NULL REFERENCES schools (id),
  sku TEXT NOT NULL,
  quantity_on_hand INTEGER NOT NULL DEFAULT 0,
  weighted_avg_cost INTEGER NOT NULL DEFAULT 0,
  last_valued_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),
  UNIQUE (organization_id, school_id, sku)
);

CREATE TABLE finance_ap_commitments (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id UUID NOT NULL REFERENCES organizations (id),
  school_id UUID NOT NULL REFERENCES schools (id),
  vendor_id UUID NOT NULL REFERENCES inventory_vendors (id),
  purchase_order_id UUID NOT NULL REFERENCES purchase_orders (id),
  commitment_number TEXT NOT NULL,
  amount INTEGER NOT NULL CHECK (amount >= 0),
  currency TEXT NOT NULL DEFAULT 'INR',
  status TEXT NOT NULL DEFAULT 'open'
    CHECK (status IN ('open', 'partially_paid', 'paid', 'cancelled')),
  created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),
  UNIQUE (organization_id, school_id, commitment_number)
);

CREATE TABLE inventory_finance_postings (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id UUID NOT NULL REFERENCES organizations (id),
  school_id UUID NOT NULL REFERENCES schools (id),
  purchase_order_id UUID NOT NULL REFERENCES purchase_orders (id),
  ap_commitment_id UUID NOT NULL REFERENCES finance_ap_commitments (id),
  posting_status TEXT NOT NULL DEFAULT 'posted'
    CHECK (posting_status IN ('pending', 'posted', 'failed', 'reversed')),
  ledger_refs JSONB NOT NULL DEFAULT '[]'::jsonb,
  posted_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now())
);

CREATE TABLE procurement_finance_links (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id UUID NOT NULL REFERENCES organizations (id),
  school_id UUID NOT NULL REFERENCES schools (id),
  purchase_order_id UUID NOT NULL REFERENCES purchase_orders (id),
  ap_commitment_id UUID NOT NULL REFERENCES finance_ap_commitments (id),
  finance_posting_id UUID NOT NULL REFERENCES inventory_finance_postings (id),
  posted_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),
  UNIQUE (purchase_order_id)
);

CREATE INDEX idx_purchase_orders_school ON purchase_orders (school_id, status);
CREATE INDEX idx_finance_ap_commitments_school ON finance_ap_commitments (school_id, status);

CREATE TRIGGER purchase_orders_updated_at BEFORE UPDATE ON purchase_orders
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE TRIGGER inventory_stock_valuations_updated_at BEFORE UPDATE ON inventory_stock_valuations
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE TRIGGER finance_ap_commitments_updated_at BEFORE UPDATE ON finance_ap_commitments
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE TRIGGER inventory_finance_postings_updated_at BEFORE UPDATE ON inventory_finance_postings
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

ALTER TABLE purchase_orders ENABLE ROW LEVEL SECURITY;
ALTER TABLE purchase_orders FORCE ROW LEVEL SECURITY;
ALTER TABLE purchase_order_lines ENABLE ROW LEVEL SECURITY;
ALTER TABLE purchase_order_lines FORCE ROW LEVEL SECURITY;
ALTER TABLE goods_receipts ENABLE ROW LEVEL SECURITY;
ALTER TABLE goods_receipts FORCE ROW LEVEL SECURITY;
ALTER TABLE goods_receipt_lines ENABLE ROW LEVEL SECURITY;
ALTER TABLE goods_receipt_lines FORCE ROW LEVEL SECURITY;
ALTER TABLE inventory_stock_valuations ENABLE ROW LEVEL SECURITY;
ALTER TABLE inventory_stock_valuations FORCE ROW LEVEL SECURITY;
ALTER TABLE finance_ap_commitments ENABLE ROW LEVEL SECURITY;
ALTER TABLE finance_ap_commitments FORCE ROW LEVEL SECURITY;
ALTER TABLE inventory_finance_postings ENABLE ROW LEVEL SECURITY;
ALTER TABLE inventory_finance_postings FORCE ROW LEVEL SECURITY;
ALTER TABLE procurement_finance_links ENABLE ROW LEVEL SECURITY;
ALTER TABLE procurement_finance_links FORCE ROW LEVEL SECURITY;

CREATE POLICY purchase_orders_school ON purchase_orders
  FOR ALL USING (
    organization_id = app_current_tenant_id()
    AND school_id = app_current_school_id()
    AND app_current_scope() IN ('school', 'organization')
  );

CREATE POLICY purchase_order_lines_school ON purchase_order_lines
  FOR ALL USING (
    organization_id = app_current_tenant_id()
    AND school_id = app_current_school_id()
    AND app_current_scope() IN ('school', 'organization')
  );

CREATE POLICY goods_receipts_school ON goods_receipts
  FOR ALL USING (
    organization_id = app_current_tenant_id()
    AND school_id = app_current_school_id()
    AND app_current_scope() IN ('school', 'organization')
  );

CREATE POLICY goods_receipt_lines_school ON goods_receipt_lines
  FOR ALL USING (
    organization_id = app_current_tenant_id()
    AND school_id = app_current_school_id()
    AND app_current_scope() IN ('school', 'organization')
  );

CREATE POLICY inventory_stock_valuations_school ON inventory_stock_valuations
  FOR ALL USING (
    organization_id = app_current_tenant_id()
    AND school_id = app_current_school_id()
    AND app_current_scope() IN ('school', 'organization')
  );

CREATE POLICY finance_ap_commitments_school ON finance_ap_commitments
  FOR ALL USING (
    organization_id = app_current_tenant_id()
    AND school_id = app_current_school_id()
    AND app_current_scope() IN ('school', 'organization')
  );

CREATE POLICY inventory_finance_postings_school ON inventory_finance_postings
  FOR ALL USING (
    organization_id = app_current_tenant_id()
    AND school_id = app_current_school_id()
    AND app_current_scope() IN ('school', 'organization')
  );

CREATE POLICY procurement_finance_links_school ON procurement_finance_links
  FOR ALL USING (
    organization_id = app_current_tenant_id()
    AND school_id = app_current_school_id()
    AND app_current_scope() IN ('school', 'organization')
  );

GRANT SELECT, INSERT, UPDATE ON purchase_orders TO erp_tenant;
GRANT SELECT, INSERT, UPDATE, DELETE ON purchase_order_lines TO erp_tenant;
GRANT SELECT, INSERT, UPDATE ON goods_receipts TO erp_tenant;
GRANT SELECT, INSERT, UPDATE, DELETE ON goods_receipt_lines TO erp_tenant;
GRANT SELECT, INSERT, UPDATE ON inventory_stock_valuations TO erp_tenant;
GRANT SELECT, INSERT, UPDATE ON finance_ap_commitments TO erp_tenant;
GRANT SELECT, INSERT, UPDATE ON inventory_finance_postings TO erp_tenant;
GRANT SELECT, INSERT ON procurement_finance_links TO erp_tenant;

-- Probe seeds
INSERT INTO purchase_orders (
  id, organization_id, school_id, vendor_id, po_number, status, total_amount,
  requested_by
) VALUES (
  'd8100000-0000-4000-8000-000000000001',
  'a1000000-0000-4000-8000-000000000001',
  'a2000000-0000-4000-8000-000000000001',
  'd8000000-0000-4000-8000-000000000001',
  'PO-PROBE-A', 'approved', 50000,
  'a3000000-0000-4000-8000-000000000001'
), (
  'd8100000-0000-4000-8000-000000000002',
  'a1000000-0000-4000-8000-000000000001',
  'a2000000-0000-4000-8000-000000000002',
  'd8000000-0000-4000-8000-000000000002',
  'PO-PROBE-B', 'approved', 30000,
  'a3000000-0000-4000-8000-000000000001'
) ON CONFLICT (id) DO NOTHING;

INSERT INTO finance_ap_commitments (
  id, organization_id, school_id, vendor_id, purchase_order_id,
  commitment_number, amount, status
) VALUES (
  'd8200000-0000-4000-8000-000000000001',
  'a1000000-0000-4000-8000-000000000001',
  'a2000000-0000-4000-8000-000000000001',
  'd8000000-0000-4000-8000-000000000001',
  'd8100000-0000-4000-8000-000000000001',
  'AP-PROBE-A', 50000, 'open'
), (
  'd8200000-0000-4000-8000-000000000002',
  'a1000000-0000-4000-8000-000000000001',
  'a2000000-0000-4000-8000-000000000002',
  'd8000000-0000-4000-8000-000000000002',
  'd8100000-0000-4000-8000-000000000002',
  'AP-PROBE-B', 30000, 'open'
) ON CONFLICT (id) DO NOTHING;
