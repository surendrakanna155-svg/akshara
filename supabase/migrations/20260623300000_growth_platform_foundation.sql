-- v11.0 — School Growth Platform Foundation

CREATE TABLE growth_campaigns (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id UUID NOT NULL REFERENCES organizations (id),
  school_id UUID NOT NULL REFERENCES schools (id),
  name TEXT NOT NULL,
  channel TEXT NOT NULL
    CHECK (channel IN ('website', 'walk_in', 'referral', 'whatsapp', 'facebook', 'google_ads', 'other')),
  status TEXT NOT NULL DEFAULT 'active'
    CHECK (status IN ('draft', 'active', 'paused', 'completed')),
  budget_inr NUMERIC(12, 2),
  start_date DATE,
  end_date DATE,
  metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
  created_by UUID REFERENCES users (id),
  created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now())
);

CREATE TABLE growth_inquiries (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id UUID NOT NULL REFERENCES organizations (id),
  school_id UUID NOT NULL REFERENCES schools (id),
  campaign_id UUID REFERENCES growth_campaigns (id) ON DELETE SET NULL,
  lead_id UUID,
  parent_name TEXT NOT NULL,
  phone TEXT,
  grade_interest TEXT,
  source TEXT NOT NULL,
  status TEXT NOT NULL DEFAULT 'new'
    CHECK (status IN ('new', 'contacted', 'visit_scheduled', 'converted', 'lost')),
  follow_up_at TIMESTAMPTZ,
  notes TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now())
);

CREATE INDEX idx_growth_campaigns_school ON growth_campaigns (organization_id, school_id, status);
CREATE INDEX idx_growth_inquiries_school ON growth_inquiries (organization_id, school_id, status);
CREATE INDEX idx_growth_inquiries_campaign ON growth_inquiries (campaign_id);

CREATE TRIGGER growth_campaigns_updated_at
  BEFORE UPDATE ON growth_campaigns
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER growth_inquiries_updated_at
  BEFORE UPDATE ON growth_inquiries
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

ALTER TABLE growth_campaigns ENABLE ROW LEVEL SECURITY;
ALTER TABLE growth_campaigns FORCE ROW LEVEL SECURITY;
ALTER TABLE growth_inquiries ENABLE ROW LEVEL SECURITY;
ALTER TABLE growth_inquiries FORCE ROW LEVEL SECURITY;

CREATE POLICY growth_campaigns_school_scope ON growth_campaigns
  FOR ALL USING (organization_id = app_current_tenant_id() AND school_id = app_current_school_id());

CREATE POLICY growth_inquiries_school_scope ON growth_inquiries
  FOR ALL USING (organization_id = app_current_tenant_id() AND school_id = app_current_school_id());

GRANT SELECT, INSERT, UPDATE ON growth_campaigns TO erp_tenant;
GRANT SELECT, INSERT, UPDATE ON growth_inquiries TO erp_tenant;
