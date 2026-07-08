-- CI-E1b (Curriculum Intelligence) — DORMANT canonical-concept graph schema
-- (v3.0 §8.2 "Canonical Concept Layer", D4; GAP_ANALYSIS A1-1). DORMANT
-- additive schema: this migration CREATES tables only — ZERO data seed
-- (the CI-B4 Concept Graph dataset lands the actual concept rows in a later,
-- content-lane wave; this is schema only), no code reads or writes these yet,
-- no wiring into any handler or service, no UI. Changes NO existing
-- behaviour: `edu_question_bank_items.concept_id` stays NULL for every row
-- until a future wave populates and reads this graph.
--
-- Why now: "engines can be built any year; data cannot be backfilled" (v3.0
-- §5.3) applies to schema shape too — CI-C10 (Question Factory) and CI-C11
-- (Diagram Intelligence) both require a live concept read-path before they can
-- ship (AIMS Rule 2: "never generate isolated questions without Concept
-- mapping"), so the seam must exist before either factory is built.
--
-- Governance mirrors the certified CI-C1 (`20260854000000_edu_blueprint_templates`)
-- / CI-C7 (`20260855000000_edu_exam_profiles`) shape EXACTLY: FORCE RLS,
-- `_school_scope` policy, `_platform_read` catalogue policy (canonical
-- concepts are platform-curated per v3.0 §8.3, but the certified pattern is
-- reused rather than inventing a second shape for a "pure global" table),
-- narrow `GRANT SELECT, INSERT, UPDATE` to `erp_tenant` (no DELETE — archive/
-- retire, never delete), and a COALESCE identity unique index. FKs to
-- existing tables (`syllabus_chapters`, `syllabus_topics`) are nullable
-- (invariant B4). No triggers on certified tables. No destructive change.

-- ── 1. Canonical concepts — the graph nodes (v3.0 §8.2, AIMS Concept Entity) ─
-- Board syllabus trees remain separate and never auto-mapped for content
-- (v2.0 §9 stands); cognition is board-independent, so mastery lives on this
-- canonical spine. A concept row is EITHER platform/canonical (organization_id
-- NULL — platform-curated, v3.0 §8.3: "not per-school") OR a school-custom
-- clone (organization_id + school_id set).

CREATE TABLE canonical_concepts (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id UUID REFERENCES organizations (id),   -- NULL = platform/canonical (global); else school-custom clone
  school_id UUID REFERENCES schools (id),               -- NULL for platform rows
  concept_code TEXT NOT NULL,             -- permanent Concept ID, e.g. 'SCI_G06_PHY_FORCE_001' (AIMS A1-1 ID scheme)
  title TEXT NOT NULL,                    -- Concept Name
  definition TEXT,
  description TEXT,
  subject_domain TEXT,                    -- 'physics','mathematics',… (v3.0 §8.2)
  typical_grade_range INT4RANGE,          -- guidance, not restriction (v3.0 §8.2)
  bloom_levels JSONB NOT NULL DEFAULT '[]'::jsonb,          -- Bloom Levels (AIMS Concept Entity)
  difficulty_range JSONB NOT NULL DEFAULT '{}'::jsonb,      -- {"min":"easy","max":"hard"}
  curriculum_boundary JSONB NOT NULL DEFAULT '{}'::jsonb,   -- Curriculum Boundary attribute (AIMS)
  foundation_boundary JSONB NOT NULL DEFAULT '{}'::jsonb,   -- Foundation Boundary — depth-not-scope escape hatch (A1-3)
  common_misconceptions JSONB NOT NULL DEFAULT '[]'::jsonb, -- Common Misconceptions (AIMS Concept Entity)
  reference_facts JSONB NOT NULL DEFAULT '{}'::jsonb,       -- Formula/Scientific-Law/Theorem/Definition refs (AIMS)
  status TEXT NOT NULL DEFAULT 'active'
    CHECK (status IN ('active', 'merged', 'retired')),      -- v3.0 §8.2 literal enum
  merged_into UUID REFERENCES canonical_concepts (id),      -- concept dedup over time (v3.0 §8.2; self-FK)
  created_by UUID,
  created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now())
);

