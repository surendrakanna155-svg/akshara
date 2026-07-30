-- ICA-B3 (P1, Security) — in-DB guardrails for the onboarding / subscription
-- SECURITY DEFINER functions.
--
-- These three functions run as SECURITY DEFINER (owner) granted to erp_tenant, so
-- they BYPASS RLS for their writes. They are safe TODAY only because their single
-- app-layer callers gate them with server-DERIVED ids (organizationIdFromClaims /
-- schoolIdFromClaims / auth.claims.sub) inside withTenantContext(). ICA-B3 adds
-- defense-in-depth: each function now RE-DERIVES its authorization boundary from
-- the request-context GUCs (app_current_tenant_id / app_current_school_id /
-- app_current_user_id set by app.set_request_context) and fails closed on any
-- cross-tenant / out-of-allowlist / forged argument — mirroring the ASIP
-- mirror-bridge pattern (20260920000040), which derives scope from the session,
-- never from a trusted parameter.
--
-- Verified calling context (why each guard is safe for legitimate provisioning):
--   * onboarding_ensure_school_membership — sole caller is the teacher-import
--     commit (onboarding_repository.commitImportJob → ensureSchoolMembership),
--     which runs under withTenantContext at SCHOOL scope. schoolIdFromClaims()
--     THROWS unless claims.school_id is present, so app_current_school_id() is
--     always set and p_school_id == the session school, which belongs to
--     app_current_tenant_id(). The importer only ever produces the roles
--     teacher / principal / schoolAdmin (parseTeacherImportRow allowlist).
--   * onboarding_upsert_user_by_phone — `users` is a GLOBAL identity table (no
--     org/school column); one phone is deliberately shared across tenants (one
--     identity, many schools). A per-row tenant predicate is therefore
--     impossible without breaking legitimate cross-org onboarding, so the safe
--     guardrail is to refuse to run outside an established tenant session.
--   * assign_organization_subscription — platform plan assignment is CROSS-ORG by
--     design (a superAdmin sets ANY org's plan via
--     PUT /platform/organizations/:id/subscription, declared scope 'organization',
--     never 'platform'). Tying p_organization_id to app_current_tenant_id() or
--     asserting a 'platform' scope GUC would BREAK the legitimate flow. The safe
--     defense-in-depth is to require an authenticated session, bind the recorded
--     actor to the real session principal (handler passes actorId = claims.sub =
--     app_current_user_id()), and require a real, non-deleted target org.
--
-- Posture preserved exactly: SECURITY DEFINER, SET search_path = public, and the
-- existing REVOKE-from-PUBLIC / GRANT-to-erp_tenant grants. Bodies are byte-for-
-- byte the originals with ONLY the guard block prepended. Additive + idempotent
-- (CREATE OR REPLACE); no migration-time caller invokes these, so the
-- session-context guards never fire during migration.

-- ─── 1 · onboarding_ensure_school_membership: tenant/school scope + role allowlist
CREATE OR REPLACE FUNCTION onboarding_ensure_school_membership(
  p_user_id UUID,
  p_school_id UUID,
  p_role TEXT
) RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_membership_id UUID;
  v_role TEXT;
  v_tenant UUID := app_current_tenant_id();
BEGIN
  -- ICA-B3 guard: re-derive the tenant boundary in-DB (this fn bypasses RLS).
  IF v_tenant IS NULL THEN
    RAISE EXCEPTION 'onboarding_ensure_school_membership: no authenticated tenant session'
      USING ERRCODE = 'insufficient_privilege';
  END IF;
  -- The target school MUST belong to the caller's tenant.
  IF NOT EXISTS (
    SELECT 1 FROM schools
    WHERE id = p_school_id
      AND organization_id = v_tenant
      AND deleted_at IS NULL
  ) THEN
    RAISE EXCEPTION 'onboarding_ensure_school_membership: school % is not in the caller tenant %',
      p_school_id, v_tenant
      USING ERRCODE = 'insufficient_privilege';
  END IF;
  -- When a school-scoped session is active (the onboarding path), the target
  -- school must equal the session school.
  IF app_current_school_id() IS NOT NULL AND p_school_id <> app_current_school_id() THEN
    RAISE EXCEPTION 'onboarding_ensure_school_membership: school % does not match the session school %',
      p_school_id, app_current_school_id()
      USING ERRCODE = 'insufficient_privilege';
  END IF;

  v_role := COALESCE(NULLIF(btrim(p_role), ''), 'teacher');
  IF v_role = 'schooladmin' THEN
    v_role := 'schoolAdmin';
  END IF;

  -- ICA-B3 role allowlist: onboarding may only assign a school-scoped staff role
  -- (mirrors role_definitions.scope='school'). This blocks privilege escalation
  -- via a forged p_role (e.g. 'superAdmin' / 'organizationOwner' / 'organizationAdmin'
  -- / 'schoolGroupDirector'). The importer only ever produces teacher / principal
  -- / schoolAdmin, all of which are allowed.
  IF v_role NOT IN (
    'teacher', 'principal', 'schoolAdmin', 'vicePrincipal', 'classTeacher',
    'financeAdmin', 'financeManager', 'hrManager', 'inventoryManager',
    'transportManager', 'marketingManager', 'coordinator', 'counselor',
    'admissionsCounselor', 'petTeacher', 'danceTeacher', 'musicTeacher',
    'librarian', 'officeStaff', 'management', 'hostelManager'
  ) THEN
    RAISE EXCEPTION 'onboarding_ensure_school_membership: role % is not an assignable school role',
      v_role
      USING ERRCODE = 'check_violation';
  END IF;

  INSERT INTO school_memberships (user_id, school_id, role, status, permissions_version)
  VALUES (p_user_id, p_school_id, v_role, 'active', 1)
  ON CONFLICT (user_id, school_id)
  DO UPDATE SET
    role = EXCLUDED.role,
    status = 'active',
    updated_at = timezone('utc', now())
  RETURNING id INTO v_membership_id;

  INSERT INTO school_membership_roles (school_membership_id, role_slug, is_primary, status)
  VALUES (v_membership_id, v_role, true, 'active')
  ON CONFLICT (school_membership_id, role_slug)
  DO UPDATE SET status = 'active', is_primary = true;

  RETURN v_membership_id;
