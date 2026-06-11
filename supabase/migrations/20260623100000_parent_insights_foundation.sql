-- v10.8 — Parent Insights Center (insights only, no free chat)

CREATE TABLE parent_insight_snapshots (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id UUID NOT NULL REFERENCES organizations (id),
  school_id UUID NOT NULL REFERENCES schools (id),
  student_id UUID NOT NULL REFERENCES students (id) ON DELETE CASCADE,
  period TEXT NOT NULL CHECK (period IN ('daily', 'weekly', 'monthly', 'exam_prep')),
  language TEXT NOT NULL DEFAULT 'english',
  strengths JSONB NOT NULL DEFAULT '[]'::jsonb,
  weaknesses JSONB NOT NULL DEFAULT '[]'::jsonb,
  attendance_insights JSONB NOT NULL DEFAULT '[]'::jsonb,
  homework_insights JSONB NOT NULL DEFAULT '[]'::jsonb,
  improvement_suggestions JSONB NOT NULL DEFAULT '[]'::jsonb,
  teacher_remarks_summary TEXT,
  progress_summary TEXT NOT NULL DEFAULT '',
  voice_ready BOOLEAN NOT NULL DEFAULT true,
  printable BOOLEAN NOT NULL DEFAULT true,
  generated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),
  created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now())
);

CREATE INDEX idx_parent_insight_snapshots_student
  ON parent_insight_snapshots (organization_id, school_id, student_id, period, generated_at DESC);

ALTER TABLE parent_insight_snapshots ENABLE ROW LEVEL SECURITY;
ALTER TABLE parent_insight_snapshots FORCE ROW LEVEL SECURITY;

CREATE POLICY parent_insight_snapshots_school_scope ON parent_insight_snapshots
  FOR ALL
  USING (
    organization_id = app_current_tenant_id()
    AND school_id = app_current_school_id()
  );

GRANT SELECT, INSERT ON parent_insight_snapshots TO erp_tenant;
