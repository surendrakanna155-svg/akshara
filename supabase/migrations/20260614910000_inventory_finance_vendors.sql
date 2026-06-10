-- v7.2 Phase B Step 1 — Shared vendor master (Inventory–Finance foundation)

CREATE TABLE inventory_vendors (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id UUID NOT NULL REFERENCES organizations (id),
  school_id UUID NOT NULL REFERENCES schools (id),
  vendor_code TEXT NOT NULL,
  display_name TEXT NOT NULL,
  contact_phone TEXT,
  contact_email TEXT,
  gstin TEXT,
  status TEXT NOT NULL DEFAULT 'active'
    CHECK (status IN ('active', 'inactive', 'blocked')),
  metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
  created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),
  UNIQUE (organization_id, school_id, vendor_code)
);

CREATE INDEX idx_inventory_vendors_school ON inventory_vendors (school_id, status);

CREATE TRIGGER inventory_vendors_updated_at
  BEFORE UPDATE ON inventory_vendors
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

ALTER TABLE inventory_vendors ENABLE ROW LEVEL SECURITY;
ALTER TABLE inventory_vendors FORCE ROW LEVEL SECURITY;

CREATE POLICY inventory_vendors_school ON inventory_vendors
  FOR ALL USING (
    organization_id = app_current_tenant_id()
    AND school_id = app_current_school_id()
    AND app_current_scope() IN ('school', 'organization')
  );

GRANT SELECT, INSERT, UPDATE ON inventory_vendors TO erp_tenant;

-- Probe seeds
INSERT INTO inventory_vendors (
  id, organization_id, school_id, vendor_code, display_name, contact_phone, status
) VALUES (
  'd8000000-0000-4000-8000-000000000001',
  'a1000000-0000-4000-8000-000000000001',
  'a2000000-0000-4000-8000-000000000001',
  'VEND-A', 'Probe Vendor A', '+919876543210', 'active'
), (
  'd8000000-0000-4000-8000-000000000002',
  'a1000000-0000-4000-8000-000000000001',
  'a2000000-0000-4000-8000-000000000002',
  'VEND-B', 'Probe Vendor B', '+919876543211', 'active'
) ON CONFLICT (id) DO NOTHING;
