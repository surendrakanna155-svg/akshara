-- v7.6 — Analytics & Intelligence foundation

CREATE TABLE analytics_score_snapshots (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id UUID NOT NULL REFERENCES organizations (id),
  school_id UUID NOT NULL REFERENCES schools (id),
  snapshot_type TEXT NOT NULL DEFAULT 'daily'
    CHECK (snapshot_type IN ('daily', 'weekly', 'manual')),
  scores JSONB NOT NULL DEFAULT '{}'::jsonb,
  computed_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),
  created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now())
);

CREATE INDEX idx_analytics_snapshots_school
  ON analytics_score_snapshots (organization_id, school_id, computed_at DESC);

ALTER TABLE analytics_score_snapshots ENABLE ROW LEVEL SECURITY;
ALTER TABLE analytics_score_snapshots FORCE ROW LEVEL SECURITY;

CREATE POLICY analytics_snapshots_school ON analytics_score_snapshots
  FOR ALL USING (
    organization_id = app_current_tenant_id()
    AND school_id = app_current_school_id()
    AND app_current_scope() IN ('school', 'organization')
  );

GRANT SELECT, INSERT ON analytics_score_snapshots TO erp_tenant;

INSERT INTO permission_definitions (slug, module, action, scope, description) VALUES
  ('viewAnalytics', 'Analytics', 'view', 'school', 'View analytics dashboards and trends'),
  ('viewSchoolHealth', 'Analytics', 'view', 'school', 'View school health scores and composition')
ON CONFLICT (slug) DO NOTHING;

INSERT INTO role_permissions (role_slug, permission_slug) VALUES
  ('superAdmin', 'viewAnalytics'),
  ('superAdmin', 'viewSchoolHealth'),
  ('schoolAdmin', 'viewAnalytics'),
  ('schoolAdmin', 'viewSchoolHealth'),
  ('principal', 'viewAnalytics'),
  ('principal', 'viewSchoolHealth'),
  ('management', 'viewAnalytics'),
  ('management', 'viewSchoolHealth')
ON CONFLICT DO NOTHING;

INSERT INTO analytics_score_snapshots (
  id, organization_id, school_id, snapshot_type, scores
) VALUES
  (
    'd0600000-0000-4000-8000-000000000001',
    'a1000000-0000-4000-8000-000000000001',
    'a2000000-0000-4000-8000-000000000001',
    'daily',
    '{"schoolHealthScore": 82}'::jsonb
  ),
  (
    'd0600000-0000-4000-8000-000000000002',
    'a1000000-0000-4000-8000-000000000001',
    'a2000000-0000-4000-8000-000000000002',
    'daily',
    '{"schoolHealthScore": 74}'::jsonb
  )
ON CONFLICT (id) DO NOTHING;
