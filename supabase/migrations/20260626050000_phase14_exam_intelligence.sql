-- Phase 14 — Exam & Academic Intelligence

CREATE TABLE intel_exam_intelligence_snapshots (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id UUID NOT NULL REFERENCES organizations (id),
  school_id UUID NOT NULL REFERENCES schools (id),
  snapshot_type TEXT NOT NULL
    CHECK (snapshot_type IN (
      'analytics', 'subject_performance', 'weak_chapters',
      'result_intelligence', 'academic_forecast', 'rank_movement'
    )),
  class_name TEXT,
  subject_name TEXT,
  exam_type TEXT,
  payload JSONB NOT NULL DEFAULT '{}'::jsonb,
  computed_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),
  created_by UUID REFERENCES users (id)
);

CREATE INDEX idx_intel_exam_intelligence_school_type
  ON intel_exam_intelligence_snapshots (
    organization_id, school_id, snapshot_type, computed_at DESC
  );

ALTER TABLE intel_exam_intelligence_snapshots ENABLE ROW LEVEL SECURITY;
ALTER TABLE intel_exam_intelligence_snapshots FORCE ROW LEVEL SECURITY;

CREATE POLICY intel_exam_intelligence_scope ON intel_exam_intelligence_snapshots
  FOR ALL USING (
    organization_id = app_current_tenant_id()
    AND school_id = app_current_school_id()
  );

GRANT SELECT, INSERT ON intel_exam_intelligence_snapshots TO erp_tenant;
