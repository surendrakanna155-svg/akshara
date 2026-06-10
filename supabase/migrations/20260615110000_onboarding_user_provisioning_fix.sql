-- Pilot fix: onboarding import commit failed because erp_tenant could not upsert users
-- inside the tenant transaction (RLS + missing INSERT grant aborted the transaction).

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
BEGIN
  v_role := COALESCE(NULLIF(btrim(p_role), ''), 'teacher');
  IF v_role = 'schooladmin' THEN
    v_role := 'schoolAdmin';
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

REVOKE ALL ON FUNCTION onboarding_upsert_user_by_phone(TEXT, TEXT, TEXT) FROM PUBLIC;
REVOKE ALL ON FUNCTION onboarding_ensure_school_membership(UUID, UUID, TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION onboarding_upsert_user_by_phone(TEXT, TEXT, TEXT) TO erp_tenant;
GRANT EXECUTE ON FUNCTION onboarding_ensure_school_membership(UUID, UUID, TEXT) TO erp_tenant;
