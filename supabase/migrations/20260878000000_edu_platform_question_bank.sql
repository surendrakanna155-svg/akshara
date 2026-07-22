-- Program D · M1.1 (+ M2.1 calibration column) — certified PLATFORM question bank
-- + school adoption-by-reference table. DORMANT, additive, owner-gated apply.
--
-- Contract-2 §2.1 / §2.2 (docs/roadmap/PROGRAM_D_CONTRACTS.md) is normative for the
-- column names / types / CHECK values below. This migration is the DDL producer for
-- the platform bank (WP-B). Consumers: WP-C writes the platform rows (service role,
-- RLS bypass), WP-E reads the union, WP-D reads the near-dup vectors.
--
-- DORMANT: CREATE-only, ZERO data seed, ZERO wiring. No production code reads or
-- writes these tables yet; the certified bank is filled by a later, owner-approved
-- certified-content run (the bank is EMPTY today — readiness report blocker #1), and
-- Program D stays dark until a per-tenant flag is flipped (see 20260880000000).
--
-- Two tables:
--   1. edu_platform_question_bank  — platform-owned certified items (organization_id
--      NULL = platform sentinel). content_hash is the global importer idempotency key
--      (Contract-1 D5). Recall = TOMBSTONE (status flips to 'tombstoned'; append-only,
--      never a hard delete). difficulty_calibration [M2.1] separates PREDICTED from
--      MEASURED calibration and is never blended (certified export is always
--      'predicted_uncalibrated'; 'measured_pilot' lands only after real pilot data).
--      question_type CHECK is WIDENED with 'numerical' vs the school bank — a widening,
--      never a weakening (Contract-1 §1.4: future NUMERIC/INTEGER QIE types map here).
--   2. edu_school_adopted_items    — adoption BY REFERENCE (never a row copy). A school
--      adopts a platform item by id; recall propagates automatically because the union
--      view only surfaces adopted items whose platform row is still 'active'.
--
-- Governance mirrors the certified edu_* platform-read catalogue shape EXACTLY
-- (20260877000000_edu_concept_vocabulary / 20260859000000_edu_canonical_concept_graph):
-- FORCE RLS + _school_scope FOR ALL + _platform_read FOR SELECT (org NULL) + narrow
-- GRANT SELECT, INSERT, UPDATE (no DELETE — recall by tombstone, never delete) +
-- COALESCE identity index. The adoption table is a tenant-owned record (school-scope
-- only, no platform-read).
--
-- Reversibility (additive + dormant ⇒ safe; nothing reads it). Owner-gated DOWN:
--   DROP TABLE IF EXISTS edu_school_adopted_items;
--   DROP TABLE IF EXISTS edu_platform_question_bank;

-- ── 1. edu_platform_question_bank — platform-owned certified items (Contract-2 §2.1) ─

CREATE TABLE edu_platform_question_bank (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),                 -- surrogate
  organization_id UUID REFERENCES organizations (id),           -- NULL = platform (platform-read sentinel)
  school_id UUID REFERENCES schools (id),                       -- NULL for platform rows
  content_hash TEXT NOT NULL UNIQUE,                            -- = Contract-1 content_hash; global importer idempotency key
  stem_norm_hash TEXT,                                          -- exact-dup aid
  subject_name TEXT NOT NULL,
  chapter TEXT NOT NULL DEFAULT '',
  topic TEXT NOT NULL DEFAULT '',
  difficulty TEXT
    CHECK (difficulty IN ('easy', 'medium', 'hard')),
  difficulty_calibration TEXT NOT NULL DEFAULT 'predicted_uncalibrated'
    CHECK (difficulty_calibration IN ('predicted_uncalibrated', 'measured_pilot')),  -- M2.1: predicted vs measured, never blend
  question_type TEXT
    CHECK (question_type IN (
      'mcq', 'fill_blank', 'match', 'short_answer', 'long_answer', 'diagram', 'numerical'
    )),                                                          -- WIDENED with 'numerical' (a widening, never a weakening)
  marks INT CHECK (marks > 0),
  question_text TEXT NOT NULL,
  answer_text TEXT,
  options JSONB NOT NULL DEFAULT '[]'::jsonb,
  answer_label TEXT,
  cognitive_level TEXT
    CHECK (cognitive_level IS NULL OR cognitive_level IN (
      'remember', 'understand', 'apply', 'analyze', 'hots'
    )),
  program_track TEXT NOT NULL DEFAULT 'board',
  kc_id TEXT,                                                   -- QIE concept id provenance (KC_<sha14>)
  concept_uuid UUID,                                            -- loose ref (canonical_concepts dormant/empty); no FK
  near_dup_embedding JSONB,                                     -- number[128], offline-computed (WP-A recipe)
  near_dup_model_version TEXT,                                  -- e.g. 'hashvec-128-v1'
  provenance JSONB,                                             -- Contract-1 provenance object
  frozen_version TEXT,
  status TEXT NOT NULL DEFAULT 'active'
    CHECK (status IN ('active', 'tombstoned')),                 -- recall = tombstone (append-only), never hard-delete
  recalled_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now())
);

