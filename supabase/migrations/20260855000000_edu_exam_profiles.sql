-- CI-C7 (Curriculum Intelligence) — Exam Profile Engine config entity
-- (spec Parts 13–14 / v3.0 Layer 4 "Exam Profile Engine"). DORMANT additive
-- schema: this migration CREATES the table only — ZERO data seed, no code
-- writes/reads it in production yet, no VPS/import wiring. It exists so the
-- CI-C7 profile engine has a governed shape to read once real profiles are
-- transcribed (a later, owner-gated wave). Mirrors the CI-C1 dormant pattern
-- (20260854000000_edu_blueprint_templates) exactly. Changes NO existing
-- behaviour: with no profile supplied, paper generation is byte-identical.
--
-- WHAT A PROFILE IS (Part 14): an Exam Profile controls HOW questions are
-- SELECTED (difficulty / Bloom / cognitive emphasis, reasoning depth, diagram
-- requirement, question-family distribution, time allocation) over the SAME
-- unchanged curriculum Knowledge Base. Board / Class / Subject / Chapters /
-- Exam Type / Blueprint stay independently configurable — the profile never
-- rewrites the curriculum (Part 13 Layer independence; invariant I2).
--
-- A profile is EITHER platform/official (organization_id NULL — authored by the
-- platform team via the service role) OR school-custom (organization_id +
-- school_id set — a school's own clone/customization). Same certified edu_*
-- governance: FORCE RLS + narrow erp_tenant grants; platform rows are read-only
-- to tenants (subject_templates read-catalogue pattern — invariant I7).
-- Additive-only, nullable FKs to existing tables; no triggers on certified
-- tables; no destructive change.

CREATE TABLE edu_exam_profiles (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id UUID REFERENCES organizations (id),   -- NULL = platform/official; else school-custom
  school_id UUID REFERENCES schools (id),               -- NULL for platform rows

  -- Identity / classification. profile_code is the essential key (Part 14 list):
  -- 'standard_board','advanced_board','foundation','jee_foundation',
  -- 'neet_foundation','olympiad','scholarship','talent_search','custom', …
  profile_code TEXT NOT NULL,
  title TEXT,
  description TEXT,

  -- Scope binding (Part 14 — Board/Class/Subject stay INDEPENDENTLY configurable;
  -- never merged). All nullable so a profile can be broad (board-wide) or narrow.
  board_code TEXT,                                      -- board catalogue code (subject_templates.board convention)
  class_label TEXT,
  subject_name TEXT,
  program_track TEXT NOT NULL DEFAULT 'board',          -- aligns to the edu program_track enum (board/jee_foundation/…)

  -- A1-11 config enrichment ─────────────────────────────────────────────────
  -- Selection weighting: chapter / difficulty / cognitive emphasis that BIASES
  -- (never overrides) bank-first selection. Shape:
  --   { "chapterEmphasis": {"<chapter>": <weight>},
  --     "difficultyEmphasis": {"easy|medium|hard": <weight>},
  --     "cognitiveEmphasis": {"remember|understand|apply|analyze|hots": <weight>} }
  selection_weighting JSONB NOT NULL DEFAULT '{}'::jsonb,
  time_allocation_minutes INTEGER,                      -- total paper duration target (minutes)
  time_allocation JSONB NOT NULL DEFAULT '{}'::jsonb,   -- optional per-section/type minute budget
  -- Reasoning depth requirement: { "minLevel": "<cognitive level>", "minCount": <n> }
  -- — at least minCount answered items must reach minLevel or above (higher-order).
  reasoning_depth JSONB NOT NULL DEFAULT '{}'::jsonb,
  diagram_requirement JSONB NOT NULL DEFAULT '{}'::jsonb, -- { "minCount": <n> }
  -- Question-family distribution: per question_type minimum count target.
  question_family_distribution JSONB NOT NULL DEFAULT '{}'::jsonb,

  -- A1-3 depth-not-scope ────────────────────────────────────────────────────
  -- A foundation/competitive profile may RAISE Bloom/reasoning/difficulty but
  -- must NEVER widen curriculum scope (chapters beyond the class syllabus)
  -- unless a field explicitly configures it (spec Part 14 Rule 6). The engine
  -- enforces this in pre-generation compatibility validation.
  foundation BOOLEAN NOT NULL DEFAULT false,            -- foundation/competitive profile
  allow_scope_extension BOOLEAN NOT NULL DEFAULT false, -- explicit escape hatch for additional_chapters
  additional_chapters JSONB NOT NULL DEFAULT '[]'::jsonb, -- extra chapters ONLY honoured when allow_scope_extension

  -- B7 capability gating (DEFAULT-ALLOW) ─────────────────────────────────────
  -- OPTIONAL gated-capability slug (e.g. 'exam_profile.foundation'). NULL = the
  -- profile is ungated. Gating DEFAULTS TO ALLOW: a profile is blocked ONLY when
  -- this slug is EXPLICITLY denied for the org — absence of a grant never blocks
  -- (invariant B7; never silently break existing generation).
  entitlement_slug TEXT,

  -- Lifecycle (board revisions: archive, never overwrite).
  version_label TEXT,
  academic_year_label TEXT,
  effective_from DATE,
  effective_to DATE,
  status TEXT NOT NULL DEFAULT 'draft'
    CHECK (status IN ('draft', 'active', 'archived')),
  created_by UUID,
  created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now())
);

-- One profile per (scope, profile code, board, class, subject, exam type-agnostic,
-- version). COALESCE keeps the key well-defined across the NULLable tenant/scope
-- columns (NULL org groups all platform rows together, so platform versions stay
-- unique). Mirrors edu_blueprint_templates_identity.
CREATE UNIQUE INDEX edu_exam_profiles_identity
  ON edu_exam_profiles (
    COALESCE(organization_id, '00000000-0000-0000-0000-000000000000'::uuid),
    COALESCE(school_id, '00000000-0000-0000-0000-000000000000'::uuid),
    COALESCE(profile_code, ''),
    COALESCE(board_code, ''),
    COALESCE(class_label, ''),
    COALESCE(subject_name, ''),
    COALESCE(program_track, ''),
    COALESCE(version_label, '')
  );

ALTER TABLE edu_exam_profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE edu_exam_profiles FORCE ROW LEVEL SECURITY;

-- School-custom rows: the certified edu_* _school_scope shape (org + school bound
-- to the caller's tenant). Governs SELECT/INSERT/UPDATE of a school's OWN profiles.
CREATE POLICY edu_exam_profiles_school_scope ON edu_exam_profiles
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

-- Platform/official rows (organization_id NULL) are a global read catalogue
-- (invariant I7, subject_templates pattern): any school-scoped tenant may READ
-- them; only the platform service role (RLS bypass) writes them. Postgres ORs the
-- SELECT policies, so a school sees platform rows + its own school-scoped rows.
CREATE POLICY edu_exam_profiles_platform_read ON edu_exam_profiles
  FOR SELECT
  USING (
    organization_id IS NULL
    AND app_current_scope() = 'school'
  );

-- Schools read platform + own rows, and create/customize their own (archive, not
-- delete — board-revision semantics). No DELETE grant.
GRANT SELECT, INSERT, UPDATE ON edu_exam_profiles TO erp_tenant;
