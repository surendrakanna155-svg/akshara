-- v6.0 Sprint 2 — Core platform schema (organizations, schools, users, memberships, auth)

CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- ─── Core tenant entities ───────────────────────────────────────────────────

CREATE TABLE organizations (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  slug TEXT NOT NULL UNIQUE,
  plan TEXT NOT NULL DEFAULT 'trial' CHECK (plan IN ('trial', 'standard', 'enterprise')),
  status TEXT NOT NULL DEFAULT 'active' CHECK (status IN ('trial', 'active', 'suspended', 'deleted')),
  settings JSONB NOT NULL DEFAULT '{}'::jsonb,
  created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),
  deleted_at TIMESTAMPTZ
);

CREATE TABLE schools (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id UUID NOT NULL REFERENCES organizations (id),
  name TEXT NOT NULL,
  code TEXT NOT NULL,
  settings JSONB NOT NULL DEFAULT '{}'::jsonb,
  created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),
  deleted_at TIMESTAMPTZ,
  UNIQUE (organization_id, code)
);

CREATE INDEX idx_schools_organization_id ON schools (organization_id);

CREATE TABLE users (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  phone TEXT NOT NULL UNIQUE,
  email TEXT,
  display_name TEXT NOT NULL DEFAULT '',
  profile JSONB NOT NULL DEFAULT '{}'::jsonb,
  created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),
  deleted_at TIMESTAMPTZ
);

CREATE TABLE organization_memberships (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users (id),
  organization_id UUID NOT NULL REFERENCES organizations (id),
  role TEXT NOT NULL,
  status TEXT NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'suspended', 'revoked')),
  permissions_version INTEGER NOT NULL DEFAULT 1,
  created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),
  UNIQUE (user_id, organization_id)
);

CREATE INDEX idx_org_memberships_org ON organization_memberships (organization_id);

CREATE TABLE school_memberships (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users (id),
  school_id UUID NOT NULL REFERENCES schools (id),
  role TEXT NOT NULL,
  status TEXT NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'suspended', 'revoked')),
  permissions_version INTEGER NOT NULL DEFAULT 1,
  created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),
  UNIQUE (user_id, school_id)
);

CREATE INDEX idx_school_memberships_school ON school_memberships (school_id);

-- ─── Authentication ─────────────────────────────────────────────────────────

CREATE TABLE otp_requests (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  phone TEXT NOT NULL,
  otp_hash TEXT NOT NULL,
  organization_slug TEXT,
  attempts INTEGER NOT NULL DEFAULT 0,
  expires_at TIMESTAMPTZ NOT NULL,
  consumed_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now())
);

CREATE INDEX idx_otp_requests_phone_created ON otp_requests (phone, created_at DESC);

CREATE TABLE sessions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users (id),
  tenant_id UUID NOT NULL REFERENCES organizations (id),
  device_type TEXT,
  device_name TEXT,
  ip_address INET,
  user_agent TEXT,
  last_active_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),
  revoked_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now())
);

CREATE INDEX idx_sessions_user_id ON sessions (user_id);

CREATE TABLE refresh_tokens (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  session_id UUID NOT NULL REFERENCES sessions (id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES users (id),
  token_hash TEXT NOT NULL UNIQUE,
  family_id UUID NOT NULL DEFAULT gen_random_uuid(),
  used_at TIMESTAMPTZ,
  revoked_at TIMESTAMPTZ,
  expires_at TIMESTAMPTZ NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now())
);

CREATE INDEX idx_refresh_tokens_session ON refresh_tokens (session_id);
CREATE INDEX idx_refresh_tokens_user ON refresh_tokens (user_id);

-- ─── Updated-at triggers ────────────────────────────────────────────────────

CREATE OR REPLACE FUNCTION set_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = timezone('utc', now());
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER organizations_updated_at
  BEFORE UPDATE ON organizations
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER schools_updated_at
  BEFORE UPDATE ON schools
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER users_updated_at
  BEFORE UPDATE ON users
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();
