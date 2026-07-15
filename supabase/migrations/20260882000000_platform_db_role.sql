-- PRC-A caps 44-49 — platform-scoped DB role for the AI/WhatsApp/SMS
-- provider vault (`platform_secret_vault` / `platform_provider_configs` /
-- `platform_secret_audit_log`).
--
-- THE DEFECT: `20260815000000_red_team_wave2_tenant_privacy_rls.sql`
-- (RT-15, ~L288-310) live-probed and found `erp_tenant` has NO grant on
-- `platform_secret_vault`, and correctly added ENABLE/FORCE RLS + a
-- `platform_secret_vault_deny_all` policy as belt-and-braces — that finding
-- and that fix are BOTH still correct and are left untouched here. But every
-- Control-Center vault handler (`control_center/platform_providers_handlers.ts`
-- store/list/rotate/health, `vault/vault_reencrypt.ts` reencrypt) runs on
-- `withTenantContext` — the `erp_tenant` connection — by design a non-bypass
-- RLS connection with NO access to platform tables. So every vault
-- store/rotate/health/reencrypt has ALWAYS failed `permission denied` in
-- production: the panel-facing AI provider vault is decorative.
--
-- Platform secrets are SUPER-ADMIN/platform scope, not tenant data — the
-- architecture was simply missing a platform-scoped DB role. This migration
-- adds exactly one: `erp_platform`, mirroring the `erp_tenant` role from
-- `20260610100000_tenant_access_foundation.sql` (same attrs, same
-- GUC-sourced-password pattern), granted ONLY on the 3 vault tables, and
-- reachable only via the app's new `withPlatformContext` (see
-- `supabase/functions/_shared/platform_db.ts`) which itself gates on the
-- caller genuinely being a platform/super-admin session BEFORE it ever opens
-- this connection. RT-15's deny-all is NEVER weakened, and `erp_tenant`
-- NEVER receives access to these tables — see the RLS section below for why
-- that's still true after this migration.

-- ─── Non-bypass platform database role ──────────────────────────────────────
-- The LOGIN password is NOT a committed literal. It is read from the
-- `erp.platform_password` GUC, which the deploy/provisioning step sets from a
-- secret (NOT stored in git) before applying migrations, e.g.
--   psql -v ON_ERROR_STOP=1 -c "SET erp.platform_password = '<secret>'" -f <this>
-- or by exporting PGOPTIONS="-c erp.platform_password=<secret>". It MUST
-- match the `ERP_PLATFORM_DATABASE_URL` secret configured on the Edge
-- Functions. For local/dev only, an obviously-non-secret fallback is used so
-- a fresh `supabase start` still works; production/staging MUST supply the
-- GUC. (On an already-provisioned DB the role exists, so this block is a
-- no-op — rotate with `ALTER ROLE erp_platform PASSWORD`.)

DO $$
DECLARE
  v_pw text := current_setting('erp.platform_password', true);
BEGIN
  IF v_pw IS NULL OR v_pw = '' THEN
    -- DEV/LOCAL fallback ONLY — never a real credential. Any production or
    -- staging deploy must set erp.platform_password from a secret.
    v_pw := 'dev_local_only_change_via_erp_platform_password_guc';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_catalog.pg_roles WHERE rolname = 'erp_platform') THEN
    EXECUTE format(
      'CREATE ROLE erp_platform LOGIN PASSWORD %L '
      'NOSUPERUSER NOBYPASSRLS NOCREATEDB NOCREATEROLE NOREPLICATION',
      v_pw
    );
  END IF;
END
$$;

GRANT CONNECT ON DATABASE postgres TO erp_platform;
GRANT USAGE ON SCHEMA public TO erp_platform;

-- No EXECUTE grant on `app.set_request_context` / `public.set_request_context`
-- (unlike `erp_tenant`): the platform path never calls it. All three tables
-- below carry no `organization_id = app_current_tenant_id()`-style tenant RLS
-- to satisfy — platform secrets are genuinely global/platform-scoped, not
-- tenant-partitioned — so there is no request context for `erp_platform` to
-- set. `withPlatformContext` (platform_db.ts) does not call it either.

-- Least-privilege: ONLY what the provider-key vault needs (verified against
-- the actual `CREATE TABLE` statements in 20260625000000_phase10_school_final.sql
-- — no table invented here).
GRANT SELECT, INSERT, UPDATE ON platform_secret_vault TO erp_platform;
GRANT SELECT, INSERT, UPDATE ON platform_provider_configs TO erp_platform;
GRANT SELECT, INSERT ON platform_secret_audit_log TO erp_platform;

-- ─── RLS: RT-15's deny-all stays intact; add an explicit permissive allow for erp_platform ONLY ───
-- `platform_secret_vault` already has ENABLE + FORCE ROW LEVEL SECURITY and a
-- `platform_secret_vault_deny_all` policy (`USING (false) WITH CHECK (false)`)
-- from RT-15 — NOT touched, NOT dropped, NOT weakened here. Postgres OR's
-- multiple PERMISSIVE policies together, so for `erp_platform`:
--   deny_all(false) OR platform_rw(true)  =>  allowed
-- and for every other role (erp_tenant, anon, authenticated, ...):
--   deny_all(false) OR <no matching policy>  =>  denied
-- `erp_platform` stays NOBYPASSRLS on purpose — this is an explicit, narrow,
-- auditable allow policy scoped to one role, not a blanket RLS bypass.
DROP POLICY IF EXISTS platform_secret_vault_platform_rw ON platform_secret_vault;
CREATE POLICY platform_secret_vault_platform_rw ON platform_secret_vault
  FOR ALL TO erp_platform
  USING (true)
  WITH CHECK (true);

-- `platform_provider_configs` and `platform_secret_audit_log` do NOT have RLS
-- enabled anywhere in the migration history (verified: no
-- `ENABLE ROW LEVEL SECURITY` / policy exists for either table today — access
-- to them has only ever been grant-gated, and until this migration NO role
-- was granted access at all). Per the owning task's instruction, an
-- RLS allow-policy is added ONLY for a table that already has RLS/deny in
-- place (`platform_secret_vault`, above); these two tables get the GRANTs
-- above and nothing else — adding new RLS to them is a separate, out-of-scope
-- decision, not silently bundled into this fix.