END;
$$;

-- ─── 2 · onboarding_upsert_user_by_phone: authenticated-tenant-session guard ───
CREATE OR REPLACE FUNCTION onboarding_upsert_user_by_phone(
  p_phone TEXT,
  p_display_name TEXT,
  p_email TEXT DEFAULT NULL
) RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id UUID;
  v_phone TEXT;
BEGIN
  -- ICA-B3 guard: `users` is a GLOBAL identity table (no org/school column) — one
  -- phone is deliberately shared across tenants (one identity, many schools), so a
  -- per-row tenant predicate is impossible without breaking legitimate cross-org
  -- onboarding. The safe, behavior-preserving guardrail is to refuse to run
  -- outside an established tenant session (fail-closed): every legitimate caller
  -- reaches this fn through withTenantContext, which sets app.tenant_id first.
  -- This blocks contextless / forged invocation of the definer fn; the true
  -- cross-tenant boundary for this global write stays the app-layer gate.
  IF app_current_tenant_id() IS NULL THEN
    RAISE EXCEPTION 'onboarding_upsert_user_by_phone: no authenticated tenant session'
      USING ERRCODE = 'insufficient_privilege';
  END IF;

  v_phone := NULLIF(btrim(p_phone), '');
  IF v_phone IS NULL THEN
    RAISE EXCEPTION 'phone required';
  END IF;
  IF v_phone NOT LIKE '+%' AND v_phone ~ '^\d{10}$' THEN
    v_phone := '+91' || v_phone;
  END IF;

  SELECT id INTO v_user_id FROM users WHERE phone = v_phone LIMIT 1;
  IF v_user_id IS NOT NULL THEN
    UPDATE users
    SET display_name = COALESCE(NULLIF(btrim(p_display_name), ''), display_name),
        email = COALESCE(p_email, email),
        updated_at = timezone('utc', now())
    WHERE id = v_user_id;
    RETURN v_user_id;
  END IF;

  INSERT INTO users (phone, display_name, email)
  VALUES (v_phone, COALESCE(NULLIF(btrim(p_display_name), ''), ''), p_email)
  RETURNING id INTO v_user_id;
  RETURN v_user_id;
END;
$$;

-- ─── 3 · assign_organization_subscription: session + actor-binding + real-org ──
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
  v_caller uuid := app_current_user_id();
BEGIN
  -- ICA-B3 guard: platform plan assignment is CROSS-ORG by design (a superAdmin
  -- sets ANY org's plan), so p_organization_id must NOT be tied to
  -- app_current_tenant_id(); the route runs at 'organization' scope (there is no
  -- 'platform' scope GUC), so a scope check would break the legitimate flow. The
  -- safe defense-in-depth: (a) require an authenticated session, (b) bind the
  -- recorded actor to the real session principal — the handler passes
  -- actorId = claims.sub = app_current_user_id(), so a forged p_actor is
  -- rejected — and (c) require the target org to be a real, non-deleted org.
  IF v_caller IS NULL OR app_current_tenant_id() IS NULL THEN
    RAISE EXCEPTION 'assign_organization_subscription: no authenticated session'
      USING ERRCODE = 'insufficient_privilege';
  END IF;
  IF p_actor IS DISTINCT FROM v_caller THEN
    RAISE EXCEPTION 'assign_organization_subscription: actor % does not match the session principal %',
      p_actor, v_caller
      USING ERRCODE = 'insufficient_privilege';
  END IF;
  IF NOT EXISTS (
    SELECT 1 FROM organizations
    WHERE id = p_organization_id AND deleted_at IS NULL
  ) THEN
    RAISE EXCEPTION 'assign_organization_subscription: unknown or deleted organization %',
      p_organization_id
      USING ERRCODE = 'foreign_key_violation';
  END IF;

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

-- Preserve the exact existing security posture (grants unchanged; re-asserted so
-- the CREATE OR REPLACE keeps a self-contained, idempotent grant state).
REVOKE ALL ON FUNCTION onboarding_upsert_user_by_phone(TEXT, TEXT, TEXT) FROM PUBLIC;
REVOKE ALL ON FUNCTION onboarding_ensure_school_membership(UUID, UUID, TEXT) FROM PUBLIC;
REVOKE ALL ON FUNCTION assign_organization_subscription(uuid, text, text, uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION onboarding_upsert_user_by_phone(TEXT, TEXT, TEXT) TO erp_tenant;
GRANT EXECUTE ON FUNCTION onboarding_ensure_school_membership(UUID, UUID, TEXT) TO erp_tenant;
GRANT EXECUTE ON FUNCTION assign_organization_subscription(uuid, text, text, uuid) TO erp_tenant;
