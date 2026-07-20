-- W5 Smart OMR — capture → score ingestion (owner decision #8: Smart OMR
-- APPROVED, resolves D1; owner decision #15: Assessment Intelligence).
--
-- OMR is an ADDITIONAL capture path. The frozen Assessment Marks-Grid decision is
-- UNTOUCHED — this migration adds a NEW table only and changes NOTHING about the
-- certified marks-grid (exam_mark_entries) or the EIP-6 spine
-- (edu_student_item_responses). An OMR scan's scored per-item outcome is emitted
-- INTO the EIP-6 spine (source:'omr') by the ingestion handler, so OMR flows
-- through the SAME learning-evidence lane as practice / homework / exam. This
-- table is the ingestion + result store; the physical scan/image OCR is a
-- device/client concern and lands elsewhere as a list of {questionNo, marked}.
--
-- APPEND-ONLY, like the evidence spine: one scan result per
-- (org, school, exam, paper, student). A re-post of the same sheet is an
-- idempotent no-op at the application layer (the handler returns the existing
-- row); the UNIQUE index is the hard DB backstop. No UPDATE / DELETE grant — a
-- correction is a governance concern, not a silent overwrite.

CREATE TABLE edu_omr_scan_results (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id UUID NOT NULL REFERENCES organizations (id),
  school_id UUID NOT NULL REFERENCES schools (id),
  -- ERP exam context (TEXT, matches exam_mark_entries.exam_id / the EIP-6
  -- exam_id used as contextRef). The learning interaction "belongs to" this exam.
  exam_id TEXT NOT NULL,
  -- The generated question paper the sheet was answered against — the answer-key
  -- source. Scoring targets the paper's CANONICAL (master-set) option order.
  paper_id UUID NOT NULL REFERENCES edu_question_papers (id),
  student_id UUID NOT NULL,
  -- Informational provenance only (A/B/C…). Scoring uses the canonical order;
  -- scrambled per-set OMR realignment is a documented future extension.
  set_label TEXT,
  -- The raw sheet as read off the scanner: [{ "questionNo": int, "marked": [int] }].
  -- marked = 1-based option bubbles detected filled ([] = blank, >1 = ambiguous).
  marked_options JSONB NOT NULL DEFAULT '[]'::jsonb,
  -- Denormalized scored snapshot for a fast per-scan read. The EIP-6 spine is the
  -- system of record for per-item evidence; these are a convenience roll-up.
  total_score NUMERIC NOT NULL DEFAULT 0 CHECK (total_score >= 0),
  max_score NUMERIC NOT NULL DEFAULT 0 CHECK (max_score >= 0),
  correct_count INT NOT NULL DEFAULT 0 CHECK (correct_count >= 0),
  incorrect_count INT NOT NULL DEFAULT 0 CHECK (incorrect_count >= 0),
  blank_count INT NOT NULL DEFAULT 0 CHECK (blank_count >= 0),
  ambiguous_count INT NOT NULL DEFAULT 0 CHECK (ambiguous_count >= 0),
  unscored_count INT NOT NULL DEFAULT 0 CHECK (unscored_count >= 0),
  -- The scoring policy this result was produced under (so a re-score is auditable).
  blank_policy TEXT NOT NULL DEFAULT 'blank'
    CHECK (blank_policy IN ('blank', 'wrong')),
  multi_mark_policy TEXT NOT NULL DEFAULT 'blank'
    CHECK (multi_mark_policy IN ('blank', 'wrong', 'reject')),
  scanned_by UUID REFERENCES users (id),
  scored_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),
  created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now())
);

-- Idempotency backstop + per-student lookup: one scan per (exam, paper, student).
CREATE UNIQUE INDEX edu_omr_scan_results_idem
  ON edu_omr_scan_results (organization_id, school_id, exam_id, paper_id, student_id);

-- Per-paper read path (item-analysis / listing a paper's scans).
CREATE INDEX idx_edu_omr_scan_results_paper
  ON edu_omr_scan_results (organization_id, school_id, paper_id, scored_at DESC);

ALTER TABLE edu_omr_scan_results ENABLE ROW LEVEL SECURITY;
ALTER TABLE edu_omr_scan_results FORCE ROW LEVEL SECURITY;

-- School-scope only: OMR capture + item-analysis are staff (teacher / exam-admin)
-- actions. Same certified `_school_scope` shape as every other edu_* table.
CREATE POLICY edu_omr_scan_results_school_scope ON edu_omr_scan_results
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

-- APPEND-ONLY: SELECT + INSERT only. A scan result is never mutated in place.
GRANT SELECT, INSERT ON edu_omr_scan_results TO erp_tenant;