-- content_hash is the GLOBAL idempotency key (inline UNIQUE above; importer targets
-- ON CONFLICT (content_hash)). The COALESCE identity index below additionally carries
-- the scope-aware catalogue-shape identity, mirroring the sibling edu_* tables so the
-- governance shape is identical across the certified catalogue family.
CREATE UNIQUE INDEX edu_platform_question_bank_identity
  ON edu_platform_question_bank (
    COALESCE(organization_id, '00000000-0000-0000-0000-000000000000'::uuid),
    COALESCE(school_id, '00000000-0000-0000-0000-000000000000'::uuid),
    COALESCE(content_hash, '')
  );
CREATE INDEX edu_platform_question_bank_concept_uuid ON edu_platform_question_bank (concept_uuid);
CREATE INDEX edu_platform_question_bank_stem_norm_hash ON edu_platform_question_bank (stem_norm_hash);
CREATE INDEX edu_platform_question_bank_status ON edu_platform_question_bank (status);

ALTER TABLE edu_platform_question_bank ENABLE ROW LEVEL SECURITY;
ALTER TABLE edu_platform_question_bank FORCE ROW LEVEL SECURITY;

-- A school's own custom rows (org/school set): read + write.
CREATE POLICY edu_platform_question_bank_school_scope ON edu_platform_question_bank
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

-- Platform rows (organization_id NULL): READABLE by every school tenant; writable only
-- by the platform service role (RLS bypass) — deliberately NO platform-write policy.
CREATE POLICY edu_platform_question_bank_platform_read ON edu_platform_question_bank
  FOR SELECT
  USING (
    organization_id IS NULL
    AND app_current_scope() = 'school'
  );

GRANT SELECT, INSERT, UPDATE ON edu_platform_question_bank TO erp_tenant;  -- no DELETE: recall = tombstone, never delete

-- ── 2. edu_school_adopted_items — adoption BY REFERENCE, never a row copy (§2.2) ─────
-- A school adopts a platform item by id. Recall propagates for free: the union view
-- only surfaces adopted items whose platform row is still 'active', so tombstoning a
-- platform item drops it from every adopting school's pool automatically.

CREATE TABLE edu_school_adopted_items (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id UUID NOT NULL REFERENCES organizations (id),  -- adopting tenant
  school_id UUID NOT NULL REFERENCES schools (id),              -- adopting school
  platform_item_id UUID NOT NULL REFERENCES edu_platform_question_bank (id),  -- reference, not a copy
  adopted_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),
  adopted_by UUID,
  UNIQUE (organization_id, school_id, platform_item_id)
);

CREATE INDEX edu_school_adopted_items_platform_item_id ON edu_school_adopted_items (platform_item_id);

ALTER TABLE edu_school_adopted_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE edu_school_adopted_items FORCE ROW LEVEL SECURITY;

-- Tenant-owned adoption records: school-scope only (no platform-read — this is not a
-- platform catalogue).
CREATE POLICY edu_school_adopted_items_school_scope ON edu_school_adopted_items
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

GRANT SELECT, INSERT, UPDATE ON edu_school_adopted_items TO erp_tenant;  -- no DELETE: un-adopt is a future explicit op, not a raw delete
