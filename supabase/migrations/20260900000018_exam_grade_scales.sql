-- PRA-P1-13 — per-school exam grade scale (grading bands + pass mark).
--
-- The school's chosen grading scale must PERSIST and be AUTHORITATIVE at publish
-- and report time. Previously the backend derived every letter grade from a
-- COMPILE-TIME constant (A+/A/B+/B/C/D/F, pass fixed at 40%), so a CBSE school
-- that picked an A1–E scale still had A+/A/B printed, and the pass boundary was
-- silently fixed. This table stores ONE row per school. When NO row exists the
-- backend falls back to the exact legacy constant, so a school that never
-- configures a scale sees ZERO behaviour change.
--
-- Shape mirrors the exam-domain per-school convention (exam_sessions RLS +
-- startup_onboarding single-row-per-school): gen_random_uuid PK,
-- (organization_id, school_id) UNIQUE, app_current_* school-scoped RLS,
-- erp_tenant grants, set_updated_at trigger. Seeded with nothing.

CREATE TABLE exam_grade_scales (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id UUID NOT NULL REFERENCES organizations (id),
  school_id UUID NOT NULL REFERENCES schools (id),
  -- Optional label for the chosen preset (e.g. 'cbse_a1_e' / 'custom'); free text.
  scale_code TEXT NOT NULL DEFAULT 'custom',
  -- Ordered grading bands, highest threshold first, e.g.
  --   [{"minPercent": 91, "letter": "A1"}, ... , {"minPercent": 0, "letter": "E"}]
  -- Bands are validated server-side (strictly descending minPercent, non-empty
  -- letters); the CHECK below only guards the coarse shape (non-empty JSON array).
  bands JSONB NOT NULL,
  -- Pass boundary as a percentage (0–100). Drives pass/fail in the distribution
  -- report. Defaults to the legacy 40%.
  pass_mark_percent NUMERIC(5, 2) NOT NULL DEFAULT 40,
  created_by UUID,
  updated_by UUID,
  created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),
  UNIQUE (organization_id, school_id),
  CONSTRAINT exam_grade_scales_bands_array CHECK (
    jsonb_typeof(bands) = 'array' AND jsonb_array_length(bands) >= 1
  ),
  CONSTRAINT exam_grade_scales_pass_mark_range CHECK (
    pass_mark_percent >= 0 AND pass_mark_percent <= 100
  )
);

CREATE INDEX idx_exam_grade_scales_school
  ON exam_grade_scales (organization_id, school_id);

CREATE TRIGGER exam_grade_scales_updated_at
  BEFORE UPDATE ON exam_grade_scales
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

ALTER TABLE exam_grade_scales ENABLE ROW LEVEL SECURITY;
ALTER TABLE exam_grade_scales FORCE ROW LEVEL SECURITY;

CREATE POLICY exam_grade_scales_school_scope ON exam_grade_scales
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

GRANT SELECT, INSERT, UPDATE ON exam_grade_scales TO erp_tenant;
