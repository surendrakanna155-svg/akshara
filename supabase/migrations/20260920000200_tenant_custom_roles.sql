-- ICA-G3 — Tenant-specific custom roles & permissions.
--
-- OWNER DECISION (G3): "Support tenant-specific custom roles and permissions.
-- Built-in system roles must remain immutable and protected, while schools may
-- create and manage their own custom roles within the RBAC framework."
--
-- BEFORE (RBAC foundation, 20260608100000): `role_definitions` was keyed by
-- `slug` alone — one GLOBAL catalog with `is_system` but NO org/tenant column.
-- `role_permissions`, `school_membership_roles.role_slug` and
-- `organization_membership_roles.role_slug` all FK to that global slug. There was
-- nowhere to hold a per-tenant custom role.
--
-- DESIGN (additive, integrity-preserving):
--   * `role_definitions.slug` REMAINS the PRIMARY KEY (a single global namespace).
--     Every existing FK keeps resolving unchanged, and — because a slug is
--     globally unique — a tenant custom slug can NEVER collide with (shadow) a
--     system slug. Custom slugs are app-generated as `custom_<org>_<name>`, so
--     they are structurally disjoint from the camelCase system slugs.
--   * A nullable `organization_id` is added to `role_definitions` and
--     `role_permissions`: NULL = system-global built-in (is_system=true); non-NULL
--     = a tenant's own custom role (is_system=false). Every pre-existing row is a
--     system role and backfills to NULL.
--   * Per-org uniqueness of the custom namespace is enforced explicitly
--     (partial unique indexes) on top of the global-unique guarantee.
--   * The membership -> role reference cannot be a hard COMPOSITE FK: the owner
--     mandates NULL org for system rows, and a MATCH SIMPLE composite FK does NOT
--     enforce the NULL-org branch (any NULL column satisfies it), while the
--     membership tables carry no org column. So the "a membership may hold a
--     custom role only from its OWN org" invariant is enforced by a HARD DB
--     TRIGGER (fires even under the service role) + an app check + a privileged
--     violation DETECTOR (ICA-E2/F5 posture). System roles (org NULL) always pass
--     -> existing system-role memberships are completely unaffected.
--   * IMMUTABILITY: system rows are read-only to the `erp_tenant` DB role via RLS
--     (a tenant may write ONLY its own org rows) AND rejected by the app writer.
--     The service-role resolution path is unchanged (service_role bypasses RLS).
--
-- Forward-only & idempotent (re-runnable per migration_rerunnability_guard_test).

-- ─── 1. org-scoping columns (NULL = system-global; non-NULL = tenant custom) ──

ALTER TABLE role_definitions
  ADD COLUMN IF NOT EXISTS organization_id UUID REFERENCES organizations (id) ON DELETE CASCADE;

ALTER TABLE role_permissions
  ADD COLUMN IF NOT EXISTS organization_id UUID REFERENCES organizations (id) ON DELETE CASCADE;

COMMENT ON COLUMN role_definitions.organization_id IS
  'NULL = system-global built-in role (immutable to tenants); non-NULL = a tenant custom role owned by that organization.';
COMMENT ON COLUMN role_permissions.organization_id IS
  'Derived (auto-synced by trigger) from the role: NULL for system-role grants, the owning org for a custom-role grant.';

-- Every pre-existing row is a system-global role. Column default is NULL, so this
-- is a no-op today; it also self-heals any manual drift and keeps grants in sync
-- with their role (idempotent).
UPDATE role_permissions rp
SET organization_id = rd.organization_id
FROM role_definitions rd
WHERE rp.role_slug = rd.slug
  AND rp.organization_id IS DISTINCT FROM rd.organization_id;

-- ─── 2. system/custom consistency invariant on role_definitions ──────────────

ALTER TABLE role_definitions DROP CONSTRAINT IF EXISTS role_definitions_system_org_chk;
ALTER TABLE role_definitions
  ADD CONSTRAINT role_definitions_system_org_chk
  CHECK (
    (organization_id IS NULL AND is_system = true)
    OR (organization_id IS NOT NULL AND is_system = false)
  );

-- ─── 3. uniqueness re-scope (custom namespace) ──────────────────────────────
-- slug stays the global PK (shadow-proof); these add the per-org guarantees.

