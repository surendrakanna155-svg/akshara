-- ASIP — Phase 2, migration 3: close the "School is informed" loop.
--
-- When support resolves an incident, the resolution already flows back to the
-- school incident via app_support_propagate_resolution. This redefines that
-- bridge to ALSO enqueue a push notification to the reporter (the bridge runs as
-- the definer/superuser, so it can insert the school-scoped notification row
-- directly — the same delivery queue the rest of the app drains). Additive:
-- CREATE OR REPLACE, no schema change, no existing row touched.

CREATE OR REPLACE FUNCTION app_support_propagate_resolution(
  p_incident uuid,
  p_source_status text,
  p_resolution text
) RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS
$$
DECLARE
  v_caller uuid := app_current_tenant_id();
  v_src_org uuid;
  v_src_school uuid;
  v_reporter uuid;
  v_public_ref text;
BEGIN
  IF v_caller IS DISTINCT FROM app_support_platform_org() THEN
    RAISE EXCEPTION 'only the platform-support org may propagate a resolution';
  END IF;

  SELECT source_org_id, source_school_id INTO v_src_org, v_src_school
  FROM support_platform_incident
  WHERE id = p_incident AND platform_org_id = app_support_platform_org();
  IF v_src_org IS NULL THEN
    RAISE EXCEPTION 'mirror incident not found';
  END IF;

  UPDATE support_incident
     SET status = p_source_status,
         resolution_summary = p_resolution,
         resolved_at = CASE WHEN p_source_status = 'resolved' AND resolved_at IS NULL
                            THEN timezone('utc', now()) ELSE resolved_at END,
         updated_at = timezone('utc', now())
   WHERE id = p_incident AND organization_id = v_src_org
   RETURNING reporter_user_id, public_ref INTO v_reporter, v_public_ref;

  UPDATE support_platform_incident
     SET source_status = p_source_status, updated_at = timezone('utc', now())
   WHERE id = p_incident;

  -- Inform the school: enqueue a push notification to the reporter on resolve.
  IF p_source_status = 'resolved' AND v_reporter IS NOT NULL THEN
    INSERT INTO notification_deliveries (
      organization_id, school_id, recipient_user_id, channel, category,
      rendered_subject, rendered_body, status
    ) VALUES (
      v_src_org, v_src_school, v_reporter, 'push', 'support',
      COALESCE(v_public_ref, 'Your reported issue') || ' is resolved',
      'Akshara Support has resolved your reported issue.', 'pending'
    );
  END IF;
END;
$$;

REVOKE ALL ON FUNCTION app_support_propagate_resolution(uuid, text, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION app_support_propagate_resolution(uuid, text, text) TO erp_tenant;
