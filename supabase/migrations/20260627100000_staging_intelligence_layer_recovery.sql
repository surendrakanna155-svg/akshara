-- v15.7 — Staging intelligence layer recovery (idempotent)
-- Repairs staging when 20260621000000_intelligence_layer_foundation.sql did not apply
-- due to broken permission migrations blocking the chain (permissions → permission_definitions).

-- ─── intel_student_risk_snapshots ────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS intel_student_risk_snapshots (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id UUID NOT NULL REFERENCES organizations (id),
  school_id UUID NOT NULL REFERENCES schools (id),
  student_id UUID NOT NULL REFERENCES students (id) ON DELETE CASCADE,
  academic_year_label TEXT NOT NULL DEFAULT '',
  class_name TEXT NOT NULL DEFAULT '',
  section_name TEXT,
  risk_score INT NOT NULL CHECK (risk_score >= 0 AND risk_score <= 100),
  risk_level TEXT NOT NULL
    CHECK (risk_level IN ('low', 'medium', 'high', 'critical')),
  reasons JSONB NOT NULL DEFAULT '[]'::jsonb,
  interventions JSONB NOT NULL DEFAULT '[]'::jsonb,
  teacher_actions JSONB NOT NULL DEFAULT '[]'::jsonb,
  parent_notifications JSONB NOT NULL DEFAULT '[]'::jsonb,
  inputs JSONB NOT NULL DEFAULT '{}'::jsonb,
  computed_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),
  created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now())
);

CREATE INDEX IF NOT EXISTS idx_intel_student_risk_school_class
  ON intel_student_risk_snapshots (organization_id, school_id, class_name, risk_level);

CREATE INDEX IF NOT EXISTS idx_intel_student_risk_student
  ON intel_student_risk_snapshots (organization_id, school_id, student_id, computed_at DESC);

ALTER TABLE intel_student_risk_snapshots ENABLE ROW LEVEL SECURITY;
ALTER TABLE intel_student_risk_snapshots FORCE ROW LEVEL SECURITY;

DO $policy$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'public'
      AND tablename = 'intel_student_risk_snapshots'
      AND policyname = 'intel_student_risk_school_scope'
  ) THEN
    CREATE POLICY intel_student_risk_school_scope ON intel_student_risk_snapshots
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
  END IF;
END
$policy$;

GRANT SELECT, INSERT, UPDATE, DELETE ON intel_student_risk_snapshots TO erp_tenant;

-- ─── intel_communication_drafts ──────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS intel_communication_drafts (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id UUID NOT NULL REFERENCES organizations (id),
  school_id UUID NOT NULL REFERENCES schools (id),
  scenario TEXT NOT NULL,
  student_id UUID REFERENCES students (id) ON DELETE SET NULL,
  custom_note TEXT,
  languages JSONB NOT NULL DEFAULT '["english"]'::jsonb,
  outputs JSONB NOT NULL DEFAULT '{}'::jsonb,
  created_by UUID REFERENCES users (id),
  created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now())
);

CREATE INDEX IF NOT EXISTS idx_intel_comm_drafts_school
  ON intel_communication_drafts (organization_id, school_id, created_at DESC);

ALTER TABLE intel_communication_drafts ENABLE ROW LEVEL SECURITY;
ALTER TABLE intel_communication_drafts FORCE ROW LEVEL SECURITY;

DO $policy$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'public'
      AND tablename = 'intel_communication_drafts'
      AND policyname = 'intel_comm_drafts_school_scope'
  ) THEN
    CREATE POLICY intel_comm_drafts_school_scope ON intel_communication_drafts
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
  END IF;
END
$policy$;

GRANT SELECT, INSERT ON intel_communication_drafts TO erp_tenant;

-- ─── intel_parent_guidance_reports ───────────────────────────────────────────

CREATE TABLE IF NOT EXISTS intel_parent_guidance_reports (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id UUID NOT NULL REFERENCES organizations (id),
  school_id UUID NOT NULL REFERENCES schools (id),
  student_id UUID NOT NULL REFERENCES students (id) ON DELETE CASCADE,
  mode TEXT NOT NULL CHECK (mode IN ('weekly', 'monthly', 'exam_review')),
  language TEXT NOT NULL DEFAULT 'english',
  inputs JSONB NOT NULL DEFAULT '{}'::jsonb,
  report JSONB NOT NULL DEFAULT '{}'::jsonb,
  status TEXT NOT NULL DEFAULT 'draft'
    CHECK (status IN ('draft', 'published')),
  created_by UUID REFERENCES users (id),
  created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now())
);

CREATE INDEX IF NOT EXISTS idx_intel_parent_guidance_student
  ON intel_parent_guidance_reports (organization_id, school_id, student_id);

DROP TRIGGER IF EXISTS intel_parent_guidance_reports_updated_at ON intel_parent_guidance_reports;
CREATE TRIGGER intel_parent_guidance_reports_updated_at
  BEFORE UPDATE ON intel_parent_guidance_reports
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

ALTER TABLE intel_parent_guidance_reports ENABLE ROW LEVEL SECURITY;
ALTER TABLE intel_parent_guidance_reports FORCE ROW LEVEL SECURITY;

DO $policy$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'public'
      AND tablename = 'intel_parent_guidance_reports'
      AND policyname = 'intel_parent_guidance_school_scope'
  ) THEN
    CREATE POLICY intel_parent_guidance_school_scope ON intel_parent_guidance_reports
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
  END IF;
END
$policy$;

GRANT SELECT, INSERT, UPDATE ON intel_parent_guidance_reports TO erp_tenant;

-- ─── Intelligence RBAC (idempotent) ──────────────────────────────────────────

INSERT INTO permission_definitions (slug, module, action, scope, description) VALUES
  ('viewStudentRisk', 'Intelligence', 'view', 'school', 'View student risk dashboards and alerts'),
  ('generateIntelligence', 'Intelligence', 'manage', 'school', 'Generate risk scores, messages, and guidance reports')
ON CONFLICT (slug) DO NOTHING;

INSERT INTO role_permissions (role_slug, permission_slug) VALUES
  ('superAdmin', 'viewStudentRisk'),
  ('superAdmin', 'generateIntelligence'),
  ('schoolAdmin', 'viewStudentRisk'),
  ('schoolAdmin', 'generateIntelligence'),
  ('principal', 'viewStudentRisk'),
  ('principal', 'generateIntelligence'),
  ('teacher', 'viewStudentRisk'),
  ('teacher', 'generateIntelligence'),
  ('management', 'viewStudentRisk'),
  ('management', 'generateIntelligence')
ON CONFLICT DO NOTHING;

-- ─── Tenant isolation probe fixtures ─────────────────────────────────────────

INSERT INTO intel_student_risk_snapshots (
  id, organization_id, school_id, student_id,
  academic_year_label, class_name, risk_score, risk_level, reasons
) VALUES
  (
    'f0500000-0000-4000-8000-000000000001',
    'a1000000-0000-4000-8000-000000000001',
    'a2000000-0000-4000-8000-000000000001',
    'a4000000-0000-4000-8000-000000000001',
    '2025-26', 'Grade 8', 72, 'high', '[]'::jsonb
  ),
  (
    'f0500000-0000-4000-8000-000000000002',
    'a1000000-0000-4000-8000-000000000001',
    'a2000000-0000-4000-8000-000000000002',
    'a4000000-0000-4000-8000-000000000002',
    '2025-26', 'Grade 9', 45, 'medium', '[]'::jsonb
  )
ON CONFLICT (id) DO NOTHING;
