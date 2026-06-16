-- Unified startup onboarding — tenant-scoped wizard state (resume + go-live).

CREATE TABLE startup_onboarding (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id UUID NOT NULL REFERENCES organizations (id),
  school_id UUID NOT NULL REFERENCES schools (id),
  current_step TEXT NOT NULL DEFAULT 'schoolProfile',
  school_name TEXT NOT NULL DEFAULT '',
  board TEXT NOT NULL DEFAULT '',
  curriculum TEXT NOT NULL DEFAULT 'CBSE',
  address TEXT NOT NULL DEFAULT '',
  contact_phone TEXT NOT NULL DEFAULT '',
  contact_email TEXT NOT NULL DEFAULT '',
  academic_year TEXT NOT NULL DEFAULT '',
  classes JSONB NOT NULL DEFAULT '[]'::jsonb,
  sections JSONB NOT NULL DEFAULT '[]'::jsonb,
  fee_model TEXT NOT NULL DEFAULT '',
  fee_categories JSONB NOT NULL DEFAULT '[]'::jsonb,
  logo_url TEXT NOT NULL DEFAULT '',
  theme_primary TEXT NOT NULL DEFAULT '#1565C0',
  theme_secondary TEXT NOT NULL DEFAULT '#42A5F5',
  branding_preferences JSONB NOT NULL DEFAULT '{}'::jsonb,
  default_language TEXT NOT NULL DEFAULT 'en',
  modules_enabled JSONB NOT NULL DEFAULT '["sis","finance","attendance"]'::jsonb,
  is_live BOOLEAN NOT NULL DEFAULT false,
  go_live_at TIMESTAMPTZ,
  created_by UUID REFERENCES users (id),
  updated_by UUID REFERENCES users (id),
  created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),
  UNIQUE (organization_id, school_id)
);

CREATE INDEX idx_startup_onboarding_school
  ON startup_onboarding (organization_id, school_id);

CREATE TRIGGER startup_onboarding_updated_at
  BEFORE UPDATE ON startup_onboarding
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

ALTER TABLE startup_onboarding ENABLE ROW LEVEL SECURITY;
ALTER TABLE startup_onboarding FORCE ROW LEVEL SECURITY;

CREATE POLICY startup_onboarding_school_scope ON startup_onboarding
  FOR ALL
  USING (
    organization_id = app_current_tenant_id()
    AND school_id = app_current_school_id()
  );

GRANT SELECT, INSERT, UPDATE ON startup_onboarding TO erp_tenant;
