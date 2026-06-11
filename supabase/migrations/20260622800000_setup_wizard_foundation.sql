-- v10.5 — AI School Setup Wizard

CREATE TABLE setup_wizard_sessions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id UUID NOT NULL REFERENCES organizations (id),
  school_id UUID NOT NULL REFERENCES schools (id),
  status TEXT NOT NULL DEFAULT 'in_progress'
    CHECK (status IN ('in_progress', 'completed', 'abandoned')),
  current_step TEXT NOT NULL DEFAULT 'school_profile',
  inputs JSONB NOT NULL DEFAULT '{}'::jsonb,
  recommendations JSONB NOT NULL DEFAULT '{}'::jsonb,
  warnings JSONB NOT NULL DEFAULT '[]'::jsonb,
  missing_items JSONB NOT NULL DEFAULT '[]'::jsonb,
  created_by UUID REFERENCES users (id),
  created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now())
);

CREATE INDEX idx_setup_wizard_sessions_school
  ON setup_wizard_sessions (organization_id, school_id, status);

CREATE TRIGGER setup_wizard_sessions_updated_at
  BEFORE UPDATE ON setup_wizard_sessions
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

ALTER TABLE setup_wizard_sessions ENABLE ROW LEVEL SECURITY;
ALTER TABLE setup_wizard_sessions FORCE ROW LEVEL SECURITY;

CREATE POLICY setup_wizard_school_scope ON setup_wizard_sessions
  FOR ALL
  USING (
    organization_id = app_current_tenant_id()
    AND school_id = app_current_school_id()
  );

GRANT SELECT, INSERT, UPDATE ON setup_wizard_sessions TO erp_tenant;
