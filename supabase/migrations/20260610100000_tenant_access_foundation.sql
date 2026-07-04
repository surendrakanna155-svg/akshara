-- v6.1 Sprint 3 Phase 3A — Non-bypass tenant access (TD-P0-01 partial close)
-- Architecture: v6.1 §6.5; TD-P0-01 AC-1, AC-2, AC-3
-- Enforced isolation probes run via Edge `withTenantContext` + ERP_TENANT_DATABASE_URL.

-- ─── Non-bypass database role ────────────────────────────────────────────────
-- P0-INFRA-5 / DB-1 / OPS-6: the LOGIN password is NO LONGER a committed literal.
-- It is read from the `erp.tenant_password` GUC, which the deploy/provisioning
-- step sets from a secret (NOT stored in git) before applying migrations, e.g.
--   psql -v ON_ERROR_STOP=1 -c "SET erp.tenant_password = '<secret>'" -f <this>
-- or by exporting PGOPTIONS="-c erp.tenant_password=<secret>". It MUST match the
-- ERP_TENANT_DATABASE_URL secret on the Edge Functions. For local/dev only, an
-- obviously-non-secret fallback is used so a fresh `supabase start` still works;
-- production/staging MUST supply the GUC. (On an already-provisioned DB the role
-- exists, so this block is a no-op — rotate with `ALTER ROLE erp_tenant PASSWORD`.)

DO $$
DECLARE
  v_pw text := current_setting('erp.tenant_password', true);
BEGIN
  IF v_pw IS NULL OR v_pw = '' THEN
    -- DEV/LOCAL fallback ONLY — never a real credential. Any production or
    -- staging deploy must set erp.tenant_password from a secret.
    v_pw := 'dev_local_only_change_via_erp_tenant_password_guc';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_catalog.pg_roles WHERE rolname = 'erp_tenant') THEN
    EXECUTE format(
      'CREATE ROLE erp_tenant LOGIN PASSWORD %L '
      'NOSUPERUSER NOBYPASSRLS NOCREATEDB NOCREATEROLE NOREPLICATION',
      v_pw
    );
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
