-- Journey Wave 4 · OB-1 — Organization Builder REAL provisioning (SECURITY DEFINER)
--
-- Before this migration, provision() in organization_builder_repository.ts only
-- INSERTed an org_builder_provisioning_jobs row whose status was hardcoded
-- 'completed' with six fabricated 'completed' steps. NO real tenant rows were
-- ever created — the Flutter UI claimed "Organization provisioned successfully"
-- while nothing existed. This closes that documented stub: provisioning now
-- creates the REAL tenant rows the six steps claim, inside ONE atomic call,
-- idempotently, and the job records each step's ACTUAL outcome.
--
-- Why SECURITY DEFINER: provisioning stands up a NEW organization (a child of the
-- calling chain/trust). The edge runs as the non-bypass `erp_tenant` role under
-- org-scope RLS keyed to the CALLER's tenant_id; it cannot INSERT a row into
-- `organizations` for a DIFFERENT (new) tenant, nor write the global RBAC catalog
-- (role_definitions / role_permissions). This is exactly the established
-- privileged-op pattern (assign_organization_subscription,
-- onboarding_rollback_student): a SECURITY DEFINER function owned by the migration
-- role, EXECUTE granted only to erp_tenant. The tenant role gains NO new table
-- rights; this one audited, draft-scoped function is the only path that creates a
-- child organization, and the edge gates it on manageOrganizationBuilder +
-- org scope + the feature.organization_builder entitlement (Enterprise).
--
-- Atomicity / rollback: the function is a single plpgsql call, so it executes
-- inside the caller's open transaction as ONE statement — if any step RAISEs, the
-- whole function's writes (org/school/roles/permissions/golive) are unwound by
-- Postgres before control returns. provision() catches that, records a 'failed'
-- job (in a SEPARATE, committed write) describing which step failed, and never
-- flips the draft to 'provisioned'. Tenant rows are therefore all-or-nothing.
--
-- Idempotency: re-running a provision for the same draft must NOT duplicate the
-- organization or its branch. The new org is marked with
-- settings->>'org_builder_draft_id' = <draftId>; the function reuses that org if
-- it already exists, and the branch is guarded by schools' (organization_id, code)
-- unique key. role_definitions / role_permissions / membership upserts all use
-- ON CONFLICT DO NOTHING. Forward-only; INSERT/UPDATE only (never DELETE).

-- ─── Pack → role/permission blueprint (reference data, data-driven steps) ─────
-- The provisioning role/permission steps seed REAL rows ONLY from this catalog —
-- they never invent roles or permissions. School roles already exist in the RBAC
-- foundation (principal/teacher/parent); non-school verticals get system roles
-- seeded here so their provisioning grants real, FK-valid permissions.

CREATE TABLE IF NOT EXISTS org_builder_pack_roles (
  pack_id         TEXT NOT NULL REFERENCES org_builder_packs (id),
  role_slug       TEXT NOT NULL,
  display_name    TEXT NOT NULL,
  role_scope      TEXT NOT NULL DEFAULT 'school'
    CHECK (role_scope IN ('organization', 'school', 'school_group', 'self', 'platform')),
  permission_slugs TEXT[] NOT NULL DEFAULT '{}',
  sort_order      INTEGER NOT NULL DEFAULT 0,
  PRIMARY KEY (pack_id, role_slug)
);

ALTER TABLE org_builder_pack_roles ENABLE ROW LEVEL SECURITY;
ALTER TABLE org_builder_pack_roles FORCE ROW LEVEL SECURITY;

-- Catalog: any org-scope caller may read (mirrors org_builder_packs).
CREATE POLICY org_builder_pack_roles_org_read ON org_builder_pack_roles
  FOR SELECT USING (
    app_current_scope() IN ('organization', 'school_group', 'platform')
  );

GRANT SELECT ON org_builder_pack_roles TO erp_tenant;

-- Blueprint. School roles reuse the real RBAC slugs (principal/teacher/parent) so
-- the grants land on the EXISTING system roles. Vertical roles use namespaced
-- slugs (no collision with school RBAC) and a baseline of EXISTING permission
-- slugs valid in permission_definitions.
INSERT INTO org_builder_pack_roles (pack_id, role_slug, display_name, role_scope, permission_slugs, sort_order) VALUES
  ('pack_school', 'principal', 'Principal', 'school',
   ARRAY['viewManagement','manageManagement','viewSis','manageSis','viewFinance','viewHr'], 0),
  ('pack_school', 'teacher', 'Teacher', 'school',
   ARRAY['viewSis','viewManagement'], 1),
  ('pack_school', 'parent', 'Parent', 'self',
   ARRAY[]::text[], 2),

  ('pack_salon', 'salonManager', 'Salon Manager', 'school',
   ARRAY['viewManagement','manageManagement','viewInventory','manageInventory','viewHr','manageHr'], 0),
  ('pack_salon', 'salonStylist', 'Stylist', 'school',
   ARRAY['viewManagement'], 1),
  ('pack_salon', 'salonReception', 'Reception', 'school',
   ARRAY['viewManagement','viewInventory'], 2),

  ('pack_hospital', 'hospitalAdmin', 'Hospital Admin', 'school',
   ARRAY['viewManagement','manageManagement','viewFinance','manageFinance','viewInventory','manageInventory','viewHr','manageHr'], 0),
  ('pack_hospital', 'hospitalDoctor', 'Doctor', 'school',
   ARRAY['viewManagement','viewInventory'], 1),
  ('pack_hospital', 'hospitalNurse', 'Nurse', 'school',
   ARRAY['viewManagement'], 2),

  ('pack_restaurant', 'restaurantManager', 'Restaurant Manager', 'school',
   ARRAY['viewManagement','manageManagement','viewInventory','manageInventory','viewHr'], 0),
  ('pack_restaurant', 'restaurantChef', 'Chef', 'school',
   ARRAY['viewInventory','manageInventory'], 1),
  ('pack_restaurant', 'restaurantServer', 'Server', 'school',
   ARRAY['viewManagement'], 2)
