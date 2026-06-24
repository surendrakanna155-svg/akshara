-- B2 — Step 4.5 · SuperAdmin organization plan assignment (SECURITY DEFINER).
--
-- The edge runs as the non-bypass `erp_tenant` role. The Step-1 RLS on
-- organization_subscriptions only lets an org write its OWN row (scope =
-- 'organization', organization_id = current tenant). Platform plan assignment is
-- a cross-organization operation (a superAdmin sets ANY org's plan), so it cannot
-- go through that policy. Mirror the established privileged-op pattern
-- (onboarding_rollback_student): SECURITY DEFINER functions owned by the migration
-- role, with EXECUTE granted only to erp_tenant. The tenant role gains NO new
-- table rights; these two audited functions are the only cross-org path, and the
-- edge gates them on the `managePlatformSubscriptions` permission (superAdmin).
--
-- Scope (locked): entitlement assignment only — NO billing/payments/renewals/
-- invoices/MRR/addons/white-label. `assign` flips plan + status; never deletes.
-- Additive + idempotent (CREATE OR REPLACE).

-- ─── Assign (upsert) an organization's subscription plan ─────────────────────
CREATE OR REPLACE FUNCTION assign_organization_subscription(
  p_organization_id uuid,
  p_plan_slug       text,
  p_status          text,
  p_actor           uuid
) RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_len  integer;
  v_grc  integer;
  v_is_trial boolean;
BEGIN
  -- Validate the plan exists and is active (data-driven catalog).
  SELECT COALESCE(trial_length_days, 30), COALESCE(trial_grace_days, 0),
         (slug = 'trial')
    INTO v_len, v_grc, v_is_trial
  FROM subscription_plans
  WHERE slug = p_plan_slug AND is_active = true;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Unknown or inactive plan: %', p_plan_slug
      USING ERRCODE = 'foreign_key_violation';
  END IF;

  IF p_status NOT IN ('trial', 'active', 'grace', 'suspended') THEN
    RAISE EXCEPTION 'Invalid subscription status: %', p_status
      USING ERRCODE = 'check_violation';
  END IF;

  INSERT INTO organization_subscriptions
    (organization_id, plan_slug, status, trial_ends_at, grace_ends_at,
     started_at, assigned_by)
  VALUES
    (p_organization_id, p_plan_slug, p_status,
     CASE WHEN p_status = 'trial'
          THEN timezone('utc', now()) + make_interval(days => v_len) END,
     CASE WHEN p_status = 'trial'
          THEN timezone('utc', now()) + make_interval(days => v_len + v_grc) END,
     timezone('utc', now()), p_actor)
  ON CONFLICT (organization_id) DO UPDATE SET
    plan_slug     = EXCLUDED.plan_slug,
    status        = EXCLUDED.status,
    trial_ends_at = EXCLUDED.trial_ends_at,
    grace_ends_at = EXCLUDED.grace_ends_at,
    assigned_by   = EXCLUDED.assigned_by;
END;
$$;

REVOKE ALL ON FUNCTION assign_organization_subscription(uuid, text, text, uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION assign_organization_subscription(uuid, text, text, uuid) TO erp_tenant;

-- ─── List every organization with its current plan (for the assign screen) ───
CREATE OR REPLACE FUNCTION list_subscription_assignments()
  RETURNS TABLE (
    organization_id   uuid,
    organization_name text,
    organization_slug text,
    plan_slug         text,
    status            text
  )
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT o.id, o.name, o.slug,
         COALESCE(os.plan_slug, 'trial'),
         COALESCE(os.status, 'trial')
  FROM organizations o
  LEFT JOIN organization_subscriptions os ON os.organization_id = o.id
  WHERE o.deleted_at IS NULL
  ORDER BY o.name;
$$;

REVOKE ALL ON FUNCTION list_subscription_assignments() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION list_subscription_assignments() TO erp_tenant;
