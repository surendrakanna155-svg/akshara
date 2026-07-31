-- =============================================================================
-- READ-ONLY diagnostic: why does POST /auth/verify-otp return 500?
--
-- Run against the LIVE tenant database. Performs SELECTs only — no DDL, no DML,
-- no locks beyond catalog reads. Safe on production.
--
--   docker exec -i akshara-postgres psql -U <user> -d <db> -f - < scripts/diagnose_auth_schema.sql
--
-- Background: the OTP login path resolves permissions through
-- `permission_resolver.ts`, whose queries `throw` on ANY Postgres error. Those
-- throws happen OUTSIDE handleVerifyOtp's try/catch, so they surface as the
-- generic 500 "An unexpected error occurred." with no server-side detail
-- (the thrown PostgrestError is a plain object, not an Error, so even the
-- request log records only "Unexpected error").
--
-- This script checks every column those queries touch. Anything reported as
-- MISSING is a sufficient cause of the 500.
-- =============================================================================

\pset pager off

\echo ''
\echo '=== 1. Columns the login permission-resolver requires ==='
SELECT
  chk.table_name || '.' || chk.column_name AS required_object,
  CASE WHEN c.column_name IS NULL THEN '*** MISSING ***' ELSE 'present' END AS status,
  chk.introduced_by AS introduced_by_migration
FROM (VALUES
  -- loadRolePermissionMap()  — shared by BOTH the school and organization paths
  ('role_permissions',                 'role_slug',                  'baseline 20260608100000'),
  ('role_permissions',                 'permission_slug',            'baseline 20260608100000'),
  ('role_permissions',                 'organization_id',            '20260920000200_tenant_custom_roles'),
  ('role_definitions',                 'organization_id',            '20260920000200_tenant_custom_roles'),
  -- resolveSchoolMembershipPermissions()
  ('school_membership_roles',          'role_slug',                  'baseline'),
  ('school_membership_roles',          'is_primary',                 'baseline'),
  ('school_membership_roles',          'status',                     'baseline'),
  ('membership_permission_overrides',  'school_membership_id',       'baseline'),
  ('membership_permission_overrides',  'permission_slug',            'baseline'),
  ('membership_permission_overrides',  'effect',                     'baseline'),
  -- resolveOrganizationMembershipPermissions()
  ('organization_membership_roles',    'role_slug',                  'baseline'),
  ('organization_membership_roles',    'is_primary',                 'baseline'),
  ('organization_membership_roles',    'status',                     'baseline'),
  ('membership_permission_overrides',  'organization_membership_id', 'baseline')
) AS chk(table_name, column_name, introduced_by)
LEFT JOIN information_schema.columns c
  ON c.table_schema = 'public'
 AND c.table_name   = chk.table_name
 AND c.column_name  = chk.column_name
ORDER BY (c.column_name IS NOT NULL), required_object;  -- MISSING rows first

\echo ''
\echo '=== 2. VERDICT ==='
SELECT CASE WHEN missing = 0
         THEN 'All resolver columns present — the 500 has a DIFFERENT cause; do not apply a migration blindly. Capture the real error next (section 5).'
         ELSE missing || ' required column(s) MISSING — this fully explains the 500.'
       END AS verdict
FROM (
  SELECT count(*) AS missing
  FROM (VALUES
    ('role_permissions','organization_id'), ('role_definitions','organization_id'),
    ('role_permissions','role_slug'), ('role_permissions','permission_slug'),
    ('school_membership_roles','role_slug'), ('school_membership_roles','is_primary'),
    ('school_membership_roles','status'), ('organization_membership_roles','role_slug'),
    ('organization_membership_roles','is_primary'), ('organization_membership_roles','status'),
    ('membership_permission_overrides','school_membership_id'),
    ('membership_permission_overrides','organization_membership_id'),
    ('membership_permission_overrides','permission_slug'), ('membership_permission_overrides','effect')
  ) AS chk(t, col)
  LEFT JOIN information_schema.columns c
    ON c.table_schema='public' AND c.table_name=chk.t AND c.column_name=chk.col
  WHERE c.column_name IS NULL
) s;

\echo ''
\echo '=== 3. Migration bookkeeping (if this DB records it) ==='
SELECT CASE
  WHEN to_regclass('supabase_migrations.schema_migrations') IS NULL
    THEN 'No supabase_migrations.schema_migrations table — this DB is not tracked by the supabase CLI. Trust section 1 (actual objects), not bookkeeping.'
  ELSE 'tracked — see next result set'
END AS migration_tracking;

SELECT count(*) AS applied_count, min(version) AS earliest, max(version) AS latest
FROM supabase_migrations.schema_migrations
WHERE to_regclass('supabase_migrations.schema_migrations') IS NOT NULL;

\echo ''
\echo '--- is the suspected migration recorded as applied? ---'
SELECT coalesce(
  (SELECT 'YES — 20260920000200 is recorded applied'
     FROM supabase_migrations.schema_migrations WHERE version = '20260920000200'),
  'NO  — 20260920000200 is NOT recorded applied') AS tenant_custom_roles_20260920000200;

\echo ''
\echo '=== 4. Live account shape (does a login even have a membership?) ==='
SELECT 'users'                     AS relation, count(*) FROM users
UNION ALL SELECT 'school_memberships (active)',       count(*) FROM school_memberships       WHERE status = 'active'
UNION ALL SELECT 'organization_memberships (active)', count(*) FROM organization_memberships WHERE status = 'active'
UNION ALL SELECT 'role_permissions',                  count(*) FROM role_permissions
UNION ALL SELECT 'role_definitions',                  count(*) FROM role_definitions;

\echo ''
\echo '=== 5. If section 2 says all columns are present, run THIS to surface the real error ==='
\echo '    (it reproduces the exact resolver SELECT; the error message names the culprit)'
\echo ''
\echo '    SELECT role_slug, permission_slug, organization_id FROM role_permissions LIMIT 1;'
\echo '    SELECT role_slug, is_primary, status FROM school_membership_roles LIMIT 1;'
\echo '    SELECT permission_slug, effect FROM membership_permission_overrides LIMIT 1;'
\echo ''
