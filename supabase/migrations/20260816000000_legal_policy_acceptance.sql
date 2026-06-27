-- Legal & Compliance — policy acceptance ledger.
--
-- Records, append-only, which user accepted which legal policy version, when, and
-- from which IP/device. Backs the in-app legal acceptance gate (GET /legal/status,
-- POST /legal/accept) so an Institution can evidence who agreed to what version.
--
-- Scope note: unlike most operational tables this is NOT school-scope-only — every
-- authenticated principal (parent, school staff, director/org, etc.) must be able to
-- record their own acceptance. The RLS policy therefore scopes each row to the
-- current tenant + the current user (app_current_user_id()), which is set for every
-- scope, rather than to app_current_scope() = 'school'. school_id is nullable for
-- org/director-scope users who carry no school_id.

CREATE TABLE legal_acceptances (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id UUID NOT NULL REFERENCES organizations (id),
  school_id UUID REFERENCES schools (id),
  user_id UUID NOT NULL,
  user_role TEXT NOT NULL,
  scope TEXT NOT NULL,
  policy_key TEXT NOT NULL,
  policy_version TEXT NOT NULL,
  accepted_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),
  ip_address TEXT,
  user_agent TEXT,
  device_id TEXT,
  -- One immutable record per (user, policy, version); re-accepting the same version
  -- is a no-op (idempotent ON CONFLICT in the handler).
  UNIQUE (user_id, policy_key, policy_version)
);

CREATE INDEX idx_legal_acceptances_user
  ON legal_acceptances (user_id);
CREATE INDEX idx_legal_acceptances_org_policy
  ON legal_acceptances (organization_id, policy_key, policy_version);

ALTER TABLE legal_acceptances ENABLE ROW LEVEL SECURITY;
ALTER TABLE legal_acceptances FORCE ROW LEVEL SECURITY;

-- Each user reads and writes only their own acceptance rows within their tenant.
CREATE POLICY legal_acceptances_self ON legal_acceptances
  FOR ALL
  USING (
    organization_id = app_current_tenant_id()
    AND user_id = app_current_user_id()
  )
  WITH CHECK (
    organization_id = app_current_tenant_id()
    AND user_id = app_current_user_id()
  );

-- Append-only ledger: SELECT + INSERT only (no UPDATE/DELETE) so acceptance
-- evidence cannot be silently altered through the tenant role.
GRANT SELECT, INSERT ON legal_acceptances TO erp_tenant;
