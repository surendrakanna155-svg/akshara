-- v10.7 — Teacher Assistant Completion

CREATE TABLE teacher_interventions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id UUID NOT NULL REFERENCES organizations (id),
  school_id UUID NOT NULL REFERENCES schools (id),
  teacher_user_id UUID REFERENCES users (id),
  student_id UUID NOT NULL REFERENCES students (id) ON DELETE CASCADE,
  intervention_type TEXT NOT NULL
    CHECK (intervention_type IN ('academic', 'attendance', 'homework', 'behavior', 'parent_meeting')),
  status TEXT NOT NULL DEFAULT 'open'
    CHECK (status IN ('open', 'in_progress', 'completed', 'cancelled')),
  priority TEXT NOT NULL DEFAULT 'medium'
    CHECK (priority IN ('low', 'medium', 'high')),
  title TEXT NOT NULL,
  notes TEXT,
  follow_up_at TIMESTAMPTZ,
  completed_at TIMESTAMPTZ,
  created_by UUID REFERENCES users (id),
  created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now())
);

CREATE INDEX idx_teacher_interventions_teacher
  ON teacher_interventions (organization_id, school_id, teacher_user_id, status);

ALTER TABLE teacher_interventions ENABLE ROW LEVEL SECURITY;
ALTER TABLE teacher_interventions FORCE ROW LEVEL SECURITY;

CREATE POLICY teacher_interventions_school_scope ON teacher_interventions
  FOR ALL
  USING (
    organization_id = app_current_tenant_id()
    AND school_id = app_current_school_id()
  );

GRANT SELECT, INSERT, UPDATE ON teacher_interventions TO erp_tenant;
