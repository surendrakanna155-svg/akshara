-- B12 (BACKWARD_COMPATIBILITY_PLAN.md) / AIMS Amendment A1-4/A1-5/A1-8
-- (GAP_ANALYSIS.md) — Question Factory asset schema: reusable Item Models,
-- Question Families, and a concept-linked Distractor Library. DORMANT
-- additive schema: this migration CREATES tables only — ZERO data seed, no
-- code writes/reads them in production yet, no wiring into any handler or
-- service. It exists so the CI-C10 offline batch factory (a later,
-- owner-gated wave, per A1-O1: after CI-C5 + CI-E1b) has a governed shape to
-- land generated assets in. Changes NO existing behaviour.
--
-- BACKWARD_COMPATIBILITY_PLAN.md B12: "New asset tables: `edu_question_templates`
-- (Item Models), `edu_question_families`, `edu_distractors` … — None [risk] —
-- greenfield tables. Certified RLS shape; nullable FKs to existing tables;
-- factory/diagram outputs enter as candidates only through the D-6 lifecycle
-- (I3/I4 verbatim) — nothing auto-certifies." `edu_diagrams` (also listed under
-- B12, CI-C11 Diagram Intelligence) is explicitly OUT of scope for this
-- migration — it belongs to the separate CI-C11 wave.
--
-- Governance mirrors the certified CI-C1 (`20260854000000_edu_blueprint_templates`)
-- / CI-C7 (`20260855000000_edu_exam_profiles`) shape EXACTLY: FORCE RLS,
-- `_school_scope` policy (a school's own rows), `_platform_read` catalogue
-- policy (platform/global rows are a read-only catalogue to every tenant —
-- invariant I7, `subject_templates` read-grant pattern), narrow
-- `GRANT SELECT, INSERT, UPDATE` to `erp_tenant` (no DELETE — archive, never
-- delete), and a COALESCE identity unique index across the nullable
-- tenant/scope columns. Every FK to an existing table is nullable
-- (invariant B4). No triggers on certified tables. No destructive change.

-- ── 1. Question Families — AIMS "Question Family Entity" ────────────────────
-- Groups all educational variations (MCQ, Very Short, Short, Long, Essay, Case
-- Study, Assertion-Reason, Numerical, Diagram, Practical, Application, Project,
-- Activity, …) under one canonical concept. "Every family belongs to one
-- Concept" (AIMS) — one family serves every board that maps the concept
-- (v3.0 §8.3). A family is EITHER platform/global (organization_id NULL —
-- platform-curated) OR school-custom (organization_id + school_id set).

CREATE TABLE edu_question_families (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id UUID REFERENCES organizations (id),   -- NULL = platform/global family; else school-custom
  school_id UUID REFERENCES schools (id),               -- NULL for platform rows
  family_code TEXT NOT NULL,             -- 'mcq','very_short','short','long','essay','case_study',
                                          -- 'assertion_reason','numerical','diagram','practical',
                                          -- 'application','project','activity',… (AIMS Question Family Entity)
  title TEXT,
  description TEXT,
  concept_id UUID,                       -- forward-reference: canonical_concepts lands with CI-E1b
                                          -- (next migration); plain UUID, no FK yet — the same
                                          -- loose-reference precedent certified by 20260857000000
                                          -- ("the real FOREIGN KEY constraint gets added later, by the
                                          -- migration that creates the referenced table — never before").
                                          -- "Every family belongs to one Concept" (AIMS).
  status TEXT NOT NULL DEFAULT 'draft'
    CHECK (status IN ('draft', 'active', 'archived')),
  created_by UUID,
  created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now())
);

-- One family per (scope, concept, family code). COALESCE keeps the key
-- well-defined across the NULLable tenant/concept columns, mirroring
-- edu_blueprint_templates_identity / edu_exam_profiles_identity exactly.
CREATE UNIQUE INDEX edu_question_families_identity
  ON edu_question_families (
    COALESCE(organization_id, '00000000-0000-0000-0000-000000000000'::uuid),
    COALESCE(school_id, '00000000-0000-0000-0000-000000000000'::uuid),
    COALESCE(concept_id, '00000000-0000-0000-0000-000000000000'::uuid),
    COALESCE(family_code, '')
  );

ALTER TABLE edu_question_families ENABLE ROW LEVEL SECURITY;
ALTER TABLE edu_question_families FORCE ROW LEVEL SECURITY;

CREATE POLICY edu_question_families_school_scope ON edu_question_families
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

CREATE POLICY edu_question_families_platform_read ON edu_question_families
  FOR SELECT
  USING (
    organization_id IS NULL
    AND app_current_scope() = 'school'
  );

GRANT SELECT, INSERT, UPDATE ON edu_question_families TO erp_tenant;

-- ── 2. Question Templates — AIMS "Question Template Entity" (Item Models) ───
-- Reusable Item Models supporting controlled parameter variation: one Item
-- Model can generate many curriculum-compliant questions while preserving
-- originality (AIMS Automatic Item Generation, A1-4). References the family
-- created above (real FK — same migration) and forward-references a concept
-- (FK lands with CI-E1b, same loose-reference precedent as above).

CREATE TABLE edu_question_templates (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id UUID REFERENCES organizations (id),   -- NULL = platform/official Item Model; else school-custom
  school_id UUID REFERENCES schools (id),
  template_code TEXT,                    -- stable slug, e.g. 'phy_ohms_law_numerical_v1'
  title TEXT,
  concept_id UUID,                       -- forward-reference: FK added when canonical_concepts lands (CI-E1b)
  question_family_id UUID REFERENCES edu_question_families (id),  -- real FK: created above, same migration
  question_type TEXT                     -- optional alignment with edu_question_bank_items.question_type
    CHECK (question_type IS NULL OR question_type IN (
      'mcq', 'fill_blank', 'match', 'short_answer', 'long_answer', 'diagram'
    )),
  stem_template TEXT,                    -- parameterized stem, e.g. 'A block of mass {m} kg …'
  parameter_variables JSONB NOT NULL DEFAULT '[]'::jsonb,  -- [{name, type, domain/range, generation rule}, …]
  constraints JSONB NOT NULL DEFAULT '{}'::jsonb,          -- cross-variable constraints (e.g. m > 0)
  generation_rules JSONB NOT NULL DEFAULT '{}'::jsonb,     -- substitution + derived-answer computation
  validation_rules JSONB NOT NULL DEFAULT '{}'::jsonb,     -- post-generation sanity/difficulty checks
  difficulty_range JSONB NOT NULL DEFAULT '{}'::jsonb,     -- {"min":"easy","max":"hard"}
  learning_outcome TEXT,                 -- objective binding; mirrors edu_question_bank_items.learning_outcome
  competency TEXT,                       -- competency binding; mirrors edu_question_bank_items.competency
  supported_exam_profiles JSONB NOT NULL DEFAULT '[]'::jsonb,  -- [exam_profile_code, …] loose reference
  status TEXT NOT NULL DEFAULT 'draft'
    CHECK (status IN ('draft', 'active', 'archived')),
  created_by UUID,
  created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now())
);

