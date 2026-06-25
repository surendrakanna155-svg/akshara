-- Social Media Integration (Phase 2) — Meta (Facebook/Instagram) connections.
--
-- Extends the Marketing Publisher: a school connects a Meta account, selects a
-- Facebook Page (+ linked Instagram Business account), and the publisher then posts
-- to the selected channels via the Graph API. OAuth access tokens are stored
-- ENCRYPTED (AES-256-GCM, see social_token_crypto.ts) — never in clear text.

CREATE TABLE social_media_connections (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id UUID NOT NULL REFERENCES organizations (id),
  school_id UUID NOT NULL REFERENCES schools (id),
  page_id TEXT NOT NULL,
  page_name TEXT NOT NULL,
  ig_business_id TEXT,
  ig_username TEXT,
  encrypted_page_token TEXT NOT NULL,
  token_expires_at TIMESTAMPTZ,
  scopes JSONB NOT NULL DEFAULT '[]'::jsonb,
  status TEXT NOT NULL DEFAULT 'connected',
  connected_by UUID NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),
  CONSTRAINT social_media_connections_status_check CHECK (status IN ('connected', 'revoked')),
  UNIQUE (organization_id, school_id, page_id)
);

CREATE INDEX idx_social_media_connections_school
  ON social_media_connections (organization_id, school_id, status);

CREATE TRIGGER social_media_connections_updated_at
  BEFORE UPDATE ON social_media_connections
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

ALTER TABLE social_media_connections ENABLE ROW LEVEL SECURITY;
ALTER TABLE social_media_connections FORCE ROW LEVEL SECURITY;

CREATE POLICY social_media_connections_school_scope ON social_media_connections
  FOR ALL
  USING (
    organization_id = app_current_tenant_id()
    AND school_id = app_current_school_id()
  )
  WITH CHECK (
    organization_id = app_current_tenant_id()
    AND school_id = app_current_school_id()
  );

GRANT SELECT, INSERT, UPDATE, DELETE ON social_media_connections TO erp_tenant;

INSERT INTO permission_definitions (slug, module, action, scope, description) VALUES
  ('viewSocialConnections', 'Social', 'view', 'school', 'View connected social media accounts'),
  ('manageSocialConnections', 'Social', 'manage', 'school', 'Connect/disconnect social media accounts')
ON CONFLICT (slug) DO NOTHING;

INSERT INTO role_permissions (role_slug, permission_slug) VALUES
  ('superAdmin', 'viewSocialConnections'),
  ('superAdmin', 'manageSocialConnections'),
  ('schoolAdmin', 'viewSocialConnections'),
  ('schoolAdmin', 'manageSocialConnections'),
  ('principal', 'viewSocialConnections'),
  ('principal', 'manageSocialConnections')
ON CONFLICT (role_slug, permission_slug) DO NOTHING;
