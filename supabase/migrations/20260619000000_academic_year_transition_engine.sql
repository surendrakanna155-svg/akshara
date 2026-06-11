-- v8.0 — Academic Year Transition Engine

CREATE TABLE academic_year_transitions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id UUID NOT NULL REFERENCES organizations (id),
  school_id UUID NOT NULL REFERENCES schools (id),
  source_year_id UUID NOT NULL REFERENCES academic_years (id) ON DELETE RESTRICT,
  target_year_id UUID NOT NULL REFERENCES academic_years (id) ON DELETE RESTRICT,
  status TEXT NOT NULL DEFAULT 'previewed'
    CHECK (status IN ('previewed', 'executing', 'completed', 'failed')),
  class_mapping JSONB NOT NULL DEFAULT '[]'::jsonb,
  preview_report JSONB NOT NULL DEFAULT '{}'::jsonb,
  execution_report JSONB NOT NULL DEFAULT '{}'::jsonb,
  promoted_count INT NOT NULL DEFAULT 0,
  skipped_count INT NOT NULL DEFAULT 0,
  failed_count INT NOT NULL DEFAULT 0,
  set_target_current BOOLEAN NOT NULL DEFAULT true,
  archive_source_year BOOLEAN NOT NULL DEFAULT true,
  created_by UUID REFERENCES users (id),
  created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),
  executed_at TIMESTAMPTZ,
  CHECK (source_year_id <> target_year_id)
);

CREATE INDEX idx_academic_year_transitions_school
  ON academic_year_transitions (organization_id, school_id, created_at DESC);

CREATE TRIGGER academic_year_transitions_updated_at
  BEFORE UPDATE ON academic_year_transitions
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

ALTER TABLE academic_year_transitions ENABLE ROW LEVEL SECURITY;
ALTER TABLE academic_year_transitions FORCE ROW LEVEL SECURITY;

CREATE POLICY academic_year_transitions_school_scope ON academic_year_transitions
  FOR ALL
  USING (
    organization_id = app_current_tenant_id()
    AND app_current_scope() = 'school'
    AND school_id = app_current_school_id()
  )
  WITH CHECK (
    organization_id = app_current_tenant_id()
    AND app_current_scope() = 'school'
    AND school_id = app_current_school_id()
  );

GRANT SELECT, INSERT, UPDATE ON academic_year_transitions TO erp_tenant;