-- One concept per (scope, concept code). COALESCE keeps the key well-defined
-- across the NULLable tenant columns, mirroring edu_blueprint_templates_identity.
CREATE UNIQUE INDEX canonical_concepts_identity
  ON canonical_concepts (
    COALESCE(organization_id, '00000000-0000-0000-0000-000000000000'::uuid),
    COALESCE(school_id, '00000000-0000-0000-0000-000000000000'::uuid),
    COALESCE(concept_code, '')
  );

ALTER TABLE canonical_concepts ENABLE ROW LEVEL SECURITY;
ALTER TABLE canonical_concepts FORCE ROW LEVEL SECURITY;

CREATE POLICY canonical_concepts_school_scope ON canonical_concepts
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

CREATE POLICY canonical_concepts_platform_read ON canonical_concepts
  FOR SELECT
  USING (
    organization_id IS NULL
    AND app_current_scope() = 'school'
  );

GRANT SELECT, INSERT, UPDATE ON canonical_concepts TO erp_tenant;

-- ── 2. Concept relationship graph — the graph edges (v3.0 §8.2 `concept_prerequisites`) ─
-- v3.0 §8.2 names this table `concept_prerequisites` with a DAG of
-- (from_concept, to_concept, strength). GAP_ANALYSIS A1-1 extends its *scope*
-- (never its name — "same module, more dimensions; never a second engine",
-- invariant I2's rule applied here) to also carry parent/child, related, and
-- frequently-confused-misconception pairs on ONE edge table, discriminated by
-- `relationship_type`, rather than forking four near-duplicate tables.
-- Cycle-checking for the prerequisite DAG is application-level (v3.0 §8.2:
-- "cycle-checked in code") — dormant here, no code path exists yet.

CREATE TABLE concept_prerequisites (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id UUID REFERENCES organizations (id),   -- NULL = platform/global edge; else school-custom
  school_id UUID REFERENCES schools (id),
  from_concept_id UUID NOT NULL REFERENCES canonical_concepts (id) ON DELETE CASCADE,
  to_concept_id UUID NOT NULL REFERENCES canonical_concepts (id) ON DELETE CASCADE,
  relationship_type TEXT NOT NULL DEFAULT 'prerequisite'
    CHECK (relationship_type IN ('prerequisite', 'parent_child', 'related', 'confused_with')),
  strength NUMERIC,                      -- soft weighting for remediation pathing (v3.0 §8.2);
                                          -- doubles as a confusion strength for 'confused_with' edges
  notes TEXT,                            -- e.g. the misconception note for a 'confused_with' edge
  created_by UUID,
  created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),
  CHECK (from_concept_id <> to_concept_id)
);

-- One edge of a given relationship type between two concepts per scope.
CREATE UNIQUE INDEX concept_prerequisites_identity
  ON concept_prerequisites (
    COALESCE(organization_id, '00000000-0000-0000-0000-000000000000'::uuid),
    COALESCE(school_id, '00000000-0000-0000-0000-000000000000'::uuid),
    from_concept_id,
    to_concept_id,
    relationship_type
  );

ALTER TABLE concept_prerequisites ENABLE ROW LEVEL SECURITY;
ALTER TABLE concept_prerequisites FORCE ROW LEVEL SECURITY;

CREATE POLICY concept_prerequisites_school_scope ON concept_prerequisites
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

CREATE POLICY concept_prerequisites_platform_read ON concept_prerequisites
  FOR SELECT
  USING (
    organization_id IS NULL
    AND app_current_scope() = 'school'
  );

GRANT SELECT, INSERT, UPDATE ON concept_prerequisites TO erp_tenant;

-- ── 3. Concept ↔ board-content mappings (v3.0 §8.2 `concept_board_mappings`) ─
-- Where a canonical concept appears in each separate, versioned board content
-- tree (CBSE/TS/AP/ICSE/JEE, …) — the mapping layer, never a merge of the
-- trees themselves (v2.0 §9 invariant). `syllabus_chapter_id` /
-- `syllabus_topic_id` are real FKs — those tables already exist and are
-- school-scoped, so a mapping that names one is inherently school-scoped;
-- a pure board/profile-level mapping (board_code + exam_profile_code only,
-- no chapter/topic) may be a platform row. This invariant is documented, not
-- DB-enforced, matching the existing style (e.g. `additional_chapters` only
-- honoured when `allow_scope_extension`, enforced in code not by trigger).

