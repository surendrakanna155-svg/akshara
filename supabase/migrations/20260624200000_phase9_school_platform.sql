-- Phase 9 — School Platform Completion (v12.1–v12.6)

CREATE TABLE class_subject_assignments (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id UUID NOT NULL REFERENCES organizations (id),
  school_id UUID NOT NULL REFERENCES schools (id),
  academic_year_id UUID NOT NULL REFERENCES academic_years (id),
  class_id UUID NOT NULL REFERENCES classes (id),
  section_id UUID REFERENCES sections (id),
  subject_id UUID NOT NULL REFERENCES academic_subjects (id),
  is_elective BOOLEAN NOT NULL DEFAULT false,
  periods_per_week INT NOT NULL DEFAULT 5,
  status TEXT NOT NULL DEFAULT 'active'
    CHECK (status IN ('active', 'inactive')),
  created_by UUID REFERENCES users (id),
  created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),
  UNIQUE (organization_id, school_id, class_id, section_id, subject_id)
);

CREATE INDEX idx_class_subject_assignments_class
  ON class_subject_assignments (organization_id, school_id, class_id);

CREATE TRIGGER class_subject_assignments_updated_at
  BEFORE UPDATE ON class_subject_assignments
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

ALTER TABLE class_subject_assignments ENABLE ROW LEVEL SECURITY;
ALTER TABLE class_subject_assignments FORCE ROW LEVEL SECURITY;

CREATE POLICY class_subject_assignments_scope ON class_subject_assignments
  FOR ALL USING (
    organization_id = app_current_tenant_id()
    AND school_id = app_current_school_id()
  );

GRANT SELECT, INSERT, UPDATE, DELETE ON class_subject_assignments TO erp_tenant;

CREATE TABLE teacher_subject_assignments (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id UUID NOT NULL REFERENCES organizations (id),
  school_id UUID NOT NULL REFERENCES schools (id),
  academic_year_id UUID NOT NULL REFERENCES academic_years (id),
  teacher_user_id UUID NOT NULL REFERENCES users (id),
  subject_id UUID NOT NULL REFERENCES academic_subjects (id),
  class_id UUID REFERENCES classes (id),
  section_id UUID REFERENCES sections (id),
  periods_per_week INT NOT NULL DEFAULT 0,
  is_primary BOOLEAN NOT NULL DEFAULT false,
  status TEXT NOT NULL DEFAULT 'active'
    CHECK (status IN ('active', 'inactive')),
  created_by UUID REFERENCES users (id),
  created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),
  UNIQUE (organization_id, school_id, teacher_user_id, subject_id, class_id, section_id)
);

CREATE INDEX idx_teacher_subject_assignments_teacher
  ON teacher_subject_assignments (organization_id, school_id, teacher_user_id);

CREATE TRIGGER teacher_subject_assignments_updated_at
  BEFORE UPDATE ON teacher_subject_assignments
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

ALTER TABLE teacher_subject_assignments ENABLE ROW LEVEL SECURITY;
ALTER TABLE teacher_subject_assignments FORCE ROW LEVEL SECURITY;

CREATE POLICY teacher_subject_assignments_scope ON teacher_subject_assignments
  FOR ALL USING (
    organization_id = app_current_tenant_id()
    AND school_id = app_current_school_id()
  );

GRANT SELECT, INSERT, UPDATE, DELETE ON teacher_subject_assignments TO erp_tenant;

CREATE TABLE syllabus_topics (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id UUID NOT NULL REFERENCES organizations (id),
  school_id UUID NOT NULL REFERENCES schools (id),
  subject_id UUID NOT NULL REFERENCES academic_subjects (id),
  class_name TEXT NOT NULL,
  topic_name TEXT NOT NULL,
  sequence_order INT NOT NULL DEFAULT 0,
  status TEXT NOT NULL DEFAULT 'pending'
    CHECK (status IN ('pending', 'in_progress', 'completed')),
  created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),
  UNIQUE (organization_id, school_id, subject_id, class_name, topic_name)
);

CREATE INDEX idx_syllabus_topics_subject_class
  ON syllabus_topics (organization_id, school_id, subject_id, class_name);

CREATE TRIGGER syllabus_topics_updated_at
  BEFORE UPDATE ON syllabus_topics
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

ALTER TABLE syllabus_topics ENABLE ROW LEVEL SECURITY;
ALTER TABLE syllabus_topics FORCE ROW LEVEL SECURITY;

CREATE POLICY syllabus_topics_scope ON syllabus_topics
  FOR ALL USING (
    organization_id = app_current_tenant_id()
    AND school_id = app_current_school_id()
  );

GRANT SELECT, INSERT, UPDATE ON syllabus_topics TO erp_tenant;

ALTER TABLE teacher_lesson_logs
  ADD COLUMN IF NOT EXISTS syllabus_topic_id UUID REFERENCES syllabus_topics (id) ON DELETE SET NULL;

CREATE TABLE communication_delivery_events (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id UUID NOT NULL REFERENCES organizations (id),
  school_id UUID NOT NULL REFERENCES schools (id),
  channel TEXT NOT NULL,
  template_code TEXT,
  recipient_label TEXT NOT NULL,
  status TEXT NOT NULL DEFAULT 'pending'
    CHECK (status IN ('pending', 'sent', 'failed', 'delivered')),
  provider_ref TEXT,
  error_message TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now())
);

CREATE INDEX idx_comm_delivery_events_school
  ON communication_delivery_events (organization_id, school_id, created_at DESC);

ALTER TABLE communication_delivery_events ENABLE ROW LEVEL SECURITY;
ALTER TABLE communication_delivery_events FORCE ROW LEVEL SECURITY;

CREATE POLICY comm_delivery_events_scope ON communication_delivery_events
  FOR ALL USING (
    organization_id = app_current_tenant_id()
    AND school_id = app_current_school_id()
  );

GRANT SELECT, INSERT, UPDATE ON communication_delivery_events TO erp_tenant;
