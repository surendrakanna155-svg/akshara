-- Phase 15 — Communication Analytics

CREATE TABLE communication_campaigns (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id UUID NOT NULL REFERENCES organizations (id),
  school_id UUID NOT NULL REFERENCES schools (id),
  campaign_code TEXT NOT NULL,
  campaign_name TEXT NOT NULL,
  channel TEXT NOT NULL DEFAULT 'in_app',
  template_code TEXT,
  target_audience TEXT NOT NULL DEFAULT 'all_parents',
  status TEXT NOT NULL DEFAULT 'draft'
    CHECK (status IN ('draft', 'scheduled', 'active', 'completed', 'cancelled')),
  scheduled_at TIMESTAMPTZ,
  sent_count INT NOT NULL DEFAULT 0,
  delivered_count INT NOT NULL DEFAULT 0,
  failed_count INT NOT NULL DEFAULT 0,
  opened_count INT NOT NULL DEFAULT 0,
  responded_count INT NOT NULL DEFAULT 0,
  created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),
  UNIQUE (organization_id, school_id, campaign_code)
);

CREATE INDEX idx_comm_campaigns_school
  ON communication_campaigns (organization_id, school_id, status);

ALTER TABLE communication_campaigns ENABLE ROW LEVEL SECURITY;
ALTER TABLE communication_campaigns FORCE ROW LEVEL SECURITY;

CREATE POLICY comm_campaigns_scope ON communication_campaigns
  FOR ALL USING (
    organization_id = app_current_tenant_id()
    AND school_id = app_current_school_id()
  );

GRANT SELECT, INSERT, UPDATE ON communication_campaigns TO erp_tenant;

CREATE TABLE communication_engagement_events (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id UUID NOT NULL REFERENCES organizations (id),
  school_id UUID NOT NULL REFERENCES schools (id),
  campaign_id UUID REFERENCES communication_campaigns (id) ON DELETE SET NULL,
  delivery_event_id UUID REFERENCES communication_delivery_events (id) ON DELETE SET NULL,
  event_type TEXT NOT NULL
    CHECK (event_type IN ('opened', 'clicked', 'responded', 'dismissed')),
  parent_user_id UUID,
  channel TEXT NOT NULL,
  recorded_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now())
);

CREATE INDEX idx_comm_engagement_school
  ON communication_engagement_events (organization_id, school_id, recorded_at DESC);

ALTER TABLE communication_engagement_events ENABLE ROW LEVEL SECURITY;
ALTER TABLE communication_engagement_events FORCE ROW LEVEL SECURITY;

CREATE POLICY comm_engagement_scope ON communication_engagement_events
  FOR ALL USING (
    organization_id = app_current_tenant_id()
    AND school_id = app_current_school_id()
  );

GRANT SELECT, INSERT, UPDATE ON communication_engagement_events TO erp_tenant;

CREATE TABLE parent_engagement_snapshots (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id UUID NOT NULL REFERENCES organizations (id),
  school_id UUID NOT NULL REFERENCES schools (id),
  parent_user_id UUID NOT NULL,
  engagement_score INT NOT NULL DEFAULT 0 CHECK (engagement_score BETWEEN 0 AND 100),
  messages_read_30d INT NOT NULL DEFAULT 0,
  app_sessions_30d INT NOT NULL DEFAULT 0,
  last_active_at TIMESTAMPTZ,
  computed_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),
  UNIQUE (organization_id, school_id, parent_user_id)
);

CREATE INDEX idx_parent_engagement_school
  ON parent_engagement_snapshots (organization_id, school_id, engagement_score DESC);

ALTER TABLE parent_engagement_snapshots ENABLE ROW LEVEL SECURITY;
ALTER TABLE parent_engagement_snapshots FORCE ROW LEVEL SECURITY;

CREATE POLICY parent_engagement_scope ON parent_engagement_snapshots
  FOR ALL USING (
    organization_id = app_current_tenant_id()
    AND school_id = app_current_school_id()
  );

GRANT SELECT, INSERT, UPDATE ON parent_engagement_snapshots TO erp_tenant;
