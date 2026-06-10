-- v7.15 Phase A — School Data Migration & Onboarding

ALTER TABLE otp_requests
  ADD COLUMN IF NOT EXISTS identifier_type TEXT NOT NULL DEFAULT 'phone',
  ADD COLUMN IF NOT EXISTS identifier_value TEXT,
  ADD COLUMN IF NOT EXISTS context_school_id UUID REFERENCES schools (id),
  ADD COLUMN IF NOT EXISTS context_student_id UUID REFERENCES students (id);

CREATE TABLE onboarding_import_jobs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id UUID NOT NULL REFERENCES organizations (id),
  school_id UUID NOT NULL REFERENCES schools (id),
  import_type TEXT NOT NULL CHECK (import_type IN ('student', 'teacher')),
  status TEXT NOT NULL DEFAULT 'draft'
    CHECK (status IN ('draft', 'previewed', 'committed', 'rolled_back', 'failed')),
  file_name TEXT NOT NULL DEFAULT '',
  total_rows INTEGER NOT NULL DEFAULT 0,
  valid_rows INTEGER NOT NULL DEFAULT 0,
  invalid_rows INTEGER NOT NULL DEFAULT 0,
  duplicate_rows INTEGER NOT NULL DEFAULT 0,
  committed_rows INTEGER NOT NULL DEFAULT 0,
  created_by UUID NOT NULL REFERENCES users (id),
  rollback_of_job_id UUID REFERENCES onboarding_import_jobs (id),
  report JSONB NOT NULL DEFAULT '{}'::jsonb,
  created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now())
);

CREATE INDEX idx_onboarding_import_jobs_school ON onboarding_import_jobs (school_id, import_type, status);

CREATE TABLE onboarding_import_rows (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  job_id UUID NOT NULL REFERENCES onboarding_import_jobs (id) ON DELETE CASCADE,
  organization_id UUID NOT NULL REFERENCES organizations (id),
  school_id UUID NOT NULL REFERENCES schools (id),
  row_number INTEGER NOT NULL,
  payload JSONB NOT NULL DEFAULT '{}'::jsonb,
  status TEXT NOT NULL DEFAULT 'pending'
    CHECK (status IN ('pending', 'valid', 'invalid', 'duplicate', 'committed', 'rolled_back')),
  errors JSONB NOT NULL DEFAULT '[]'::jsonb,
  matched_entity_id UUID,
  created_entity_id UUID,
  created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),
  UNIQUE (job_id, row_number)
);

CREATE INDEX idx_onboarding_import_rows_job ON onboarding_import_rows (job_id, status);

CREATE TABLE onboarding_invites (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id UUID NOT NULL REFERENCES organizations (id),
  school_id UUID NOT NULL REFERENCES schools (id),
  invite_type TEXT NOT NULL CHECK (invite_type IN ('parent', 'teacher', 'student')),
  recipient_phone TEXT NOT NULL,
  recipient_label TEXT NOT NULL DEFAULT '',
  student_id UUID REFERENCES students (id),
  user_id UUID REFERENCES users (id),
  token TEXT NOT NULL UNIQUE,
  status TEXT NOT NULL DEFAULT 'pending'
    CHECK (status IN ('pending', 'sent', 'opened', 'accepted', 'expired', 'failed')),
  channel TEXT NOT NULL DEFAULT 'sms' CHECK (channel IN ('sms', 'whatsapp', 'push')),
  deep_link TEXT NOT NULL DEFAULT '',
  sent_at TIMESTAMPTZ,
  opened_at TIMESTAMPTZ,
  accepted_at TIMESTAMPTZ,
  expires_at TIMESTAMPTZ NOT NULL,
  created_by UUID NOT NULL REFERENCES users (id),
  created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now())
);

CREATE INDEX idx_onboarding_invites_school ON onboarding_invites (school_id, status);
CREATE INDEX idx_onboarding_invites_phone ON onboarding_invites (recipient_phone);

CREATE TRIGGER onboarding_import_jobs_updated_at
  BEFORE UPDATE ON onboarding_import_jobs
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER onboarding_invites_updated_at
  BEFORE UPDATE ON onboarding_invites
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

