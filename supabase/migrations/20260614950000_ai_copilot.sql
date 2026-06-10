-- v7.4 — AI Copilot foundation (sessions, messages, RBAC)

CREATE TABLE ai_copilot_sessions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id UUID NOT NULL REFERENCES organizations (id),
  school_id UUID NOT NULL REFERENCES schools (id),
  user_id UUID NOT NULL REFERENCES users (id),
  assistant_type TEXT NOT NULL
    CHECK (assistant_type IN ('admissions', 'finance', 'sis', 'academic', 'communication')),
  title TEXT NOT NULL DEFAULT 'New conversation',
  status TEXT NOT NULL DEFAULT 'active'
    CHECK (status IN ('active', 'archived')),
  created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now())
);

CREATE TABLE ai_copilot_messages (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  session_id UUID NOT NULL REFERENCES ai_copilot_sessions (id) ON DELETE CASCADE,
  organization_id UUID NOT NULL REFERENCES organizations (id),
  school_id UUID NOT NULL REFERENCES schools (id),
  role TEXT NOT NULL CHECK (role IN ('user', 'assistant', 'system')),
  content TEXT NOT NULL,
  metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
  created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now())
);

CREATE INDEX idx_ai_copilot_sessions_user ON ai_copilot_sessions (user_id, updated_at DESC);
CREATE INDEX idx_ai_copilot_messages_session ON ai_copilot_messages (session_id, created_at ASC);

CREATE TRIGGER ai_copilot_sessions_updated_at BEFORE UPDATE ON ai_copilot_sessions
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

ALTER TABLE ai_copilot_sessions ENABLE ROW LEVEL SECURITY;
ALTER TABLE ai_copilot_sessions FORCE ROW LEVEL SECURITY;
ALTER TABLE ai_copilot_messages ENABLE ROW LEVEL SECURITY;
ALTER TABLE ai_copilot_messages FORCE ROW LEVEL SECURITY;

CREATE POLICY ai_copilot_sessions_school ON ai_copilot_sessions
  FOR ALL USING (
    organization_id = app_current_tenant_id()
    AND school_id = app_current_school_id()
    AND user_id = app_current_user_id()
    AND app_current_scope() IN ('school', 'organization')
  );

CREATE POLICY ai_copilot_messages_school ON ai_copilot_messages
  FOR ALL USING (
    organization_id = app_current_tenant_id()
    AND school_id = app_current_school_id()
    AND app_current_scope() IN ('school', 'organization')
    AND session_id IN (
      SELECT id FROM ai_copilot_sessions
      WHERE user_id = app_current_user_id()
        AND organization_id = app_current_tenant_id()
        AND school_id = app_current_school_id()
    )
  );

GRANT SELECT, INSERT, UPDATE ON ai_copilot_sessions TO erp_tenant;
GRANT SELECT, INSERT ON ai_copilot_messages TO erp_tenant;

INSERT INTO permission_definitions (slug, module, action, scope, description) VALUES
  ('viewAiCopilot', 'AiCopilot', 'view', 'school', 'View AI Copilot conversations'),
  ('runAiCopilot', 'AiCopilot', 'run', 'school', 'Send read-only prompts to AI Copilot assistants')
ON CONFLICT (slug) DO NOTHING;

INSERT INTO role_permissions (role_slug, permission_slug) VALUES
  ('superAdmin', 'viewAiCopilot'),
  ('superAdmin', 'runAiCopilot'),
  ('schoolAdmin', 'viewAiCopilot'),
  ('schoolAdmin', 'runAiCopilot'),
  ('principal', 'viewAiCopilot'),
  ('principal', 'runAiCopilot'),
  ('financeAdmin', 'viewAiCopilot'),
  ('financeAdmin', 'runAiCopilot'),
  ('financeManager', 'viewAiCopilot'),
  ('financeManager', 'runAiCopilot'),
  ('admissionsCounselor', 'viewAiCopilot'),
  ('admissionsCounselor', 'runAiCopilot')
ON CONFLICT DO NOTHING;

-- Tenant isolation probe seeds
INSERT INTO ai_copilot_sessions (
  id, organization_id, school_id, user_id, assistant_type, title
) VALUES (
  'd0400000-0000-4000-8000-000000000001',
  'a1000000-0000-4000-8000-000000000001',
  'a2000000-0000-4000-8000-000000000001',
  'b1000000-0000-4000-8000-000000000001',
  'finance',
  'Probe session A'
), (
  'd0400000-0000-4000-8000-000000000002',
  'a1000000-0000-4000-8000-000000000001',
  'a2000000-0000-4000-8000-000000000002',
  'b1000000-0000-4000-8000-000000000002',
  'finance',
  'Probe session B'
) ON CONFLICT (id) DO NOTHING;
