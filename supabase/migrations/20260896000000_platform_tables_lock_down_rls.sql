-- PRC P5 (red-team P4-RT-1 Round 4 — cross-tenant RLS coverage sweep) — close the
-- one isolation gap.
--
-- The RLS coverage sweep (every public table with an organization_id column vs its
-- rls/forced/policy state) found EXACTLY three tables holding tenant data with NO
-- row-level security AND the vestigial Supabase default grants to `anon`
-- (UNAUTHENTICATED) and `authenticated` (any logged-in user) still in place:
--   platform_provider_configs · platform_feature_enablements · platform_usage_events
-- Every other tenant table is protected by FORCE RLS (which neutralises the same
-- default grants — see platform_secret_vault / RT-15). These three were never
-- locked down, so via the PostgREST gateway `anon`/`authenticated` could read AND
-- write every org's provider config / feature flags / usage events with no scoping.
--
-- The app never reaches these via PostgREST — it uses the raw `erp_platform` pool
-- (platform_db.ts) and, for migrations, superuser `supabase_admin`. So the anon/
-- authenticated grants are pure exposure. Fix = REVOKE them + enable FORCE RLS
-- (defense-in-depth, matching every other tenant table). service_role (bypassrls)
-- and supabase_admin (superuser) are unaffected; erp_platform (non-bypass) gets an
-- explicit policy on the one table it uses so FORCE RLS does not block it.

-- ── 1. Remove the exposure: revoke the vestigial anon/authenticated grants ────
REVOKE ALL ON platform_provider_configs FROM anon, authenticated;
REVOKE ALL ON platform_feature_enablements FROM anon, authenticated;
REVOKE ALL ON platform_usage_events FROM anon, authenticated;

-- ── 2. Defense-in-depth: FORCE RLS on all three (like every other tenant table) ─
ALTER TABLE platform_provider_configs ENABLE ROW LEVEL SECURITY;
ALTER TABLE platform_provider_configs FORCE ROW LEVEL SECURITY;
ALTER TABLE platform_feature_enablements ENABLE ROW LEVEL SECURITY;
ALTER TABLE platform_feature_enablements FORCE ROW LEVEL SECURITY;
ALTER TABLE platform_usage_events ENABLE ROW LEVEL SECURITY;
ALTER TABLE platform_usage_events FORCE ROW LEVEL SECURITY;

-- ── 3. erp_platform (non-bypass platform-superadmin role) manages provider configs
-- across orgs — it needs an explicit policy so FORCE RLS does not lock it out. The
-- other two tables have no erp_platform grant (their only readers are the bypassrls
-- service_role + superuser supabase_admin, which are not subject to RLS), so a
-- FORCE-RLS-with-no-policy deny-by-default is correct for them.
CREATE POLICY platform_provider_configs_platform_manage ON platform_provider_configs
  FOR ALL TO erp_platform USING (true) WITH CHECK (true);
