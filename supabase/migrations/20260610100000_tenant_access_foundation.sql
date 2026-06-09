-- v6.1 Sprint 3 Phase 3A — Non-bypass tenant access (TD-P0-01 partial close)
-- Architecture: v6.1 §6.5; TD-P0-01 AC-1, AC-2, AC-3
-- Enforced isolation probes run via Edge `withTenantContext` + ERP_TENANT_DATABASE_URL.

-- ─── Non-bypass database role ────────────────────────────────────────────────
-- LOGIN password must match ERP_TENANT_DATABASE_URL secret on Edge Functions.

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
