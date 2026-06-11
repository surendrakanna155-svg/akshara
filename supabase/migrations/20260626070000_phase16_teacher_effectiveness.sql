-- Phase 16 — Teacher Effectiveness

CREATE TABLE teacher_lesson_effectiveness (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id UUID NOT NULL REFERENCES organizations (id),
  school_id UUID NOT NULL REFERENCES schools (id),
  teacher_user_id UUID NOT NULL,
  lesson_log_id UUID REFERENCES teacher_lesson_logs (id) ON DELETE SET NULL,
  class_name TEXT NOT NULL,
  subject_id UUID,
  topic TEXT NOT NULL,
  effectiveness_score INT NOT NULL CHECK (effectiveness_score BETWEEN 0 AND 100),
  completion_rate INT NOT NULL DEFAULT 0 CHECK (completion_rate BETWEEN 0 AND 100),
  student_engagement_score INT NOT NULL DEFAULT 0 CHECK (student_engagement_score BETWEEN 0 AND 100),
  syllabus_alignment_score INT NOT NULL DEFAULT 0 CHECK (syllabus_alignment_score BETWEEN 0 AND 100),
  computed_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now())
);

CREATE INDEX idx_teacher_lesson_effectiveness_teacher
  ON teacher_lesson_effectiveness (organization_id, school_id, teacher_user_id, computed_at DESC);

ALTER TABLE teacher_lesson_effectiveness ENABLE ROW LEVEL SECURITY;
ALTER TABLE teacher_lesson_effectiveness FORCE ROW LEVEL SECURITY;

CREATE POLICY teacher_lesson_effectiveness_scope ON teacher_lesson_effectiveness
  FOR ALL USING (
    organization_id = app_current_tenant_id()
    AND school_id = app_current_school_id()
  );

GRANT SELECT, INSERT, UPDATE ON teacher_lesson_effectiveness TO erp_tenant;

CREATE TABLE teacher_topic_mastery (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id UUID NOT NULL REFERENCES organizations (id),
  school_id UUID NOT NULL REFERENCES schools (id),
  teacher_user_id UUID NOT NULL,
  subject_id UUID,
  class_name TEXT NOT NULL,
  topic_name TEXT NOT NULL,
  mastery_percent INT NOT NULL DEFAULT 0 CHECK (mastery_percent BETWEEN 0 AND 100),
  lessons_completed INT NOT NULL DEFAULT 0,
  avg_effectiveness_score INT NOT NULL DEFAULT 0 CHECK (avg_effectiveness_score BETWEEN 0 AND 100),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),
  UNIQUE (organization_id, school_id, teacher_user_id, class_name, topic_name)
);

CREATE INDEX idx_teacher_topic_mastery_teacher
  ON teacher_topic_mastery (organization_id, school_id, teacher_user_id, mastery_percent DESC);

ALTER TABLE teacher_topic_mastery ENABLE ROW LEVEL SECURITY;
ALTER TABLE teacher_topic_mastery FORCE ROW LEVEL SECURITY;

CREATE POLICY teacher_topic_mastery_scope ON teacher_topic_mastery
  FOR ALL USING (
    organization_id = app_current_tenant_id()
    AND school_id = app_current_school_id()
  );

GRANT SELECT, INSERT, UPDATE ON teacher_topic_mastery TO erp_tenant;

CREATE TABLE parent_meeting_summaries (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id UUID NOT NULL REFERENCES organizations (id),
  school_id UUID NOT NULL REFERENCES schools (id),
  teacher_user_id UUID NOT NULL,
  student_id TEXT NOT NULL,
  meeting_date DATE NOT NULL,
  summary_json JSONB NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now())
);

CREATE INDEX idx_parent_meeting_summaries_teacher
  ON parent_meeting_summaries (organization_id, school_id, teacher_user_id, meeting_date DESC);

ALTER TABLE parent_meeting_summaries ENABLE ROW LEVEL SECURITY;
ALTER TABLE parent_meeting_summaries FORCE ROW LEVEL SECURITY;

CREATE POLICY parent_meeting_summaries_scope ON parent_meeting_summaries
  FOR ALL USING (
    organization_id = app_current_tenant_id()
    AND school_id = app_current_school_id()
  );

GRANT SELECT, INSERT, UPDATE ON parent_meeting_summaries TO erp_tenant;
