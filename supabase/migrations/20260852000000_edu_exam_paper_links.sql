-- CI-0b (Curriculum Intelligence seam) — paper ↔ exam link table (v3.0 §5.2).
--
-- Maps an ERP exam (TEXT exam_id, matching exam_mark_entries.exam_id) to a
-- generated question paper (UUID paper_id) for a given set (A/B/C…). One link
-- per (org, school, exam, set). ADDITIVE-ONLY seam: the table + its repo exist
-- so callers CAN persist/read the mapping; it is NOT yet wired into the publish
-- path (that lands with the multi-set / paper↔exam wave), so this migration
-- changes NO existing behaviour. Same certified `_school_scope` + FORCE RLS +
-- narrow erp_tenant grant as every other edu_* governance table.

CREATE TABLE edu_exam_paper_links (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id UUID NOT NULL REFERENCES organizations (id),
  school_id UUID NOT NULL REFERENCES schools (id),
  exam_id TEXT NOT NULL,                              -- matches exam_mark_entries.exam_id (TEXT)
  paper_id UUID REFERENCES edu_question_papers (id),  -- UUID FK to the generated paper
  set_code TEXT NOT NULL DEFAULT 'A',
  created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),
  UNIQUE (organization_id, school_id, exam_id, set_code)
);

ALTER TABLE edu_exam_paper_links ENABLE ROW LEVEL SECURITY;
ALTER TABLE edu_exam_paper_links FORCE ROW LEVEL SECURITY;

CREATE POLICY edu_exam_paper_links_school_scope ON edu_exam_paper_links
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

-- SELECT/INSERT + UPDATE: a paper regenerated for the same (exam, set) re-points
-- the existing link (upsert), so UPDATE is required. No DELETE (links are
-- superseded, not removed).
GRANT SELECT, INSERT, UPDATE ON edu_exam_paper_links TO erp_tenant;
