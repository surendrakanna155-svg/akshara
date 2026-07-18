-- PRA-P2-34 (S2) — make the RBAC-freshness check enforceable at runtime.
--
-- Evidence: session_validation.ts:69 rejects a token whose permissions_version no
-- longer matches the live membership (code PERMISSIONS_STALE), but the ONLY place
-- permissions_version was ever bumped was the one-off migration 20260627110000.
-- No trigger existed, so at runtime a role/override change never bumped the
-- counter and PERMISSIONS_STALE could never fire — the freshness gate was inert.
--
-- Fix: bump school_memberships.permissions_version (or organization_memberships
-- for org-scoped overrides) whenever a user's EFFECTIVE permissions change, i.e.
-- AFTER INSERT/UPDATE/DELETE on the two tables that drive resolution:
--   • school_membership_roles      (role added / removed / suspended)
--   • membership_permission_overrides (per-user grant / deny / revoke)
-- A bumped counter forces the affected session's next request to fail the
-- freshness check → refresh → re-resolve current permissions.

-- One function serves BOTH trigger tables. Their columns differ
-- (school_membership_roles has only school_membership_id;
-- membership_permission_overrides has school_membership_id XOR
-- organization_membership_id), so we read the keys defensively via to_jsonb()
-- rather than binding column names at compile time — a missing key simply
-- resolves to NULL and is skipped. SECURITY DEFINER so the bump succeeds
-- regardless of the writer's grants on the *_memberships tables.
CREATE OR REPLACE FUNCTION bump_permissions_version()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_new jsonb := CASE WHEN TG_OP = 'DELETE' THEN NULL ELSE to_jsonb(NEW) END;
  v_old jsonb := CASE WHEN TG_OP = 'INSERT' THEN NULL ELSE to_jsonb(OLD) END;
  v_smid uuid;
  v_omid uuid;
BEGIN
  -- School memberships touched by NEW and/or OLD (OLD covers DELETE and the rare
  -- UPDATE that re-points a row to a different membership). Both trigger tables
  -- expose school_membership_id.
  FOR v_smid IN
    SELECT DISTINCT x
    FROM (VALUES
      ((v_new->>'school_membership_id')::uuid),
      ((v_old->>'school_membership_id')::uuid)
    ) AS t(x)
    WHERE x IS NOT NULL
  LOOP
    UPDATE school_memberships
       SET permissions_version = permissions_version + 1
     WHERE id = v_smid;
  END LOOP;

  -- Organization memberships (only membership_permission_overrides carries this
  -- key; for school_membership_roles the key is absent → NULL → skipped).
  FOR v_omid IN
    SELECT DISTINCT x
    FROM (VALUES
      ((v_new->>'organization_membership_id')::uuid),
      ((v_old->>'organization_membership_id')::uuid)
    ) AS t(x)
    WHERE x IS NOT NULL
  LOOP
    UPDATE organization_memberships
       SET permissions_version = permissions_version + 1
     WHERE id = v_omid;
  END LOOP;

  -- AFTER trigger: return value is ignored. No recursion risk — the function
  -- writes ONLY *_memberships.permissions_version, and neither of those tables
  -- has a trigger that writes back to school_membership_roles or
  -- membership_permission_overrides, so no cycle can form.
  RETURN NULL;
END;
$$;

DROP TRIGGER IF EXISTS trg_bump_permissions_version_roles ON school_membership_roles;
CREATE TRIGGER trg_bump_permissions_version_roles
  AFTER INSERT OR UPDATE OR DELETE ON school_membership_roles
  FOR EACH ROW
  EXECUTE FUNCTION bump_permissions_version();

DROP TRIGGER IF EXISTS trg_bump_permissions_version_overrides ON membership_permission_overrides;
CREATE TRIGGER trg_bump_permissions_version_overrides
  AFTER INSERT OR UPDATE OR DELETE ON membership_permission_overrides
  FOR EACH ROW
  EXECUTE FUNCTION bump_permissions_version();