ON CONFLICT (pack_id, role_slug) DO NOTHING;

-- Seed the vertical (non-school) roles into the real RBAC catalog so the
-- provisioning grants reference FK-valid role_definitions rows. School roles
-- already exist from the RBAC foundation; the ON CONFLICT keeps this idempotent.
INSERT INTO role_definitions (slug, display_name, scope, is_system)
SELECT DISTINCT pr.role_slug, pr.display_name, pr.role_scope, true
FROM org_builder_pack_roles pr
ON CONFLICT (slug) DO NOTHING;

-- ─── Real provisioning function ──────────────────────────────────────────────
-- Creates (or reuses) the child organization + its branch, seeds the pack's roles
-- and permission grants, optionally seeds baseline rows the pack defines, and
-- takes the org live. Returns honest per-resource counts so the caller can record
-- a job whose step statuses reflect work actually done. ALL writes are
-- INSERT/UPDATE-only and idempotent. If anything is invalid it RAISEs, and the
-- caller's transaction unwinds every write made here.

CREATE OR REPLACE FUNCTION org_builder_provision_tenant(
  p_parent_org_id  uuid,   -- the calling chain/trust org (RLS tenant of the caller)
  p_draft_id       text,   -- draft this provision belongs to (idempotency marker)
  p_pack_id        text,
  p_org_name       text,
  p_actor          uuid
) RETURNS TABLE (
  new_org_id       uuid,
  new_school_id    uuid,
  roles_seeded     integer,
  permissions_granted integer,
  seeds_loaded     integer,
  reused           boolean,
  failed_step      text,
  error_message    text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_org_id     uuid;
  v_school_id  uuid;
  v_slug       text;
  v_base_slug  text;
  v_n          integer := 0;
  v_reused     boolean := false;
  v_roles      integer := 0;
  v_perms      integer := 0;
  v_seeds      integer := 0;
  v_code       text;
  v_step       text := 'step_org';
  r            record;
  p            text;
BEGIN
  -- The whole real-provisioning body runs inside an inner block whose EXCEPTION
  -- handler creates an implicit savepoint: if ANY step raises, every write made
  -- here is rolled back to function entry, but the OUTER transaction stays usable
  -- so the caller can still COMMIT a 'failed' job row. We surface WHICH step
  -- failed (v_step) + the error text as DATA — we do not re-raise — precisely so
  -- the partial work is undone yet the failure is durably recorded by the caller.
  BEGIN
    -- Validate inputs.
    IF p_parent_org_id IS NULL THEN
      RAISE EXCEPTION 'parent organization id is required' USING ERRCODE = 'check_violation';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM org_builder_packs WHERE id = p_pack_id) THEN
      RAISE EXCEPTION 'Unknown vertical pack: %', p_pack_id USING ERRCODE = 'foreign_key_violation';
    END IF;
    IF COALESCE(btrim(p_org_name), '') = '' THEN
      RAISE EXCEPTION 'organization name is required' USING ERRCODE = 'check_violation';
    END IF;

  -- ── step_org: create OR reuse the child organization (idempotent by draft) ──
  v_step := 'step_org';
  SELECT id INTO v_org_id
  FROM organizations
  WHERE settings->>'org_builder_draft_id' = p_draft_id
    AND settings->>'parent_organization_id' = p_parent_org_id::text
  LIMIT 1;

  IF v_org_id IS NULL THEN
    -- Derive a unique slug from the org name; append a numeric suffix on collision.
    v_base_slug := regexp_replace(lower(btrim(p_org_name)), '[^a-z0-9]+', '-', 'g');
    v_base_slug := btrim(v_base_slug, '-');
    IF v_base_slug = '' THEN v_base_slug := 'org'; END IF;
    v_slug := v_base_slug;
    v_n := 1;
    WHILE EXISTS (SELECT 1 FROM organizations WHERE slug = v_slug) LOOP
      v_n := v_n + 1;
      v_slug := v_base_slug || '-' || v_n::text;
    END LOOP;

    INSERT INTO organizations (name, slug, plan, status, settings)
    VALUES (
      p_org_name, v_slug, 'trial', 'trial',
      jsonb_build_object(
        'org_builder_draft_id', p_draft_id,
        'parent_organization_id', p_parent_org_id::text,
        'vertical_pack_id', p_pack_id,
        'provisioned_by', COALESCE(p_actor::text, '')
      )
    )
    RETURNING id INTO v_org_id;
  ELSE
    v_reused := true;
  END IF;

  -- ── step_branch: create OR reuse the primary branch (idempotent by code) ────
  v_step := 'step_branch';
  v_code := 'MAIN';
  SELECT id INTO v_school_id
  FROM schools
  WHERE organization_id = v_org_id AND code = v_code;

  IF v_school_id IS NULL THEN
    INSERT INTO schools (organization_id, name, code, settings)
    VALUES (
      v_org_id,
      p_org_name || ' — Main Branch',
      v_code,
      jsonb_build_object('org_builder_draft_id', p_draft_id, 'is_primary', true)
    )
    RETURNING id INTO v_school_id;
  END IF;

  -- ── step_roles: seed the pack's roles into the real RBAC catalog ────────────
  -- (Vertical roles were catalog-seeded in this migration; this re-asserts them
  --  idempotently and counts how many the pack actually defines.)
  v_step := 'step_roles';
  FOR r IN
    SELECT role_slug, display_name, role_scope
    FROM org_builder_pack_roles
    WHERE pack_id = p_pack_id
    ORDER BY sort_order
  LOOP
    INSERT INTO role_definitions (slug, display_name, scope, is_system)
    VALUES (r.role_slug, r.display_name, r.role_scope, true)
    ON CONFLICT (slug) DO NOTHING;
    v_roles := v_roles + 1;
  END LOOP;

  -- ── step_permissions: grant the pack's permissions to those roles ───────────
  v_step := 'step_permissions';
  FOR r IN
    SELECT role_slug, permission_slugs
    FROM org_builder_pack_roles
    WHERE pack_id = p_pack_id
  LOOP
    FOREACH p IN ARRAY r.permission_slugs LOOP
      -- Only grant permissions that really exist (FK-safe, idempotent).
      INSERT INTO role_permissions (role_slug, permission_slug)
      SELECT r.role_slug, p
      WHERE EXISTS (SELECT 1 FROM permission_definitions WHERE slug = p)
      ON CONFLICT (role_slug, permission_slug) DO NOTHING;
      IF FOUND THEN
        v_perms := v_perms + 1;
      END IF;
    END LOOP;
  END LOOP;

  -- ── step_seeds: seed baseline rows the pack defines ─────────────────────────
  -- The current packs declare primary ENTITIES (Students/Clients/…) but NO
  -- concrete baseline rows, so there is nothing to seed yet. We intentionally
  -- create zero rows here rather than invent data; the count is honest (0) and
  -- the step is genuinely complete. (When a pack later ships baseline seed rows,
  -- they belong here, scoped to v_org_id/v_school_id.)
  v_step := 'step_seeds';
  v_seeds := 0;

  -- ── step_golive: take the new org live ──────────────────────────────────────
  v_step := 'step_golive';
  UPDATE organizations
  SET status = 'active', updated_at = timezone('utc', now())
  WHERE id = v_org_id AND status <> 'active';

  -- Give the provisioning actor an org-admin membership on the new org so the
  -- freshly-created tenant is reachable (idempotent).
  IF p_actor IS NOT NULL THEN
    INSERT INTO organization_memberships
      (user_id, organization_id, role, status, permissions_version)
    VALUES (p_actor, v_org_id, 'organizationAdmin', 'active', 1)
    ON CONFLICT (user_id, organization_id) DO NOTHING;
  END IF;

    new_org_id := v_org_id;
    new_school_id := v_school_id;
    roles_seeded := v_roles;
    permissions_granted := v_perms;
    seeds_loaded := v_seeds;
    reused := v_reused;
    failed_step := NULL;
    error_message := NULL;
    RETURN NEXT;

  EXCEPTION WHEN OTHERS THEN
    -- Any failure: the inner block's implicit savepoint rolls back every write
    -- above (org/school/roles/permissions/golive). Report the failing step +
    -- message as DATA so the caller records a durable 'failed' job. The outer
    -- transaction remains valid and committable.
    new_org_id := NULL;
    new_school_id := NULL;
    roles_seeded := 0;
    permissions_granted := 0;
    seeds_loaded := 0;
    reused := false;
    failed_step := v_step;
    error_message := SQLERRM;
    RETURN NEXT;
  END;
END;
$$;

REVOKE ALL ON FUNCTION org_builder_provision_tenant(uuid, text, text, text, uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION org_builder_provision_tenant(uuid, text, text, text, uuid) TO erp_tenant;
