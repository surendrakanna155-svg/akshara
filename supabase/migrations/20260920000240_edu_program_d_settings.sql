-- Program D · M3.1 / M3.3 — edu_program_d_settings per-tenant flag store.
-- DORMANT, additive, owner-gated apply.
--
-- Contract-2 §2.4 (docs/roadmap/PROGRAM_D_CONTRACTS.md) is normative. One row per
-- (organization_id, school_id). The two flags default to EXACT current production
-- behaviour so Program D stays DARK until an owner flips a flag per tenant:
--   * certified_pool_enabled  (M3.1) — default FALSE: do NOT read the union pool
--     (edu_bank_items_union). Today's behaviour = own bank only. Owner flips to TRUE.
--   * gap_fill_policy          (M3.3) — default 'marked_unpublishable': today's behaviour
--     (a paper with an unfillable slot is produced but marked unpublishable). Owner flips
--     to 'hard_off' to instead refuse the slot outright.
--
-- DORMANT: CREATE-only, ZERO data seed (absence of a row = both defaults, i.e. exact
-- current behaviour — the read path COALESCEs a missing row to the defaults; never
-- backfilled here), ZERO wiring. No production code reads this table yet.
--
-- Governance: this is a TENANT-OWNED settings table (never a platform catalogue), so it
-- carries school-scope RLS ONLY (FORCE RLS + _school_scope FOR ALL) — deliberately NO
-- _platform_read policy. Narrow GRANT SELECT, INSERT, UPDATE (no DELETE — a tenant edits
-- its flags, never deletes the row). The natural key (organization_id, school_id) is the
-- PRIMARY KEY (both columns NOT NULL ⇒ no COALESCE needed).
--
-- Reversibility (additive + dormant ⇒ safe). Owner-gated DOWN:
--   DROP TABLE IF EXISTS edu_program_d_settings;

CREATE TABLE edu_program_d_settings (
  organization_id UUID NOT NULL REFERENCES organizations (id),  -- tenant
  school_id UUID NOT NULL REFERENCES schools (id),
  certified_pool_enabled BOOLEAN NOT NULL DEFAULT false,        -- M3.1: default OFF = exact current behaviour
  gap_fill_policy TEXT NOT NULL DEFAULT 'marked_unpublishable'
    CHECK (gap_fill_policy IN ('marked_unpublishable', 'hard_off')),  -- M3.3: default = today's behaviour
  created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),
  PRIMARY KEY (organization_id, school_id)                      -- one row per tenant-school (PK = UNIQUE)
);

ALTER TABLE edu_program_d_settings ENABLE ROW LEVEL SECURITY;
ALTER TABLE edu_program_d_settings FORCE ROW LEVEL SECURITY;

CREATE POLICY edu_program_d_settings_school_scope ON edu_program_d_settings
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

GRANT SELECT, INSERT, UPDATE ON edu_program_d_settings TO erp_tenant;  -- no DELETE: edit flags, never delete the row
