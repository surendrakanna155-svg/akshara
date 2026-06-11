-- Phase 10 — Final School Platform (v12.7–v13.2)

CREATE TABLE subject_templates (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  board TEXT NOT NULL DEFAULT 'CBSE',
  subject_code TEXT NOT NULL,
  subject_name TEXT NOT NULL,
  category TEXT NOT NULL DEFAULT 'core',
  grade_label TEXT NOT NULL,
  chapters JSONB NOT NULL DEFAULT '[]'::jsonb,
  created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),
  UNIQUE (board, subject_code, grade_label)
);

CREATE TABLE syllabus_chapters (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id UUID NOT NULL REFERENCES organizations (id),
  school_id UUID NOT NULL REFERENCES schools (id),
  academic_year_id UUID NOT NULL REFERENCES academic_years (id),
  subject_id UUID NOT NULL REFERENCES academic_subjects (id),
  class_name TEXT NOT NULL,
  chapter_name TEXT NOT NULL,
  sequence_order INT NOT NULL DEFAULT 0,
  status TEXT NOT NULL DEFAULT 'pending'
    CHECK (status IN ('pending', 'in_progress', 'completed')),
  created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),
  UNIQUE (organization_id, school_id, subject_id, class_name, chapter_name)
);

CREATE INDEX idx_syllabus_chapters_subject
  ON syllabus_chapters (organization_id, school_id, subject_id, class_name);

CREATE TRIGGER syllabus_chapters_updated_at
  BEFORE UPDATE ON syllabus_chapters
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

ALTER TABLE syllabus_chapters ENABLE ROW LEVEL SECURITY;
ALTER TABLE syllabus_chapters FORCE ROW LEVEL SECURITY;

CREATE POLICY syllabus_chapters_scope ON syllabus_chapters
  FOR ALL USING (
    organization_id = app_current_tenant_id()
    AND school_id = app_current_school_id()
  );

GRANT SELECT, INSERT, UPDATE, DELETE ON syllabus_chapters TO erp_tenant;

ALTER TABLE syllabus_topics
  ADD COLUMN IF NOT EXISTS chapter_id UUID REFERENCES syllabus_chapters (id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS academic_year_id UUID REFERENCES academic_years (id);

CREATE TABLE syllabus_generations (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id UUID NOT NULL REFERENCES organizations (id),
  school_id UUID NOT NULL REFERENCES schools (id),
  academic_year_id UUID NOT NULL REFERENCES academic_years (id),
  source TEXT NOT NULL DEFAULT 'wizard'
    CHECK (source IN ('wizard', 'template', 'clone', 'manual')),
  chapters_created INT NOT NULL DEFAULT 0,
  topics_created INT NOT NULL DEFAULT 0,
  created_by UUID REFERENCES users (id),
  created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now())
);

ALTER TABLE syllabus_generations ENABLE ROW LEVEL SECURITY;
ALTER TABLE syllabus_generations FORCE ROW LEVEL SECURITY;

CREATE POLICY syllabus_generations_scope ON syllabus_generations
  FOR ALL USING (
    organization_id = app_current_tenant_id()
    AND school_id = app_current_school_id()
  );

GRANT SELECT, INSERT ON syllabus_generations TO erp_tenant;

CREATE TABLE syllabus_topic_completions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id UUID NOT NULL REFERENCES organizations (id),
  school_id UUID NOT NULL REFERENCES schools (id),
  topic_id UUID NOT NULL REFERENCES syllabus_topics (id) ON DELETE CASCADE,
  teacher_user_id UUID NOT NULL REFERENCES users (id),
  lesson_log_id UUID REFERENCES teacher_lesson_logs (id) ON DELETE SET NULL,
  completed_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),
  UNIQUE (organization_id, school_id, topic_id, teacher_user_id)
);

ALTER TABLE syllabus_topic_completions ENABLE ROW LEVEL SECURITY;
ALTER TABLE syllabus_topic_completions FORCE ROW LEVEL SECURITY;

