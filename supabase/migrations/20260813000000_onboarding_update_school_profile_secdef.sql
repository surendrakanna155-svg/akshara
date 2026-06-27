-- Onboarding & Dynamic Config cert · G-fix — startup go-live could not persist
-- the school profile because the edge `erp_tenant` role has SELECT-only on the
-- core `schools` table (RLS-protected, no UPDATE grant). Startup go-live's
-- `updateSchoolProfile` (name + onboarding settings snapshot) therefore 500'd
-- with "permission denied for table schools" — a latent bug, since B7 only ever
-- certified the propose-only ai-prefill, not a real go-live.
--
-- Same remedy the codebase already uses for `erp_tenant`-restricted writes
-- (cf. org_builder_provision_tenant, onboarding_ensure_school_membership): a
-- SECURITY DEFINER function, owned by the migration role, that performs the
-- scoped UPDATE and is the ONLY thing granted to erp_tenant. It self-enforces
-- org⇄school scope, so the definer privilege cannot be used to touch another
-- tenant's school.

CREATE OR REPLACE FUNCTION onboarding_update_school_profile(
  p_org      uuid,
  p_school   uuid,
  p_name     text,
  p_settings jsonb
) RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_updated integer := 0;
BEGIN
  IF p_org IS NULL OR p_school IS NULL THEN
    RAISE EXCEPTION 'organization and school id are required' USING ERRCODE = 'check_violation';
  END IF;

  -- Scope guard: the school must belong to the caller's organization and be live.
  UPDATE schools SET
    name       = COALESCE(NULLIF(btrim(p_name), ''), name),
    settings   = COALESCE(settings, '{}'::jsonb) || COALESCE(p_settings, '{}'::jsonb),
    updated_at = timezone('utc', now())
  WHERE id = p_school
    AND organization_id = p_org
    AND deleted_at IS NULL;

  GET DIAGNOSTICS v_updated = ROW_COUNT;
  RETURN v_updated > 0;
END;
$$;

REVOKE ALL ON FUNCTION onboarding_update_school_profile(uuid, uuid, text, jsonb) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION onboarding_update_school_profile(uuid, uuid, text, jsonb) TO erp_tenant;
