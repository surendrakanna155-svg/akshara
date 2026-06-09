-- v6.1 Sprint 3 Phase 3A — Non-bypass tenant access (TD-P0-01 partial close)
-- Architecture: v6.1 §6.5; TD-P0-01 AC-1, AC-2, AC-3

-- ─── Non-bypass database role ────────────────────────────────────────────────
-- LOGIN password must match ERP_TENANT_DATABASE_URL secret on Edge Functions.
-- Rotate in production via: ALTER ROLE erp_tenant WITH PASSWORD '...';

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_catalog.pg_roles WHERE rolname = 'erp_tenant') THEN
    CREATE ROLE erp_tenant
      LOGIN
      PASSWORD 'akshara_erp_tenant_staging_v1'
      NOSUPERUSER
      NOBYPASSRLS
      NOCREATEDB
      NOCREATEROLE
      NOREPLICATION;
  END IF;
END
$$;

GRANT CONNECT ON DATABASE postgres TO erp_tenant;
GRANT USAGE ON SCHEMA public, app, tenant_isolation TO erp_tenant;

GRANT SELECT ON
  organizations,
  schools,
  users,
  organization_memberships,
  school_memberships,
  students,
  student_guardians,
  org_school_summary
TO erp_tenant;

GRANT EXECUTE ON FUNCTION app.set_request_context TO erp_tenant;
GRANT EXECUTE ON FUNCTION public.set_request_context TO erp_tenant;

-- ─── FORCE RLS — policies apply even to table owners (TD-P0-01 AC-2) ────────

ALTER TABLE organizations FORCE ROW LEVEL SECURITY;
ALTER TABLE schools FORCE ROW LEVEL SECURITY;
ALTER TABLE users FORCE ROW LEVEL SECURITY;
ALTER TABLE organization_memberships FORCE ROW LEVEL SECURITY;
ALTER TABLE school_memberships FORCE ROW LEVEL SECURITY;
ALTER TABLE students FORCE ROW LEVEL SECURITY;
ALTER TABLE student_guardians FORCE ROW LEVEL SECURITY;

-- ─── Enforced isolation test (created as erp_tenant — hosted Postgres blocks ALTER OWNER) ─

DO $$
BEGIN
  EXECUTE format('GRANT erp_tenant TO %I', current_user);
END
$$;

SET ROLE erp_tenant;

CREATE OR REPLACE FUNCTION run_tenant_isolation_enforced_test()
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_org UUID := 'a1000000-0000-4000-8000-000000000001';
  v_school_a UUID := 'a2000000-0000-4000-8000-000000000001';
  v_school_b UUID := 'a2000000-0000-4000-8000-000000000002';
  v_staff_a UUID := 'a3000000-0000-4000-8000-000000000001';
  v_parent UUID := 'a3000000-0000-4000-8000-000000000003';
  v_student_user UUID := 'a3000000-0000-4000-8000-000000000004';
  v_student_a UUID := 'a4000000-0000-4000-8000-000000000001';
  v_student_b UUID := 'a4000000-0000-4000-8000-000000000002';
  v_count INT;
  v_tests JSONB := '[]'::jsonb;
  v_all_pass BOOLEAN := true;
BEGIN
  -- School A cannot read School B
  PERFORM app.set_request_context(v_org, 'school', v_staff_a, v_school_a, NULL, NULL, NULL);
  SELECT count(*) INTO v_count FROM schools WHERE id = v_school_b;
  v_tests := v_tests || jsonb_build_object(
    'name', 'school_a_cannot_see_school_b',
    'pass', v_count = 0,
    'detail', format('visible_schools=%s', v_count)
  );
  IF v_count <> 0 THEN v_all_pass := false; END IF;

  -- Org scope sees school list (metadata)
  PERFORM app.set_request_context(v_org, 'organization', v_staff_a, NULL, NULL, NULL, NULL);
  SELECT count(*) INTO v_count FROM schools WHERE organization_id = v_org;
  v_tests := v_tests || jsonb_build_object(
    'name', 'org_scope_sees_school_metadata',
    'pass', v_count >= 2,
    'detail', format('visible_schools=%s', v_count)
  );
  IF v_count < 2 THEN v_all_pass := false; END IF;

  -- Org scope denied raw cross-school staff memberships (aggregate-only path)
  PERFORM app.set_request_context(v_org, 'organization', v_staff_a, NULL, NULL, NULL, NULL);
  SELECT count(*) INTO v_count FROM school_memberships;
  v_tests := v_tests || jsonb_build_object(
    'name', 'org_scope_denied_raw_school_memberships',
    'pass', v_count = 0,
    'detail', format('visible_memberships=%s', v_count)
  );
  IF v_count <> 0 THEN v_all_pass := false; END IF;

  -- Org scope denied raw student PII table
  PERFORM app.set_request_context(v_org, 'organization', v_staff_a, NULL, NULL, NULL, NULL);
  SELECT count(*) INTO v_count FROM students;
  v_tests := v_tests || jsonb_build_object(
    'name', 'org_scope_denied_raw_students',
    'pass', v_count = 0,
    'detail', format('visible_students=%s', v_count)
  );
  IF v_count <> 0 THEN v_all_pass := false; END IF;

  -- Org scope reads aggregate view only
  PERFORM app.set_request_context(v_org, 'organization', v_staff_a, NULL, NULL, NULL, NULL);
  SELECT count(*) INTO v_count FROM org_school_summary WHERE tenant_id = v_org;
  v_tests := v_tests || jsonb_build_object(
    'name', 'org_scope_reads_aggregate_view',
    'pass', v_count >= 2,
    'detail', format('summary_rows=%s', v_count)
  );
  IF v_count < 2 THEN v_all_pass := false; END IF;

  -- Parent sees linked child only
  PERFORM app.set_request_context(v_org, 'parent', v_parent, v_school_a, NULL, NULL, v_parent);
  SELECT count(*) INTO v_count FROM students WHERE id = v_student_a;
  v_tests := v_tests || jsonb_build_object(
    'name', 'parent_sees_linked_child',
    'pass', v_count = 1,
    'detail', format('visible_students=%s', v_count)
  );
  IF v_count <> 1 THEN v_all_pass := false; END IF;

  -- Parent cannot see unrelated student at School B
  PERFORM app.set_request_context(v_org, 'parent', v_parent, v_school_b, NULL, NULL, v_parent);
  SELECT count(*) INTO v_count FROM students WHERE id = v_student_b;
  v_tests := v_tests || jsonb_build_object(
    'name', 'parent_cannot_see_unlinked_student',
    'pass', v_count = 0,
    'detail', format('visible_students=%s', v_count)
  );
  IF v_count <> 0 THEN v_all_pass := false; END IF;

  -- Student sees self only
  PERFORM app.set_request_context(v_org, 'student', v_student_user, v_school_a, NULL, v_student_a, NULL);
  SELECT count(*) INTO v_count FROM students;
  v_tests := v_tests || jsonb_build_object(
    'name', 'student_sees_self_only',
    'pass', v_count = 1,
    'detail', format('visible_students=%s', v_count)
  );
  IF v_count <> 1 THEN v_all_pass := false; END IF;

  RETURN jsonb_build_object(
    'pass', v_all_pass,
    'enforced', true,
    'role', current_user::text,
    'tests', v_tests
  );
END;
$$;

RESET ROLE;

REVOKE ALL ON FUNCTION run_tenant_isolation_enforced_test() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION run_tenant_isolation_enforced_test() TO service_role;
