-- CI-0c (Curriculum Intelligence seam) — DORMANT E1a schema seed (v3.0 §5.3).
--
-- Response spine + question-trust columns + item-exposure, applied DORMANT:
-- migrations only, ZERO UI, no code reads or writes these yet. They exist so the
-- v3.0 Phase-2 data-capture pipeline has somewhere to land (this data cannot be
-- backfilled — the seam must exist before capture begins). Additive-only; no
-- destructive change; every new table uses the certified edu_* _school_scope +
-- FORCE RLS + narrow erp_tenant grant. (Item-statistics is Phase-2 derived data
-- and lands with E1b, not here.)

-- ── 1. Response spine (v3.0 §5.2) — one row per student per paper item ───────
CREATE TABLE edu_student_item_responses (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id UUID NOT NULL REFERENCES organizations (id),
  school_id UUID NOT NULL REFERENCES schools (id),
  exam_id TEXT NOT NULL,
  paper_id UUID REFERENCES edu_question_papers (id),
  paper_item_id UUID,
  bank_item_id UUID,
  item_version INT NOT NULL DEFAULT 1,
  student_id UUID NOT NULL,
  max_marks NUMERIC NOT NULL,
  marks_awarded NUMERIC,
  is_correct BOOLEAN,
  attempted BOOLEAN NOT NULL DEFAULT true,
  chosen_option SMALLINT,
  time_spent_ms INT,
  capture_source TEXT NOT NULL CHECK (
    capture_source IN ('marks_grid_ocr', 'marks_grid_manual', 'digital_attempt', 'import')
  ),
  captured_by UUID,
  captured_at TIMESTAMPTZ,
  UNIQUE (organization_id, school_id, exam_id, paper_item_id, student_id)
);

ALTER TABLE edu_student_item_responses ENABLE ROW LEVEL SECURITY;
ALTER TABLE edu_student_item_responses FORCE ROW LEVEL SECURITY;

CREATE POLICY edu_student_item_responses_school_scope ON edu_student_item_responses
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

GRANT SELECT, INSERT ON edu_student_item_responses TO erp_tenant;

-- ── 2. Question-trust lifecycle columns on the bank (v3.0 §10.2) ─────────────
-- New rows default 'validated'; existing teacher-authored (live, approved) rows
-- migrate as 'trusted' (§10.2). Additive + a one-time backfill of the just-added
-- column — non-destructive.
ALTER TABLE edu_question_bank_items
  ADD COLUMN trust_status TEXT NOT NULL DEFAULT 'validated'
    CHECK (trust_status IN ('draft', 'validated', 'probation', 'trusted', 'quarantined', 'retired')),
  ADD COLUMN trust_promoted_at TIMESTAMPTZ,
  ADD COLUMN trust_evidence JSONB;

UPDATE edu_question_bank_items SET trust_status = 'trusted';

-- ── 3. Item exposure (v3.0 §10.1) — usage log + fast counters ────────────────
CREATE TABLE edu_item_exposures (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id UUID NOT NULL REFERENCES organizations (id),
  school_id UUID NOT NULL REFERENCES schools (id),
  bank_item_id UUID,
  section_id UUID,
  exam_id TEXT,
  used_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now())
);

ALTER TABLE edu_item_exposures ENABLE ROW LEVEL SECURITY;
ALTER TABLE edu_item_exposures FORCE ROW LEVEL SECURITY;

CREATE POLICY edu_item_exposures_school_scope ON edu_item_exposures
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

GRANT SELECT, INSERT ON edu_item_exposures TO erp_tenant;

ALTER TABLE edu_question_bank_items
  ADD COLUMN times_used INT NOT NULL DEFAULT 0,
  ADD COLUMN last_used_at TIMESTAMPTZ;
