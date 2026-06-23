-- Batch 8b — Question Intelligence foundation
-- Bank-first provenance + syllabus linkage + dedup, paper review/approval
-- governance, and AI-candidate moderation. All ALTERs are additive with safe
-- defaults so existing rows remain valid (existing bank items become
-- source='teacher', review_status='approved'; existing papers stay 'draft').

-- ─── edu_question_bank_items: provenance, syllabus linkage, dedup ─────────────

ALTER TABLE edu_question_bank_items
  ADD COLUMN source TEXT NOT NULL DEFAULT 'teacher'
    CHECK (source IN (
      'teacher', 'school', 'import', 'pyq', 'publisher', 'ai_candidate'
    )),
  ADD COLUMN source_reference TEXT,
  ADD COLUMN program_track TEXT NOT NULL DEFAULT 'board'
    CHECK (program_track IN (
      'board', 'jee_foundation', 'neet_foundation', 'ntse', 'olympiad'
    )),
  ADD COLUMN jee_question_type TEXT
    CHECK (jee_question_type IS NULL OR jee_question_type IN (
      'single_correct', 'multiple_correct', 'numerical', 'integer',
      'matrix_match', 'assertion_reason', 'comprehension'
    )),
  ADD COLUMN cognitive_level TEXT
    CHECK (cognitive_level IS NULL OR cognitive_level IN (
      'remember', 'understand', 'apply', 'analyze', 'hots'
    )),
  ADD COLUMN syllabus_chapter_id UUID
    REFERENCES syllabus_chapters (id) ON DELETE SET NULL,
  ADD COLUMN syllabus_topic_id UUID
    REFERENCES syllabus_topics (id) ON DELETE SET NULL,
  ADD COLUMN learning_outcome TEXT,
  ADD COLUMN fingerprint TEXT,
  -- AI candidates land as 'pending' and are excluded from bank-first selection
  -- until a teacher approves them. Everything pre-existing is 'approved'.
  ADD COLUMN review_status TEXT NOT NULL DEFAULT 'approved'
    CHECK (review_status IN ('pending', 'approved', 'rejected'));

-- Dedup lookup (non-unique: import dedups gracefully in code, never hard-fails).
CREATE INDEX idx_edu_question_bank_fingerprint
  ON edu_question_bank_items (organization_id, school_id, fingerprint);

-- Bank-first selection filters on (status, review_status, program_track).
CREATE INDEX idx_edu_question_bank_selection
  ON edu_question_bank_items (
    organization_id, school_id, subject_name, status, review_status, program_track
  );

-- ─── edu_question_papers: review / approval governance ───────────────────────

ALTER TABLE edu_question_papers
  ADD COLUMN program_track TEXT NOT NULL DEFAULT 'board'
    CHECK (program_track IN (
      'board', 'jee_foundation', 'neet_foundation', 'ntse', 'olympiad'
    )),
  ADD COLUMN review_status TEXT NOT NULL DEFAULT 'draft'
    CHECK (review_status IN (
      'draft', 'submitted', 'changes_requested', 'approved', 'published', 'archived'
    )),
  ADD COLUMN submitted_by UUID REFERENCES users (id),
  ADD COLUMN submitted_at TIMESTAMPTZ,
  ADD COLUMN approved_by UUID REFERENCES users (id),
  ADD COLUMN approved_at TIMESTAMPTZ;

-- Existing published papers should reflect that in the new lifecycle column.
UPDATE edu_question_papers SET review_status = 'published' WHERE status = 'published';
UPDATE edu_question_papers SET review_status = 'archived' WHERE status = 'archived';

-- ─── edu_question_paper_items: AI-candidate moderation ───────────────────────

-- Widen source to include constrained AI candidates (kept 'ai_generated' for
-- backward compatibility with any legacy rows).
ALTER TABLE edu_question_paper_items
  DROP CONSTRAINT IF EXISTS edu_question_paper_items_source_check;
ALTER TABLE edu_question_paper_items
  ADD CONSTRAINT edu_question_paper_items_source_check
    CHECK (source IN ('bank', 'ai_generated', 'ai_candidate'));

ALTER TABLE edu_question_paper_items
  ADD COLUMN review_status TEXT NOT NULL DEFAULT 'approved'
    CHECK (review_status IN ('pending', 'approved', 'rejected'));

-- ─── edu_question_paper_reviews: governance trail ────────────────────────────

CREATE TABLE edu_question_paper_reviews (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  paper_id UUID NOT NULL REFERENCES edu_question_papers (id) ON DELETE CASCADE,
  organization_id UUID NOT NULL REFERENCES organizations (id),
  school_id UUID NOT NULL REFERENCES schools (id),
  round_number INT NOT NULL DEFAULT 1,
  status TEXT NOT NULL
    CHECK (status IN ('submitted', 'changes_requested', 'approved')),
  reviewer_user_id UUID REFERENCES users (id),
  comments TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now())
);

CREATE INDEX idx_edu_paper_reviews_paper
  ON edu_question_paper_reviews (paper_id, round_number);

ALTER TABLE edu_question_paper_reviews ENABLE ROW LEVEL SECURITY;
ALTER TABLE edu_question_paper_reviews FORCE ROW LEVEL SECURITY;

CREATE POLICY edu_question_paper_reviews_school_scope ON edu_question_paper_reviews
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

GRANT SELECT, INSERT ON edu_question_paper_reviews TO erp_tenant;