CREATE UNIQUE INDEX edu_question_templates_identity
  ON edu_question_templates (
    COALESCE(organization_id, '00000000-0000-0000-0000-000000000000'::uuid),
    COALESCE(school_id, '00000000-0000-0000-0000-000000000000'::uuid),
    COALESCE(concept_id, '00000000-0000-0000-0000-000000000000'::uuid),
    COALESCE(question_family_id, '00000000-0000-0000-0000-000000000000'::uuid),
    COALESCE(template_code, '')
  );

ALTER TABLE edu_question_templates ENABLE ROW LEVEL SECURITY;
ALTER TABLE edu_question_templates FORCE ROW LEVEL SECURITY;

CREATE POLICY edu_question_templates_school_scope ON edu_question_templates
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

CREATE POLICY edu_question_templates_platform_read ON edu_question_templates
  FOR SELECT
  USING (
    organization_id IS NULL
    AND app_current_scope() = 'school'
  );

GRANT SELECT, INSERT, UPDATE ON edu_question_templates TO erp_tenant;

-- ── 3. Distractors — AIMS "Distractor Entity" (Distractor Library, A1-8) ────
-- Distractors as first-class, misconception-categorised, concept-linked
-- assets with reuse (v3.0 D6/A1-8). `question_id` is a real FK to the
-- certified `edu_question_bank_items` (that table already exists), nullable —
-- a library entry may be authored as a concept-linked exemplar ahead of being
-- attached to any specific bank question (offline factory territory).

CREATE TABLE edu_distractors (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id UUID REFERENCES organizations (id),   -- NULL = platform/global library entry; else school-scoped
  school_id UUID REFERENCES schools (id),
  question_id UUID REFERENCES edu_question_bank_items (id) ON DELETE SET NULL,  -- real FK: table exists today
  concept_id UUID,                       -- forward-reference: FK added when canonical_concepts lands (CI-E1b)
  distractor_text TEXT NOT NULL,
  misconception_type TEXT,               -- categorised misconception label (AIMS Distractor Entity)
  difficulty TEXT
    CHECK (difficulty IS NULL OR difficulty IN ('easy', 'medium', 'hard')),
  selection_frequency NUMERIC,           -- Phase-2 derived: % of students historically choosing this (dormant)
  confusion_score NUMERIC,
  teacher_rating NUMERIC,
  reuse_score NUMERIC,
  quality_score NUMERIC,
  status TEXT NOT NULL DEFAULT 'draft'
    CHECK (status IN ('draft', 'active', 'archived', 'retired')),
  created_by UUID,
  created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now())
);

-- No natural one-per-key identity index here: many distractors legitimately
-- share the same question/concept (that IS the point of a Distractor
-- Library). Regular lookup indexes instead — mirrors the non-unique index
-- style already certified elsewhere (idx_edu_question_bank_school_subject).
CREATE INDEX idx_edu_distractors_concept
  ON edu_distractors (organization_id, school_id, concept_id);
CREATE INDEX idx_edu_distractors_question
  ON edu_distractors (question_id);

ALTER TABLE edu_distractors ENABLE ROW LEVEL SECURITY;
ALTER TABLE edu_distractors FORCE ROW LEVEL SECURITY;

CREATE POLICY edu_distractors_school_scope ON edu_distractors
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

CREATE POLICY edu_distractors_platform_read ON edu_distractors
  FOR SELECT
  USING (
    organization_id IS NULL
    AND app_current_scope() = 'school'
  );

GRANT SELECT, INSERT, UPDATE ON edu_distractors TO erp_tenant;

-- ── 4. Backfill the forward-referenced FK on edu_question_bank_items ────────
-- `question_family_id` was added as a schema-only placeholder by
-- 20260857000000 ("their referenced tables do not exist yet … the real
-- FOREIGN KEY constraint gets added later, by the migration that creates the
-- referenced table — never before"). edu_question_families now exists
-- (above), so the constraint lands here. The column carries zero data today
-- (dormant, no code writes it) — validation is instant and safe.

ALTER TABLE edu_question_bank_items
  ADD CONSTRAINT edu_question_bank_items_question_family_id_fkey
    FOREIGN KEY (question_family_id) REFERENCES edu_question_families (id);