CREATE UNIQUE INDEX IF NOT EXISTS role_definitions_org_slug_uq
  ON role_definitions (organization_id, slug) WHERE organization_id IS NOT NULL;

CREATE UNIQUE INDEX IF NOT EXISTS role_definitions_org_dispname_uq
  ON role_definitions (organization_id, lower(display_name)) WHERE organization_id IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_role_permissions_org
  ON role_permissions (organization_id) WHERE organization_id IS NOT NULL;

-- ─── 4. auto-sync role_permissions.organization_id from its role ────────────
-- Guarantees a custom role's grants carry the owning org and system-role grants
-- stay NULL — matching every historical INSERT that never set the column.

CREATE OR REPLACE FUNCTION app_sync_role_permission_org()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  SELECT rd.organization_id INTO NEW.organization_id
  FROM role_definitions rd
  WHERE rd.slug = NEW.role_slug;
  RETURN NEW;
END;
$$;

CREATE OR REPLACE TRIGGER role_permissions_org_sync
  BEFORE INSERT OR UPDATE ON role_permissions
  FOR EACH ROW EXECUTE FUNCTION app_sync_role_permission_org();

-- ─── 5. membership org-match invariant (custom role -> assignee's own org) ───
-- Hard invariant (fires even under the service role). System roles (org NULL)
-- always pass, so existing system-role memberships behave EXACTLY as before.

CREATE OR REPLACE FUNCTION app_enforce_membership_role_org()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_role_org UUID;
  v_mem_org UUID;
BEGIN
  SELECT rd.organization_id INTO v_role_org
  FROM role_definitions rd
  WHERE rd.slug = NEW.role_slug;

  -- System-global role: always assignable (no regression to existing behavior).
  IF v_role_org IS NULL THEN
    RETURN NEW;
  END IF;

  IF TG_TABLE_NAME = 'school_membership_roles' THEN
    SELECT s.organization_id INTO v_mem_org
    FROM school_memberships m
    JOIN schools s ON s.id = m.school_id
    WHERE m.id = NEW.school_membership_id;
  ELSIF TG_TABLE_NAME = 'organization_membership_roles' THEN
    SELECT om.organization_id INTO v_mem_org
    FROM organization_memberships om
    WHERE om.id = NEW.organization_membership_id;
  END IF;

  IF v_mem_org IS DISTINCT FROM v_role_org THEN
    RAISE EXCEPTION
      'custom role % (org %) cannot be assigned to a membership in org %',
      NEW.role_slug, v_role_org, v_mem_org
      USING ERRCODE = 'check_violation';
  END IF;

  RETURN NEW;
END;
$$;

CREATE OR REPLACE TRIGGER school_membership_roles_org_match
  BEFORE INSERT OR UPDATE ON school_membership_roles
  FOR EACH ROW EXECUTE FUNCTION app_enforce_membership_role_org();

CREATE OR REPLACE TRIGGER organization_membership_roles_org_match
  BEFORE INSERT OR UPDATE ON organization_membership_roles
  FOR EACH ROW EXECUTE FUNCTION app_enforce_membership_role_org();

-- ─── 6. RLS: catalog tables become tenant-aware ─────────────────────────────
-- System rows (org NULL) are READ-ONLY to erp_tenant; a tenant may write ONLY
-- its own org custom rows. ENABLE (not FORCE): the table owner (migrations) must
-- keep seeding system rows freely, and service_role bypasses RLS so the
-- resolution path is unchanged — the erp_tenant DB role is fully constrained.

ALTER TABLE role_definitions ENABLE ROW LEVEL SECURITY;
ALTER TABLE role_permissions ENABLE ROW LEVEL SECURITY;

GRANT SELECT, INSERT, UPDATE, DELETE ON role_definitions TO erp_tenant;
GRANT SELECT, INSERT, UPDATE, DELETE ON role_permissions TO erp_tenant;

-- role_definitions: read system + own; write own-org custom only (system read-only)
DROP POLICY IF EXISTS role_definitions_tenant_read ON role_definitions;
CREATE POLICY role_definitions_tenant_read ON role_definitions
  FOR SELECT
  USING (organization_id IS NULL OR organization_id = app_current_tenant_id());

DROP POLICY IF EXISTS role_definitions_tenant_insert ON role_definitions;
CREATE POLICY role_definitions_tenant_insert ON role_definitions
  FOR INSERT
  WITH CHECK (
    organization_id IS NOT NULL
    AND organization_id = app_current_tenant_id()
    AND is_system = false
  );

DROP POLICY IF EXISTS role_definitions_tenant_update ON role_definitions;
CREATE POLICY role_definitions_tenant_update ON role_definitions
  FOR UPDATE
  USING (organization_id = app_current_tenant_id() AND is_system = false)
  WITH CHECK (organization_id = app_current_tenant_id() AND is_system = false);

DROP POLICY IF EXISTS role_definitions_tenant_delete ON role_definitions;
CREATE POLICY role_definitions_tenant_delete ON role_definitions
  FOR DELETE
  USING (organization_id = app_current_tenant_id() AND is_system = false);

-- role_permissions: read system + own; write own-org only (org set by the sync
-- trigger — a tenant therefore cannot attach a grant to a system role).
DROP POLICY IF EXISTS role_permissions_tenant_read ON role_permissions;
CREATE POLICY role_permissions_tenant_read ON role_permissions
  FOR SELECT
  USING (organization_id IS NULL OR organization_id = app_current_tenant_id());

DROP POLICY IF EXISTS role_permissions_tenant_insert ON role_permissions;
CREATE POLICY role_permissions_tenant_insert ON role_permissions
  FOR INSERT
  WITH CHECK (organization_id = app_current_tenant_id());

DROP POLICY IF EXISTS role_permissions_tenant_update ON role_permissions;
CREATE POLICY role_permissions_tenant_update ON role_permissions
  FOR UPDATE
  USING (organization_id = app_current_tenant_id())
  WITH CHECK (organization_id = app_current_tenant_id());

DROP POLICY IF EXISTS role_permissions_tenant_delete ON role_permissions;
CREATE POLICY role_permissions_tenant_delete ON role_permissions
  FOR DELETE
  USING (organization_id = app_current_tenant_id());

-- ─── 7. violation detector (privileged; ICA-E2/F5 posture) ──────────────────
-- Proves the system/custom + org-match invariants hold in LIVE data. Defense in
-- depth beside the CHECK + the org-match trigger. Empty arrays = clean.

CREATE OR REPLACE FUNCTION app_detect_custom_role_violations()
RETURNS JSONB
LANGUAGE sql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
  SELECT jsonb_build_object(
    'role_definition_invariant', COALESCE((
      SELECT jsonb_agg(jsonb_build_object(
        'slug', slug, 'organization_id', organization_id, 'is_system', is_system))
      FROM role_definitions
      WHERE NOT (
        (organization_id IS NULL AND is_system = true)
        OR (organization_id IS NOT NULL AND is_system = false)
      )
    ), '[]'::jsonb),
    'role_permission_org_mismatch', COALESCE((
      SELECT jsonb_agg(jsonb_build_object(
        'role_slug', rp.role_slug, 'rp_org', rp.organization_id, 'role_org', rd.organization_id))
      FROM role_permissions rp
      JOIN role_definitions rd ON rd.slug = rp.role_slug
      WHERE rp.organization_id IS DISTINCT FROM rd.organization_id
    ), '[]'::jsonb),
    'school_membership_custom_role_org_mismatch', COALESCE((
      SELECT jsonb_agg(jsonb_build_object(
        'membership_id', smr.school_membership_id, 'role_slug', smr.role_slug))
      FROM school_membership_roles smr
      JOIN role_definitions rd ON rd.slug = smr.role_slug
      JOIN school_memberships m ON m.id = smr.school_membership_id
      JOIN schools s ON s.id = m.school_id
      WHERE rd.organization_id IS NOT NULL
        AND rd.organization_id IS DISTINCT FROM s.organization_id
    ), '[]'::jsonb),
    'org_membership_custom_role_org_mismatch', COALESCE((
      SELECT jsonb_agg(jsonb_build_object(
        'membership_id', omr.organization_membership_id, 'role_slug', omr.role_slug))
      FROM organization_membership_roles omr
      JOIN role_definitions rd ON rd.slug = omr.role_slug
      JOIN organization_memberships om ON om.id = omr.organization_membership_id
      WHERE rd.organization_id IS NOT NULL
        AND rd.organization_id IS DISTINCT FROM om.organization_id
    ), '[]'::jsonb)
  );
$$;

REVOKE ALL ON FUNCTION app_detect_custom_role_violations() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION app_detect_custom_role_violations() TO service_role;
