-- Phase 13 — Student Success Intelligence

CREATE TABLE intel_student_success_snapshots (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id UUID NOT NULL REFERENCES organizations (id),
  school_id UUID NOT NULL REFERENCES schools (id),
  student_id UUID NOT NULL,
  student_name TEXT NOT NULL DEFAULT '',
  class_name TEXT NOT NULL DEFAULT '',
  section_name TEXT,
  dropout_probability INTEGER NOT NULL DEFAULT 0
    CHECK (dropout_probability BETWEEN 0 AND 100),
  attendance_prediction INTEGER NOT NULL DEFAULT 0
    CHECK (attendance_prediction BETWEEN 0 AND 100),
  performance_decline_score INTEGER NOT NULL DEFAULT 0
    CHECK (performance_decline_score BETWEEN 0 AND 100),
  improvement_score INTEGER NOT NULL DEFAULT 0
    CHECK (improvement_score BETWEEN 0 AND 100),
  risk_signals JSONB NOT NULL DEFAULT '[]'::jsonb,
  predictions JSONB NOT NULL DEFAULT '{}'::jsonb,
  computed_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now())
);

CREATE INDEX idx_intel_student_success_school_class
  ON intel_student_success_snapshots (organization_id, school_id, class_name, dropout_probability DESC);

CREATE INDEX idx_intel_student_success_student
  ON intel_student_success_snapshots (organization_id, school_id, student_id, computed_at DESC);

ALTER TABLE intel_student_success_snapshots ENABLE ROW LEVEL SECURITY;
ALTER TABLE intel_student_success_snapshots FORCE ROW LEVEL SECURITY;

CREATE POLICY intel_student_success_school_scope ON intel_student_success_snapshots
  FOR ALL USING (
    organization_id = app_current_tenant_id()
    AND school_id = app_current_school_id()
  );

GRANT SELECT, INSERT, UPDATE, DELETE ON intel_student_success_snapshots TO erp_tenant;

CREATE TABLE intel_student_success_interventions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id UUID NOT NULL REFERENCES organizations (id),
  school_id UUID NOT NULL REFERENCES schools (id),
  student_id UUID NOT NULL,
  intervention_type TEXT NOT NULL,
  intervention_label TEXT NOT NULL,
  started_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),
  completed_at TIMESTAMPTZ,
  effectiveness_score INTEGER
    CHECK (effectiveness_score IS NULL OR effectiveness_score BETWEEN 0 AND 100),
  outcome TEXT,
  status TEXT NOT NULL DEFAULT 'active'
    CHECK (status IN ('active', 'completed', 'ineffective')),
  metadata JSONB NOT NULL DEFAULT '{}'::jsonb
);

CREATE INDEX idx_intel_student_success_interventions_student
  ON intel_student_success_interventions (organization_id, school_id, student_id, status);

ALTER TABLE intel_student_success_interventions ENABLE ROW LEVEL SECURITY;
ALTER TABLE intel_student_success_interventions FORCE ROW LEVEL SECURITY;

CREATE POLICY intel_student_success_interventions_scope ON intel_student_success_interventions
  FOR ALL USING (
    organization_id = app_current_tenant_id()
    AND school_id = app_current_school_id()
  );

GRANT SELECT, INSERT, UPDATE ON intel_student_success_interventions TO erp_tenant;
