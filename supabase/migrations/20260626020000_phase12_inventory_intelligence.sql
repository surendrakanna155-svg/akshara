-- Phase 12 — Inventory Intelligence (v13.4)

CREATE TABLE asset_lifecycle_events (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id UUID NOT NULL REFERENCES organizations (id),
  school_id UUID NOT NULL REFERENCES schools (id),
  asset_id TEXT NOT NULL,
  asset_tag TEXT NOT NULL DEFAULT '',
  event_type TEXT NOT NULL
    CHECK (event_type IN ('purchase', 'distribution', 'replacement', 'damage', 'retirement')),
  notes TEXT NOT NULL DEFAULT '',
  metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
  recorded_by UUID REFERENCES users (id),
  recorded_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),
  created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now())
);

CREATE INDEX idx_asset_lifecycle_events_school
  ON asset_lifecycle_events (organization_id, school_id, asset_id, recorded_at DESC);

CREATE INDEX idx_asset_lifecycle_events_type
  ON asset_lifecycle_events (organization_id, school_id, event_type, recorded_at DESC);

CREATE TABLE inventory_intelligence_snapshots (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id UUID NOT NULL REFERENCES organizations (id),
  school_id UUID NOT NULL REFERENCES schools (id),
  snapshot_type TEXT NOT NULL
    CHECK (snapshot_type IN ('copilot', 'lifecycle', 'procurement')),
  payload JSONB NOT NULL DEFAULT '{}'::jsonb,
  computed_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),
  created_by UUID REFERENCES users (id)
);

CREATE INDEX idx_inventory_intel_snapshots_school
  ON inventory_intelligence_snapshots (organization_id, school_id, snapshot_type, computed_at DESC);

ALTER TABLE asset_lifecycle_events ENABLE ROW LEVEL SECURITY;
ALTER TABLE asset_lifecycle_events FORCE ROW LEVEL SECURITY;
ALTER TABLE inventory_intelligence_snapshots ENABLE ROW LEVEL SECURITY;
ALTER TABLE inventory_intelligence_snapshots FORCE ROW LEVEL SECURITY;

CREATE POLICY asset_lifecycle_events_scope ON asset_lifecycle_events
  FOR ALL USING (
    organization_id = app_current_tenant_id()
    AND school_id = app_current_school_id()
  );

CREATE POLICY inventory_intel_snapshots_scope ON inventory_intelligence_snapshots
  FOR ALL USING (
    organization_id = app_current_tenant_id()
    AND school_id = app_current_school_id()
  );

GRANT SELECT, INSERT ON asset_lifecycle_events TO erp_tenant;
GRANT SELECT, INSERT ON inventory_intelligence_snapshots TO erp_tenant;
