-- PRC P5 (red-team P4-RT-1 Round 4/5 — isolation sweep, broadened to school_id /
-- context_school_id tables) — close the auth-table exposure.
--
-- Broadening the RLS coverage sweep beyond organization_id (to school_id /
-- context_school_id) surfaced two MORE public tables with NO row-level security AND
-- the vestigial Supabase default grants to `anon` (UNAUTHENTICATED) + `authenticated`:
--   * sessions       — app session records (user_id, tenant_id, ip, user_agent, scope,
--                       context_*). Anon read = session enumeration / info disclosure;
--                       anon write = forge/revoke sessions.
--   * otp_requests   — login OTP flow (phone PII, consumed_at/expires_at). Anon read =
--                       phone-PII disclosure; anon write = forge / prematurely consume OTPs.
-- Via the PostgREST gateway these were reachable with no auth and no scoping — a P0 if
-- PostgREST is internet-facing.
--
-- The app's auth flow reaches BOTH exclusively through the SERVICE-ROLE client
-- (auth_handlers.ts `createServiceClient` → `service_role`, which keeps its grant and
-- is bypassrls); no code path uses anon/authenticated or a non-bypass role for these
-- (verified: every access is `client.from(...)` on the service client). So the anon/
-- authenticated grants are pure exposure. Fix = REVOKE them + FORCE RLS (defense in
-- depth; service_role + superuser supabase_admin bypass RLS, so the auth flow is
-- unaffected; no non-bypass reader exists).

REVOKE ALL ON sessions FROM anon, authenticated;
REVOKE ALL ON otp_requests FROM anon, authenticated;

ALTER TABLE sessions ENABLE ROW LEVEL SECURITY;
ALTER TABLE sessions FORCE ROW LEVEL SECURITY;
ALTER TABLE otp_requests ENABLE ROW LEVEL SECURITY;
ALTER TABLE otp_requests FORCE ROW LEVEL SECURITY;