ALTER TABLE onboarding_import_jobs ENABLE ROW LEVEL SECURITY;
ALTER TABLE onboarding_import_jobs FORCE ROW LEVEL SECURITY;
ALTER TABLE onboarding_import_rows ENABLE ROW LEVEL SECURITY;
ALTER TABLE onboarding_import_rows FORCE ROW LEVEL SECURITY;
ALTER TABLE onboarding_invites ENABLE ROW LEVEL SECURITY;
ALTER TABLE onboarding_invites FORCE ROW LEVEL SECURITY;

CREATE POLICY onboarding_import_jobs_school ON onboarding_import_jobs
  FOR ALL USING (
    organization_id = app_current_tenant_id()
    AND school_id = app_current_school_id()
    AND app_current_scope() IN ('school', 'organization')
  );

CREATE POLICY onboarding_import_rows_school ON onboarding_import_rows
  FOR ALL USING (
    organization_id = app_current_tenant_id()
    AND school_id = app_current_school_id()
    AND app_current_scope() IN ('school', 'organization')
  );

CREATE POLICY onboarding_invites_school ON onboarding_invites
  FOR ALL USING (
    organization_id = app_current_tenant_id()
    AND school_id = app_current_school_id()
    AND app_current_scope() IN ('school', 'organization')
  );

GRANT SELECT, INSERT, UPDATE ON onboarding_import_jobs TO erp_tenant;
GRANT SELECT, INSERT, UPDATE, DELETE ON onboarding_import_rows TO erp_tenant;
GRANT SELECT, INSERT, UPDATE ON onboarding_invites TO erp_tenant;

INSERT INTO permission_definitions (slug, module, action, scope, description) VALUES
  ('viewOnboarding', 'Onboarding', 'view', 'school', 'View school onboarding imports and invites'),
  ('manageOnboarding', 'Onboarding', 'manage', 'school', 'Manage school onboarding imports and invites')
ON CONFLICT (slug) DO NOTHING;

INSERT INTO role_permissions (role_slug, permission_slug) VALUES
  ('schoolAdmin', 'viewOnboarding'),
  ('schoolAdmin', 'manageOnboarding'),
  ('principal', 'viewOnboarding'),
  ('principal', 'manageOnboarding')
ON CONFLICT DO NOTHING;

-- Tenant isolation probe seeds (School B must not see School A job)
INSERT INTO onboarding_import_jobs (
  id, organization_id, school_id, import_type, status, file_name,
  total_rows, valid_rows, created_by
) VALUES (
  'd7000000-0000-4000-8000-000000000001',
  'a1000000-0000-4000-8000-000000000001',
  'a2000000-0000-4000-8000-000000000001',
  'student', 'previewed', 'probe_students_a.csv', 1, 1,
  'a3000000-0000-4000-8000-000000000001'
), (
  'd7000000-0000-4000-8000-000000000002',
  'a1000000-0000-4000-8000-000000000001',
  'a2000000-0000-4000-8000-000000000002',
  'student', 'previewed', 'probe_students_b.csv', 1, 1,
  'a3000000-0000-4000-8000-000000000001'
) ON CONFLICT (id) DO NOTHING;

INSERT INTO onboarding_invites (
  id, organization_id, school_id, invite_type, recipient_phone, recipient_label,
  token, status, channel, deep_link, expires_at, created_by
) VALUES (
  'd7100000-0000-4000-8000-000000000001',
  'a1000000-0000-4000-8000-000000000001',
  'a2000000-0000-4000-8000-000000000001',
  'parent', '+919876543211', 'Probe Parent A',
  'probe_invite_a', 'sent', 'whatsapp', 'https://app.akshara.test/invite/probe_invite_a',
  timezone('utc', now()) + interval '7 days',
  'a3000000-0000-4000-8000-000000000001'
), (
  'd7100000-0000-4000-8000-000000000002',
  'a1000000-0000-4000-8000-000000000001',
  'a2000000-0000-4000-8000-000000000002',
  'parent', '+919876543212', 'Probe Parent B',
  'probe_invite_b', 'sent', 'whatsapp', 'https://app.akshara.test/invite/probe_invite_b',
  timezone('utc', now()) + interval '7 days',
  'a3000000-0000-4000-8000-000000000001'
) ON CONFLICT (id) DO NOTHING;
