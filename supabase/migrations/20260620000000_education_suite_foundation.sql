-- v8.5–v8.8 Education Suite — question bank, papers, homework, report remarks

-- ─── edu_question_bank_items ─────────────────────────────────────────────────

CREATE TABLE edu_question_bank_items (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id UUID NOT NULL REFERENCES organizations (id),
  school_id UUID NOT NULL REFERENCES schools (id),
  subject_name TEXT NOT NULL,
  chapter TEXT NOT NULL DEFAULT '',
  topic TEXT NOT NULL DEFAULT '',
  difficulty TEXT NOT NULL DEFAULT 'medium'
    CHECK (difficulty IN ('easy', 'medium', 'hard')),
  question_type TEXT NOT NULL
    CHECK (question_type IN (
      'mcq', 'fill_blank', 'match', 'short_answer', 'long_answer', 'diagram'
    )),
  marks INT NOT NULL CHECK (marks > 0),
  question_text TEXT NOT NULL,
  answer_text TEXT,
  options JSONB NOT NULL DEFAULT '[]'::jsonb,
  status TEXT NOT NULL DEFAULT 'active'
    CHECK (status IN ('active', 'archived')),
  created_by UUID REFERENCES users (id),
  created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now())
);

CREATE INDEX idx_edu_question_bank_school_subject
  ON edu_question_bank_items (organization_id, school_id, subject_name, chapter);

CREATE TRIGGER edu_question_bank_items_updated_at
  BEFORE UPDATE ON edu_question_bank_items
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

ALTER TABLE edu_question_bank_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE edu_question_bank_items FORCE ROW LEVEL SECURITY;

CREATE POLICY edu_question_bank_school_scope ON edu_question_bank_items
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

GRANT SELECT, INSERT, UPDATE, DELETE ON edu_question_bank_items TO erp_tenant;

-- ─── edu_question_papers ─────────────────────────────────────────────────────

CREATE TABLE edu_question_papers (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id UUID NOT NULL REFERENCES organizations (id),
  school_id UUID NOT NULL REFERENCES schools (id),
  academic_year_id UUID REFERENCES academic_years (id) ON DELETE SET NULL,
  academic_year_label TEXT NOT NULL,
  class_name TEXT NOT NULL,
  section_name TEXT,
  subject_name TEXT NOT NULL,
  chapters JSONB NOT NULL DEFAULT '[]'::jsonb,
  difficulty TEXT NOT NULL DEFAULT 'mixed'
    CHECK (difficulty IN ('easy', 'medium', 'hard', 'mixed')),
  total_marks INT NOT NULL CHECK (total_marks > 0),
  exam_type TEXT NOT NULL
    CHECK (exam_type IN (
      'unit_test', 'weekly_test', 'monthly_test',
      'quarterly', 'half_yearly', 'annual'
    )),
  title TEXT NOT NULL,
  status TEXT NOT NULL DEFAULT 'draft'
    CHECK (status IN ('draft', 'published', 'archived')),
  blueprint JSONB NOT NULL DEFAULT '{}'::jsonb,
  answer_key JSONB NOT NULL DEFAULT '[]'::jsonb,
  created_by UUID REFERENCES users (id),
  published_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now())
);

CREATE INDEX idx_edu_question_papers_school
  ON edu_question_papers (organization_id, school_id, created_at DESC);

CREATE TRIGGER edu_question_papers_updated_at
  BEFORE UPDATE ON edu_question_papers
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

ALTER TABLE edu_question_papers ENABLE ROW LEVEL SECURITY;
ALTER TABLE edu_question_papers FORCE ROW LEVEL SECURITY;

CREATE POLICY edu_question_papers_school_scope ON edu_question_papers
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

GRANT SELECT, INSERT, UPDATE ON edu_question_papers TO erp_tenant;

-- ─── edu_question_paper_items ────────────────────────────────────────────────

CREATE TABLE edu_question_paper_items (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  paper_id UUID NOT NULL REFERENCES edu_question_papers (id) ON DELETE CASCADE,
  organization_id UUID NOT NULL REFERENCES organizations (id),
  school_id UUID NOT NULL REFERENCES schools (id),
  sort_order INT NOT NULL DEFAULT 0,
  bank_item_id UUID REFERENCES edu_question_bank_items (id) ON DELETE SET NULL,
  question_type TEXT NOT NULL,
  marks INT NOT NULL CHECK (marks > 0),
  question_text TEXT NOT NULL,
  answer_text TEXT,
  options JSONB NOT NULL DEFAULT '[]'::jsonb,
  source TEXT NOT NULL DEFAULT 'bank'
    CHECK (source IN ('bank', 'ai_generated')),
  created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now())
);