CREATE TABLE concept_board_mappings (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id UUID REFERENCES organizations (id),   -- NULL = platform/board-official mapping; else school-scoped
  school_id UUID REFERENCES schools (id),
  canonical_concept_id UUID NOT NULL REFERENCES canonical_concepts (id) ON DELETE CASCADE,
  board_code TEXT,                       -- board catalogue code (subject_templates.board convention)
  syllabus_chapter_id UUID REFERENCES syllabus_chapters (id) ON DELETE SET NULL,  -- real FK: table exists today
  syllabus_topic_id UUID REFERENCES syllabus_topics (id) ON DELETE SET NULL,      -- real FK: table exists today
  exam_profile_code TEXT,                -- 'board' | 'jee_main' | 'neet' | … (edu_exam_profiles.profile_code convention)
  alignment TEXT NOT NULL DEFAULT 'exact'
    CHECK (alignment IN ('exact', 'partial', 'extends')),  -- v3.0 §8.2 literal enum (e.g. JEE Ohm's-Law > Class-10)
  curriculum_version_label TEXT,         -- loose label; no curriculum-versioning table exists yet (GAP_ANALYSIS B3)
  created_by UUID,
  created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now())
);

CREATE UNIQUE INDEX concept_board_mappings_identity
  ON concept_board_mappings (
    COALESCE(organization_id, '00000000-0000-0000-0000-000000000000'::uuid),
    COALESCE(school_id, '00000000-0000-0000-0000-000000000000'::uuid),
    canonical_concept_id,
    COALESCE(board_code, ''),
    COALESCE(syllabus_chapter_id, '00000000-0000-0000-0000-000000000000'::uuid),
    COALESCE(syllabus_topic_id, '00000000-0000-0000-0000-000000000000'::uuid),
    COALESCE(exam_profile_code, '')
  );

ALTER TABLE concept_board_mappings ENABLE ROW LEVEL SECURITY;
ALTER TABLE concept_board_mappings FORCE ROW LEVEL SECURITY;

CREATE POLICY concept_board_mappings_school_scope ON concept_board_mappings
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

CREATE POLICY concept_board_mappings_platform_read ON concept_board_mappings
  FOR SELECT
  USING (
    organization_id IS NULL
    AND app_current_scope() = 'school'
  );

GRANT SELECT, INSERT, UPDATE ON concept_board_mappings TO erp_tenant;

-- ── 4. Backfill every forward-referenced concept_id FK ──────────────────────
-- Each of these columns was added as a schema-only placeholder, documented at
-- the time as following the loose-reference precedent ("the real FOREIGN KEY
-- constraint gets added later, by the migration that creates the referenced
-- table — never before"): `edu_question_bank_items.concept_id`
-- (20260857000000) and `edu_question_families.concept_id` /
-- `edu_question_templates.concept_id` / `edu_distractors.concept_id`
-- (20260858000000, this program's own B12 migration, immediately prior).
-- canonical_concepts now exists (above), so every constraint lands here.
-- Every column is NULL-only today (dormant, no code writes them) —
-- validation is instant and safe, zero data impact.

ALTER TABLE edu_question_bank_items
  ADD CONSTRAINT edu_question_bank_items_concept_id_fkey
    FOREIGN KEY (concept_id) REFERENCES canonical_concepts (id);

ALTER TABLE edu_question_families
  ADD CONSTRAINT edu_question_families_concept_id_fkey
    FOREIGN KEY (concept_id) REFERENCES canonical_concepts (id);

ALTER TABLE edu_question_templates
  ADD CONSTRAINT edu_question_templates_concept_id_fkey
    FOREIGN KEY (concept_id) REFERENCES canonical_concepts (id);

ALTER TABLE edu_distractors
  ADD CONSTRAINT edu_distractors_concept_id_fkey
    FOREIGN KEY (concept_id) REFERENCES canonical_concepts (id);
