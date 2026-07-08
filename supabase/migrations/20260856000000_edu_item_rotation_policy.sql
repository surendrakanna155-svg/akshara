-- CI-C8 (Curriculum Intelligence) — item ROTATION-COOLDOWN policy config
-- (v3.0 §10.1 "rotation cooldowns become enforceable" / Phase-1 item 1.9
-- "Usage/exposure columns + rotation cooldown"). DORMANT additive schema: this
-- migration CREATES the config table only — ZERO data seed, no code writes/reads
-- it in production yet, no VPS/import wiring. It exists so the CI-C8 rotation
-- helper has a governed shape to read once real policies are configured (a later,
-- owner-gated wave). Changes NO existing behaviour: with no policy supplied,
-- paper generation is byte-identical to the certified path (invariant I1).
--
-- WHY A SEPARATE TABLE (not more columns): the E1a dormant seed
-- (20260853000000) already landed the exposure DATA — `edu_item_exposures`
-- (the usage log) + `times_used`/`last_used_at` counters on the bank. What that
-- seed did NOT provide is the POLICY that turns those signals into a rotation
-- decision (how long to rest an item, how many reuses cap it, whether to soft-
-- deprioritise recently-used items). That policy is per-scope config, not per-
-- item data, so it lives here. This migration is additive-only and never
-- recreates or alters the E1a exposure objects.
--
-- A policy is EITHER platform/official (organization_id NULL — authored by the
-- platform team via the service role) OR school-custom (organization_id +
-- school_id set — a school's own tuning). Same certified edu_* governance as
-- edu_exam_profiles / edu_blueprint_templates: FORCE RLS + narrow erp_tenant
-- grants; platform rows are read-only to tenants (subject_templates read-
-- catalogue pattern — invariant I7). Additive-only, nullable FKs, no triggers on
-- certified tables, no destructive change.

CREATE TABLE edu_item_rotation_policies (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id UUID REFERENCES organizations (id),   -- NULL = platform/official; else school-custom
  school_id UUID REFERENCES schools (id),               -- NULL for platform rows

  -- Identity / classification. policy_code is the essential key, e.g.
  -- 'default','formal_exam','practice','competitive'.
  policy_code TEXT NOT NULL,
  title TEXT,
  description TEXT,

  -- Scope binding (independently configurable — mirrors edu_exam_profiles). All
  -- nullable so a policy can be broad (school-wide) or narrow (one subject/track).
  board_code TEXT,
  class_label TEXT,
  subject_name TEXT,
  program_track TEXT NOT NULL DEFAULT 'board',           -- aligns to the edu program_track enum
  exam_type TEXT,                                         -- optional: rest items harder for formal exams

  -- Rotation config ─────────────────────────────────────────────────────────
  -- HARD exclusion — an item last used within this many days of the generation
  -- reference instant is skipped (rested). 0 / NULL = no time cooldown.
  cooldown_days INTEGER,
  -- HARD exclusion — an item whose times_used has reached this cap is skipped.
  -- 0 / NULL = uncapped reuse.
  max_times_used INTEGER,
  -- SOFT rotation — when true, remaining eligible items are ordered least-used /
  -- least-recently-used first so the solver's bank-first walk naturally rotates
  -- through the bank instead of always re-picking the same items. When false,
  -- only the hard cooldowns above apply and order is left canonical.
  deprioritize_recent BOOLEAN NOT NULL DEFAULT true,

  -- Lifecycle (archive, never overwrite — mirrors edu_exam_profiles).
  status TEXT NOT NULL DEFAULT 'draft'
    CHECK (status IN ('draft', 'active', 'archived')),
  created_by UUID,
  created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now())
);

-- One policy per (scope, policy code, board, class, subject, track, exam type).
-- COALESCE keeps the key well-defined across the NULLable tenant/scope columns
-- (NULL org groups all platform rows together). Mirrors edu_exam_profiles_identity.
CREATE UNIQUE INDEX edu_item_rotation_policies_identity
  ON edu_item_rotation_policies (
    COALESCE(organization_id, '00000000-0000-0000-0000-000000000000'::uuid),
    COALESCE(school_id, '00000000-0000-0000-0000-000000000000'::uuid),
    COALESCE(policy_code, ''),
    COALESCE(board_code, ''),
    COALESCE(class_label, ''),
    COALESCE(subject_name, ''),
    COALESCE(program_track, ''),
    COALESCE(exam_type, '')
  );

ALTER TABLE edu_item_rotation_policies ENABLE ROW LEVEL SECURITY;
ALTER TABLE edu_item_rotation_policies FORCE ROW LEVEL SECURITY;

-- School-custom rows: the certified edu_* _school_scope shape (org + school bound
-- to the caller's tenant). Governs SELECT/INSERT/UPDATE of a school's OWN policies.
CREATE POLICY edu_item_rotation_policies_school_scope ON edu_item_rotation_policies
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
CREATE POLICY edu_item_rotation_policies_platform_read ON edu_item_rotation_policies
  FOR SELECT
  USING (
    organization_id IS NULL
    AND app_current_scope() = 'school'
  );

-- Schools read platform + own rows, and create/customize their own (archive, not
-- delete — lifecycle semantics). No DELETE grant.
GRANT SELECT, INSERT, UPDATE ON edu_item_rotation_policies TO erp_tenant;
