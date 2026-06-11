-- v10.6 — Dynamic Widget Platform Foundation

CREATE TABLE widget_registry (
  id TEXT PRIMARY KEY,
  title TEXT NOT NULL,
  description TEXT,
  category TEXT NOT NULL,
  required_permission TEXT NOT NULL,
  default_width INTEGER NOT NULL DEFAULT 1,
  default_height INTEGER NOT NULL DEFAULT 1,
  metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
  is_active BOOLEAN NOT NULL DEFAULT true,
  created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now())
);

CREATE TABLE dashboard_layouts (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id UUID NOT NULL REFERENCES organizations (id),
  school_id UUID NOT NULL REFERENCES schools (id),
  owner_user_id UUID REFERENCES users (id),
  dashboard_key TEXT NOT NULL DEFAULT 'default',
  layout JSONB NOT NULL DEFAULT '[]'::jsonb,
  visibility_rules JSONB NOT NULL DEFAULT '{}'::jsonb,
  created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),
  UNIQUE (organization_id, school_id, owner_user_id, dashboard_key)
);

CREATE INDEX idx_dashboard_layouts_school
  ON dashboard_layouts (organization_id, school_id, dashboard_key);

CREATE TRIGGER dashboard_layouts_updated_at
  BEFORE UPDATE ON dashboard_layouts
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

ALTER TABLE dashboard_layouts ENABLE ROW LEVEL SECURITY;
ALTER TABLE dashboard_layouts FORCE ROW LEVEL SECURITY;

CREATE POLICY dashboard_layouts_school_scope ON dashboard_layouts
  FOR ALL
  USING (
    organization_id = app_current_tenant_id()
    AND school_id = app_current_school_id()
  );

GRANT SELECT, INSERT, UPDATE ON dashboard_layouts TO erp_tenant;
GRANT SELECT ON widget_registry TO erp_tenant;

INSERT INTO widget_registry (id, title, category, required_permission, description) VALUES
  ('attendance_risk', 'Attendance Risk', 'intelligence', 'viewStudentRisk', 'Students below attendance threshold'),
  ('fee_collection', 'Fee Collection', 'finance', 'viewFinance', 'Fee collection summary'),
  ('timetable_alerts', 'Timetable Alerts', 'operations', 'viewAcademicTimetable', 'Schedule conflicts and gaps'),
  ('homework_summary', 'Homework Summary', 'academics', 'viewHomeworkIntelligence', 'Homework completion overview'),
  ('school_health', 'School Health', 'operations', 'viewOperationsHub', 'Overall school health score'),
  ('employee_workload', 'Employee Workload', 'hr', 'viewEmployeeIntelligence', 'Teacher workload index'),
  ('student_risk', 'Student Risk', 'intelligence', 'viewStudentRisk', 'At-risk student count'),
  ('operations_summary', 'Operations Summary', 'operations', 'viewOperationsHub', 'Daily operations snapshot')
ON CONFLICT (id) DO NOTHING;
