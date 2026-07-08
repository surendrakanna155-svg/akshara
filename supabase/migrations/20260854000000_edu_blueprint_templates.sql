-- CI-C1 (Curriculum Intelligence keystone) — governed blueprint templates
-- (v3.0 §9.1). DORMANT additive schema: this migration CREATES the table only —
-- ZERO data seed, no code writes/reads it in production yet, no VPS/import wiring.
-- It exists so the CI-C1 template-aware solver has a governed shape to read once
-- board templates are transcribed (a later, owner-gated wave). Mirrors P1-CI-0's
-- dormant-seed pattern (20260853000000). Changes NO existing behaviour.
--
-- A template is EITHER platform/board-official (organization_id NULL — authored by
-- the platform team via the service role) OR school-custom (organization_id +
-- school_id set — a school's own clone/customization; v3.0 §9.3). Same certified
-- edu_* governance: FORCE RLS + narrow erp_tenant grants; platform rows are
-- read-only to tenants (subject_templates read-catalogue pattern — invariant I7).
-- Additive-only, nullable FKs to existing tables (invariant B4); no triggers on
-- certified tables; no destructive change.

CREATE TABLE edu_blueprint_templates (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id UUID REFERENCES organizations (id),   -- NULL = platform/board-official; else school-custom
  school_id UUID REFERENCES schools (id),               -- NULL for platform rows
  exam_profile_code TEXT,                               -- 'cbse_board','ts_board','jee_main',… (v2.0 §12)
  board_code TEXT,                                      -- board catalogue code (matches subject_templates.board convention)
  class_label TEXT,
  subject_name TEXT,
  exam_type TEXT,                                       -- unit_test … annual | dpp | mock
  version_label TEXT,                                   -- e.g. 'CBSE-X-Science-2026-SQP'
  academic_year_label TEXT,
  effective_from DATE,
  effective_to DATE,
  status TEXT NOT NULL DEFAULT 'draft'
    CHECK (status IN ('draft', 'active', 'archived')),  -- board revisions: archive, never overwrite
  structure JSONB NOT NULL DEFAULT '{}'::jsonb,         -- §9.2: sections / choice pools / weightage / quotas
  created_by UUID,
  created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now())
);

-- One template per (scope, profile, board, class, subject, exam type, version).
-- COALESCE keeps the key well-defined across the NULLable tenant/identity columns
-- (NULL org groups all platform rows together, so platform versions stay unique).
CREATE UNIQUE INDEX edu_blueprint_templates_identity
  ON edu_blueprint_templates (
    COALESCE(organization_id, '00000000-0000-0000-0000-000000000000'::uuid),
    COALESCE(school_id, '00000000-0000-0000-0000-000000000000'::uuid),
    COALESCE(exam_profile_code, ''),
    COALESCE(board_code, ''),
    COALESCE(class_label, ''),
    COALESCE(subject_name, ''),
    COALESCE(exam_type, ''),
    COALESCE(version_label, '')
  );

ALTER TABLE edu_blueprint_templates ENABLE ROW LEVEL SECURITY;
ALTER TABLE edu_blueprint_templates FORCE ROW LEVEL SECURITY;

-- School-custom rows: the certified edu_* _school_scope shape (org + school bound
-- to the caller's tenant). Governs SELECT/INSERT/UPDATE of a school's OWN templates.
CREATE POLICY edu_blueprint_templates_school_scope ON edu_blueprint_templates
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

-- Platform/board-official rows (organization_id NULL) are a global read catalogue
-- (invariant I7, subject_templates pattern): any school-scoped tenant may READ
-- them; only the platform service role (RLS bypass) writes them. Postgres ORs the
-- SELECT policies, so a school sees platform rows + its own school-scoped rows.
CREATE POLICY edu_blueprint_templates_platform_read ON edu_blueprint_templates
  FOR SELECT
  USING (
    organization_id IS NULL
    AND app_current_scope() = 'school'
  );

-- Schools read platform + own rows, and create/customize their own (archive, not
-- delete — board-revision semantics). No DELETE grant.
GRANT SELECT, INSERT, UPDATE ON edu_blueprint_templates TO erp_tenant;
