-- v9.4 Homework Intelligence Bridge

CREATE TABLE homework_intelligence_runs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id UUID NOT NULL REFERENCES organizations (id),
  school_id UUID NOT NULL REFERENCES schools (id),
  academic_year_label TEXT NOT NULL DEFAULT '2025-26',
  class_name TEXT NOT NULL,
  section_name TEXT,
  subject_name TEXT NOT NULL,
  exam_type TEXT NOT NULL DEFAULT 'unit_test',
  plan JSONB NOT NULL DEFAULT '{}'::jsonb,
  created_by UUID REFERENCES users (id),
  created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now())
);

CREATE INDEX idx_hw_intel_runs_school_class
  ON homework_intelligence_runs (organization_id, school_id, class_name, created_at DESC);

CREATE TABLE edu_homework_student_targets (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id UUID NOT NULL REFERENCES organizations (id),
  school_id UUID NOT NULL REFERENCES schools (id),
  homework_assignment_id UUID NOT NULL REFERENCES edu_homework_assignments (id) ON DELETE CASCADE,
  student_id UUID NOT NULL,
  intelligence_run_id UUID REFERENCES homework_intelligence_runs (id) ON DELETE SET NULL,
  assignment_reason TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),
  UNIQUE (homework_assignment_id, student_id)
);

CREATE INDEX idx_edu_hw_student_targets_student
  ON edu_homework_student_targets (organization_id, school_id, student_id);

ALTER TABLE homework_intelligence_runs ENABLE ROW LEVEL SECURITY;
ALTER TABLE homework_intelligence_runs FORCE ROW LEVEL SECURITY;
ALTER TABLE edu_homework_student_targets ENABLE ROW LEVEL SECURITY;
ALTER TABLE edu_homework_student_targets FORCE ROW LEVEL SECURITY;

CREATE POLICY hw_intel_runs_school_scope ON homework_intelligence_runs
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

CREATE POLICY edu_hw_student_targets_school_scope ON edu_homework_student_targets
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

GRANT SELECT, INSERT, UPDATE, DELETE ON homework_intelligence_runs TO erp_tenant;
GRANT SELECT, INSERT, UPDATE, DELETE ON edu_homework_student_targets TO erp_tenant;