CREATE INDEX idx_edu_question_paper_items_paper
  ON edu_question_paper_items (paper_id, sort_order);

ALTER TABLE edu_question_paper_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE edu_question_paper_items FORCE ROW LEVEL SECURITY;

CREATE POLICY edu_question_paper_items_school_scope ON edu_question_paper_items
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

GRANT SELECT, INSERT, UPDATE, DELETE ON edu_question_paper_items TO erp_tenant;

-- ─── edu_homework_assignments (v8.7) ─────────────────────────────────────────

CREATE TABLE edu_homework_assignments (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id UUID NOT NULL REFERENCES organizations (id),
  school_id UUID NOT NULL REFERENCES schools (id),
  academic_year_label TEXT NOT NULL,
  class_name TEXT NOT NULL,
  section_name TEXT,
  subject_name TEXT NOT NULL,
  topic TEXT NOT NULL DEFAULT '',
  difficulty TEXT NOT NULL DEFAULT 'medium'
    CHECK (difficulty IN ('easy', 'medium', 'hard', 'mixed')),
  assignment_type TEXT NOT NULL
    CHECK (assignment_type IN (
      'homework', 'practice_worksheet', 'revision_worksheet', 'holiday_homework'
    )),
  title TEXT NOT NULL,
  content JSONB NOT NULL DEFAULT '[]'::jsonb,
  due_date DATE,
  status TEXT NOT NULL DEFAULT 'draft'
    CHECK (status IN ('draft', 'published', 'archived')),
  created_by UUID REFERENCES users (id),
  published_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now())
);

CREATE INDEX idx_edu_homework_school_class
  ON edu_homework_assignments (organization_id, school_id, class_name, status);

CREATE TRIGGER edu_homework_assignments_updated_at
  BEFORE UPDATE ON edu_homework_assignments
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

ALTER TABLE edu_homework_assignments ENABLE ROW LEVEL SECURITY;
ALTER TABLE edu_homework_assignments FORCE ROW LEVEL SECURITY;

CREATE POLICY edu_homework_assignments_school_scope ON edu_homework_assignments
  FOR ALL
  USING (
    organization_id = app_current_tenant_id()
    AND school_id = app_current_school_id()
    AND (
      app_current_scope() = 'school'
      OR app_current_scope() = 'parent'
      OR app_current_scope() = 'student'
    )
  )
  WITH CHECK (
    organization_id = app_current_tenant_id()
    AND app_current_scope() = 'school'
    AND school_id = app_current_school_id()
  );

GRANT SELECT, INSERT, UPDATE ON edu_homework_assignments TO erp_tenant;

-- ─── edu_report_card_remarks (v8.8) ──────────────────────────────────────────

CREATE TABLE edu_report_card_remarks (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id UUID NOT NULL REFERENCES organizations (id),
  school_id UUID NOT NULL REFERENCES schools (id),
  student_id UUID NOT NULL REFERENCES students (id) ON DELETE CASCADE,
  academic_year_label TEXT NOT NULL,
  remark_type TEXT NOT NULL
    CHECK (remark_type IN ('principal', 'class_teacher', 'subject_teacher')),
  language TEXT NOT NULL DEFAULT 'english'
    CHECK (language IN ('english', 'telugu', 'hindi')),
  inputs JSONB NOT NULL DEFAULT '{}'::jsonb,
  generated_remark TEXT NOT NULL DEFAULT '',
  edited_remark TEXT,
  status TEXT NOT NULL DEFAULT 'draft'
    CHECK (status IN ('draft', 'published')),
  created_by UUID REFERENCES users (id),
  published_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now())
);

CREATE INDEX idx_edu_report_remarks_student
  ON edu_report_card_remarks (organization_id, school_id, student_id);

CREATE TRIGGER edu_report_card_remarks_updated_at
  BEFORE UPDATE ON edu_report_card_remarks
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

ALTER TABLE edu_report_card_remarks ENABLE ROW LEVEL SECURITY;
ALTER TABLE edu_report_card_remarks FORCE ROW LEVEL SECURITY;

CREATE POLICY edu_report_card_remarks_school_scope ON edu_report_card_remarks
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

GRANT SELECT, INSERT, UPDATE ON edu_report_card_remarks TO erp_tenant;
