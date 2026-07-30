-- Program D · M0.2 — KC_ ↔ UUID concept vocabulary bridge (DORMANT, additive, owner-gated apply).
--
-- The QIE certified spine names concepts as KC_<sha14> (kie knowledge_index `ki_concept`); the ERP names
-- concepts as canonical_concepts.id (UUID). No crosswalk existed. This bridge is the single, authoritative
-- KC_ → UUID map: a certified item whose KC_ id is absent here is NOT promoted (honest-null, never a
-- guessed mapping — R5-3 D2; readiness report red-team #5).
--
-- DORMANT: CREATE-only, ZERO data seed. The crosswalk is seeded by the OFFLINE deterministic job
-- kie.qie.export.vocabulary from the frozen index's certified `ki_concept` rows — derived knowledge stays
-- local-only, so the seed is applied at deploy time (owner-gated), never inlined here. No production code
-- reads/writes this table yet; it is WIRED by a later, flag-gated milestone.
--
-- concept_uuid is a LOOSE reference (no FK): canonical_concepts is itself dormant/empty today, and the
-- minted UUID is the KC_ concept's stable ERP-namespace handle (deterministic uuid5 — see vocabulary.py),
-- not a pointer to an existing row. A later milestone may seed canonical_concepts with these exact UUIDs.
--
-- Governance: the certified edu_* platform-read catalogue shape (FORCE RLS + _school_scope FOR ALL +
-- _platform_read FOR SELECT on org NULL + narrow no-DELETE grant + COALESCE identity index), identical to
-- canonical_concepts / edu_item_rotation_policies. Platform rows (organization_id NULL) are the global
-- crosswalk, readable by every school tenant, writable only by the platform service role (RLS bypass).
--
-- Reversibility (additive + dormant ⇒ safe; nothing reads it). Owner-gated DOWN:
--   DROP TABLE IF EXISTS edu_concept_vocabulary;

CREATE TABLE edu_concept_vocabulary (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id UUID REFERENCES organizations (id),   -- NULL = platform/global crosswalk; else school-custom
  school_id UUID REFERENCES schools (id),               -- NULL for platform rows
  kc_id TEXT NOT NULL,                                   -- QIE concept id: KC_<sha14>
  concept_uuid UUID NOT NULL,                            -- deterministic uuid5 handle (never a guess); loose ref
  subject TEXT,
  canonical_name TEXT,
  frozen_version TEXT,                                   -- frozen index version this row was derived from
  created_by UUID,
  created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now())
);

-- One crosswalk row per (scope, kc_id); platform rows collapse org/school → zero-uuid so kc_id is unique
-- among the global crosswalk (the R5-3 D2 "kc_id UNIQUE" intent, RLS-scope-aware).
CREATE UNIQUE INDEX edu_concept_vocabulary_identity
  ON edu_concept_vocabulary (
    COALESCE(organization_id, '00000000-0000-0000-0000-000000000000'::uuid),
    COALESCE(school_id, '00000000-0000-0000-0000-000000000000'::uuid),
    COALESCE(kc_id, '')
  );
CREATE INDEX edu_concept_vocabulary_concept_uuid ON edu_concept_vocabulary (concept_uuid);

ALTER TABLE edu_concept_vocabulary ENABLE ROW LEVEL SECURITY;
ALTER TABLE edu_concept_vocabulary FORCE ROW LEVEL SECURITY;

-- A school's own custom rows: read + write.
CREATE POLICY edu_concept_vocabulary_school_scope ON edu_concept_vocabulary
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

-- Platform rows (organization_id NULL): READABLE by every school tenant; writable only by the service role
-- (RLS bypass) — there is deliberately NO platform-write policy.
CREATE POLICY edu_concept_vocabulary_platform_read ON edu_concept_vocabulary
  FOR SELECT
  USING (
    organization_id IS NULL
    AND app_current_scope() = 'school'
  );

GRANT SELECT, INSERT, UPDATE ON edu_concept_vocabulary TO erp_tenant;  -- no DELETE: retire, never delete