CREATE POLICY syllabus_topic_completions_scope ON syllabus_topic_completions
  FOR ALL USING (
    organization_id = app_current_tenant_id()
    AND school_id = app_current_school_id()
  );

GRANT SELECT, INSERT, UPDATE ON syllabus_topic_completions TO erp_tenant;

CREATE TABLE platform_secret_vault (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id UUID REFERENCES organizations (id),
  provider_category TEXT NOT NULL
    CHECK (provider_category IN ('ai', 'whatsapp', 'sms')),
  provider_name TEXT NOT NULL,
  encrypted_payload TEXT NOT NULL,
  key_version INT NOT NULL DEFAULT 1,
  health_status TEXT NOT NULL DEFAULT 'unknown'
    CHECK (health_status IN ('healthy', 'degraded', 'failed', 'unknown')),
  last_health_check_at TIMESTAMPTZ,
  last_rotated_at TIMESTAMPTZ,
  failover_secret_id UUID REFERENCES platform_secret_vault (id),
  created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now())
);

CREATE TRIGGER platform_secret_vault_updated_at
  BEFORE UPDATE ON platform_secret_vault
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE TABLE platform_secret_audit_log (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  secret_id UUID NOT NULL REFERENCES platform_secret_vault (id) ON DELETE CASCADE,
  action TEXT NOT NULL
    CHECK (action IN ('created', 'rotated', 'accessed', 'health_check', 'failover')),
  actor_user_id UUID REFERENCES users (id),
  metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
  created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now())
);

CREATE TABLE platform_provider_configs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id UUID REFERENCES organizations (id),
  provider_category TEXT NOT NULL
    CHECK (provider_category IN ('ai', 'whatsapp', 'sms')),
  provider_name TEXT NOT NULL,
  vault_secret_id UUID REFERENCES platform_secret_vault (id),
  is_active BOOLEAN NOT NULL DEFAULT true,
  is_primary BOOLEAN NOT NULL DEFAULT false,
  config JSONB NOT NULL DEFAULT '{}'::jsonb,
  health_status TEXT NOT NULL DEFAULT 'unknown',
  created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now())
);

CREATE TRIGGER platform_provider_configs_updated_at
  BEFORE UPDATE ON platform_provider_configs
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE TABLE platform_usage_events (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id UUID REFERENCES organizations (id),
  school_id UUID REFERENCES schools (id),
  provider_category TEXT NOT NULL,
  provider_name TEXT NOT NULL,
  event_type TEXT NOT NULL,
  units INT NOT NULL DEFAULT 1,
  cost_inr NUMERIC(12, 2) NOT NULL DEFAULT 0,
  created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now())
);

CREATE INDEX idx_platform_usage_events_category
  ON platform_usage_events (provider_category, created_at DESC);

CREATE TABLE platform_feature_enablements (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id UUID NOT NULL REFERENCES organizations (id),
  school_id UUID NOT NULL REFERENCES schools (id),
  feature_key TEXT NOT NULL,
  enabled BOOLEAN NOT NULL DEFAULT true,
  updated_by UUID REFERENCES users (id),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),
  UNIQUE (organization_id, school_id, feature_key)
);

CREATE TABLE academic_rooms (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id UUID NOT NULL REFERENCES organizations (id),
  school_id UUID NOT NULL REFERENCES schools (id),
  room_label TEXT NOT NULL,
  room_type TEXT NOT NULL DEFAULT 'classroom'
    CHECK (room_type IN ('classroom', 'lab', 'auditorium', 'sports')),
  capacity INT NOT NULL DEFAULT 40,
  status TEXT NOT NULL DEFAULT 'active'
    CHECK (status IN ('active', 'inactive', 'maintenance')),
  created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),
  UNIQUE (organization_id, school_id, room_label)
);

ALTER TABLE academic_rooms ENABLE ROW LEVEL SECURITY;
ALTER TABLE academic_rooms FORCE ROW LEVEL SECURITY;

CREATE POLICY academic_rooms_scope ON academic_rooms
  FOR ALL USING (
    organization_id = app_current_tenant_id()
    AND school_id = app_current_school_id()
  );

