-- Phase 11 — Finance Intelligence (v13.3)

CREATE TABLE finance_intelligence_snapshots (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id UUID NOT NULL REFERENCES organizations (id),
  school_id UUID NOT NULL REFERENCES schools (id),
  snapshot_type TEXT NOT NULL
    CHECK (snapshot_type IN ('copilot', 'executive')),
  payload JSONB NOT NULL DEFAULT '{}'::jsonb,
  computed_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),
  created_by UUID REFERENCES users (id)
);

CREATE INDEX idx_finance_intel_snapshots_school
  ON finance_intelligence_snapshots (organization_id, school_id, snapshot_type, computed_at DESC);

ALTER TABLE finance_intelligence_snapshots ENABLE ROW LEVEL SECURITY;
ALTER TABLE finance_intelligence_snapshots FORCE ROW LEVEL SECURITY;

CREATE POLICY finance_intel_snapshots_scope ON finance_intelligence_snapshots
  FOR ALL USING (
    organization_id = app_current_tenant_id()
    AND school_id = app_current_school_id()
  );

GRANT SELECT, INSERT ON finance_intelligence_snapshots TO erp_tenant;
