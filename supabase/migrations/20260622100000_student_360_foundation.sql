-- v9.5 Student 360 Profile

CREATE TABLE student_timeline_events (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id UUID NOT NULL REFERENCES organizations (id),
  school_id UUID NOT NULL REFERENCES schools (id),
  student_id UUID NOT NULL,
  event_type TEXT NOT NULL,
  event_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),
  title TEXT NOT NULL,
  summary TEXT,
  payload JSONB NOT NULL DEFAULT '{}'::jsonb,
  source_module TEXT NOT NULL,
  source_id TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now())
);

CREATE INDEX idx_student_timeline_student
  ON student_timeline_events (organization_id, school_id, student_id, event_at DESC);

CREATE INDEX idx_student_timeline_type
  ON student_timeline_events (organization_id, school_id, event_type);

ALTER TABLE student_timeline_events ENABLE ROW LEVEL SECURITY;
ALTER TABLE student_timeline_events FORCE ROW LEVEL SECURITY;

CREATE POLICY student_timeline_school_scope ON student_timeline_events
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

CREATE POLICY student_timeline_parent_scope ON student_timeline_events
  FOR SELECT
  USING (
    organization_id = app_current_tenant_id()
    AND app_current_scope() = 'parent'
    AND student_id IN (
      SELECT sg.student_id
      FROM student_guardians sg
      WHERE sg.guardian_user_id = app_current_user_id()
        AND sg.organization_id = app_current_tenant_id()
        AND sg.status = 'active'
    )
  );

GRANT SELECT, INSERT, UPDATE, DELETE ON student_timeline_events TO erp_tenant;
