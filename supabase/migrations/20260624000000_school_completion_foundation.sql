-- Phase 8 — School Completion foundation tables

CREATE TABLE academic_subjects (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id UUID NOT NULL REFERENCES organizations (id),
  school_id UUID NOT NULL REFERENCES schools (id),
  subject_code TEXT NOT NULL,
  subject_name TEXT NOT NULL,
  category TEXT NOT NULL DEFAULT 'core'
    CHECK (category IN ('core', 'elective', 'language', 'activity')),
  grade_labels JSONB NOT NULL DEFAULT '[]'::jsonb,
  status TEXT NOT NULL DEFAULT 'active'
    CHECK (status IN ('active', 'inactive')),
  created_by UUID REFERENCES users (id),
  created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),
  UNIQUE (organization_id, school_id, subject_code)
);

CREATE INDEX idx_academic_subjects_school
  ON academic_subjects (organization_id, school_id, status);

CREATE TRIGGER academic_subjects_updated_at
  BEFORE UPDATE ON academic_subjects
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

ALTER TABLE academic_subjects ENABLE ROW LEVEL SECURITY;
ALTER TABLE academic_subjects FORCE ROW LEVEL SECURITY;

CREATE POLICY academic_subjects_school_scope ON academic_subjects
  FOR ALL
  USING (
    organization_id = app_current_tenant_id()
    AND school_id = app_current_school_id()
  );

GRANT SELECT, INSERT, UPDATE ON academic_subjects TO erp_tenant;

CREATE TABLE teacher_lesson_logs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id UUID NOT NULL REFERENCES organizations (id),
  school_id UUID NOT NULL REFERENCES schools (id),
  teacher_user_id UUID NOT NULL REFERENCES users (id),
  class_name TEXT NOT NULL,
  section_name TEXT,
  subject_id UUID REFERENCES academic_subjects (id) ON DELETE SET NULL,
  topic TEXT NOT NULL,
  outcome TEXT NOT NULL DEFAULT 'completed'
    CHECK (outcome IN ('completed', 'needs_revision', 'partial', 'cancelled')),
  notes TEXT,
  recorded_on DATE NOT NULL DEFAULT CURRENT_DATE,
  created_by UUID REFERENCES users (id),
  created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now())
);

CREATE INDEX idx_teacher_lesson_logs_teacher
  ON teacher_lesson_logs (organization_id, school_id, teacher_user_id, recorded_on DESC);

CREATE INDEX idx_teacher_lesson_logs_class
  ON teacher_lesson_logs (organization_id, school_id, class_name, recorded_on DESC);

CREATE TRIGGER teacher_lesson_logs_updated_at
  BEFORE UPDATE ON teacher_lesson_logs
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

ALTER TABLE teacher_lesson_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE teacher_lesson_logs FORCE ROW LEVEL SECURITY;

CREATE POLICY teacher_lesson_logs_school_scope ON teacher_lesson_logs
  FOR ALL
  USING (
    organization_id = app_current_tenant_id()
    AND school_id = app_current_school_id()
  );

GRANT SELECT, INSERT, UPDATE ON teacher_lesson_logs TO erp_tenant;

CREATE TABLE school_branding (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id UUID NOT NULL REFERENCES organizations (id),
  school_id UUID NOT NULL REFERENCES schools (id),
  display_name TEXT,
  tagline TEXT,
  primary_color TEXT NOT NULL DEFAULT '#1B4D89',
  secondary_color TEXT NOT NULL DEFAULT '#F5A623',
  logo_url TEXT,
  favicon_url TEXT,
  login_background_url TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),
  UNIQUE (organization_id, school_id)
);

CREATE TRIGGER school_branding_updated_at
  BEFORE UPDATE ON school_branding
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

ALTER TABLE school_branding ENABLE ROW LEVEL SECURITY;
ALTER TABLE school_branding FORCE ROW LEVEL SECURITY;

CREATE POLICY school_branding_school_scope ON school_branding
  FOR ALL
  USING (
    organization_id = app_current_tenant_id()
    AND school_id = app_current_school_id()
  );

GRANT SELECT, INSERT, UPDATE ON school_branding TO erp_tenant;

CREATE TABLE whatsapp_provider_configs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id UUID NOT NULL REFERENCES organizations (id),
  school_id UUID NOT NULL REFERENCES schools (id),
  provider TEXT NOT NULL DEFAULT 'stub'
    CHECK (provider IN ('stub', 'msg91', 'gupshup')),
  sender_id TEXT,
  api_key_ref TEXT,
  template_namespace TEXT,
  is_active BOOLEAN NOT NULL DEFAULT true,
  created_by UUID REFERENCES users (id),
  created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),
  UNIQUE (organization_id, school_id)
);

CREATE TRIGGER whatsapp_provider_configs_updated_at
  BEFORE UPDATE ON whatsapp_provider_configs
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

ALTER TABLE whatsapp_provider_configs ENABLE ROW LEVEL SECURITY;
ALTER TABLE whatsapp_provider_configs FORCE ROW LEVEL SECURITY;

CREATE POLICY whatsapp_provider_configs_school_scope ON whatsapp_provider_configs
  FOR ALL
  USING (
    organization_id = app_current_tenant_id()
    AND school_id = app_current_school_id()
  );

GRANT SELECT, INSERT, UPDATE ON whatsapp_provider_configs TO erp_tenant;