GRANT SELECT, INSERT, UPDATE ON academic_rooms TO erp_tenant;

CREATE TABLE exam_timetable_entries (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id UUID NOT NULL REFERENCES organizations (id),
  school_id UUID NOT NULL REFERENCES schools (id),
  academic_year_id UUID NOT NULL REFERENCES academic_years (id),
  class_name TEXT NOT NULL,
  subject_label TEXT NOT NULL,
  exam_date DATE NOT NULL,
  start_period INT NOT NULL DEFAULT 1,
  end_period INT NOT NULL DEFAULT 1,
  room_id UUID REFERENCES academic_rooms (id),
  status TEXT NOT NULL DEFAULT 'draft'
    CHECK (status IN ('draft', 'published')),
  created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now())
);

ALTER TABLE exam_timetable_entries ENABLE ROW LEVEL SECURITY;
ALTER TABLE exam_timetable_entries FORCE ROW LEVEL SECURITY;

CREATE POLICY exam_timetable_entries_scope ON exam_timetable_entries
  FOR ALL USING (
    organization_id = app_current_tenant_id()
    AND school_id = app_current_school_id()
  );

GRANT SELECT, INSERT, UPDATE ON exam_timetable_entries TO erp_tenant;

CREATE TABLE parent_academic_summaries (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id UUID NOT NULL REFERENCES organizations (id),
  school_id UUID NOT NULL REFERENCES schools (id),
  student_id UUID NOT NULL,
  attendance_summary JSONB NOT NULL DEFAULT '{}'::jsonb,
  performance_summary JSONB NOT NULL DEFAULT '{}'::jsonb,
  strengths JSONB NOT NULL DEFAULT '[]'::jsonb,
  weaknesses JSONB NOT NULL DEFAULT '[]'::jsonb,
  homework_status JSONB NOT NULL DEFAULT '{}'::jsonb,
  exam_readiness JSONB NOT NULL DEFAULT '{}'::jsonb,
  teacher_recommendations JSONB NOT NULL DEFAULT '[]'::jsonb,
  generated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),
  UNIQUE (organization_id, school_id, student_id)
);

ALTER TABLE parent_academic_summaries ENABLE ROW LEVEL SECURITY;
ALTER TABLE parent_academic_summaries FORCE ROW LEVEL SECURITY;

CREATE POLICY parent_academic_summaries_scope ON parent_academic_summaries
  FOR ALL USING (
    organization_id = app_current_tenant_id()
    AND school_id = app_current_school_id()
  );

GRANT SELECT, INSERT, UPDATE ON parent_academic_summaries TO erp_tenant;

INSERT INTO subject_templates (board, subject_code, subject_name, category, grade_label, chapters) VALUES
  ('CBSE', 'ENG', 'English', 'core', 'Grade 1', '[{"name":"Alphabet","topics":["A-Z","Phonics"]},{"name":"Reading","topics":["Simple words","Sentences"]}]'),
  ('CBSE', 'MATH', 'Mathematics', 'core', 'Grade 1', '[{"name":"Numbers","topics":["1-20","Counting"]},{"name":"Addition","topics":["Single digit"]}]'),
  ('CBSE', 'SCI', 'Science', 'core', 'Grade 1', '[{"name":"Living Things","topics":["Plants","Animals"]}]'),
  ('CBSE', 'ENG', 'English', 'core', 'Grade 7', '[{"name":"Prose","topics":["Short stories","Comprehension"]},{"name":"Grammar","topics":["Tenses","Clauses"]}]'),
  ('CBSE', 'MATH', 'Mathematics', 'core', 'Grade 7', '[{"name":"Algebra","topics":["Expressions","Equations"]},{"name":"Geometry","topics":["Triangles","Circles"]}]'),
  ('CBSE', 'SCI', 'Science', 'core', 'Grade 7', '[{"name":"Physics","topics":["Motion","Heat"]},{"name":"Biology","topics":["Nutrition","Respiration"]}]')
ON CONFLICT DO NOTHING;
