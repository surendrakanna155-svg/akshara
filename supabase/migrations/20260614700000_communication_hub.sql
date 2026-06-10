-- v7.1 Communication Hub — threads, broadcasts, notification delivery queue

CREATE TABLE notification_templates (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id UUID NOT NULL REFERENCES organizations (id),
  school_id UUID REFERENCES schools (id),
  code TEXT NOT NULL,
  channel TEXT NOT NULL,
  subject_template TEXT,
  body_template TEXT NOT NULL,
  variables JSONB NOT NULL DEFAULT '[]',
  is_active BOOLEAN NOT NULL DEFAULT true,
  created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),
  CONSTRAINT notification_templates_channel_check CHECK (
    channel IN ('sms', 'email', 'push')
  )
);

CREATE UNIQUE INDEX idx_notification_templates_code
  ON notification_templates (organization_id, COALESCE(school_id, '00000000-0000-4000-8000-000000000000'::uuid), code);

CREATE TABLE notification_deliveries (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id UUID NOT NULL REFERENCES organizations (id),
  school_id UUID REFERENCES schools (id),
  recipient_user_id UUID NOT NULL,
  channel TEXT NOT NULL,
  template_id UUID REFERENCES notification_templates (id),
  category TEXT NOT NULL DEFAULT 'announcement',
  rendered_subject TEXT,
  rendered_body TEXT NOT NULL,
  status TEXT NOT NULL DEFAULT 'pending',
  provider_ref TEXT,
  retry_count INTEGER NOT NULL DEFAULT 0,
  max_retries INTEGER NOT NULL DEFAULT 3,
  next_retry_at TIMESTAMPTZ,
  last_error TEXT,
  is_read BOOLEAN NOT NULL DEFAULT false,
  child_context TEXT,
  sent_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),
  CONSTRAINT notification_deliveries_channel_check CHECK (
    channel IN ('sms', 'email', 'push')
  ),
  CONSTRAINT notification_deliveries_status_check CHECK (
    status IN ('pending', 'sent', 'failed', 'cancelled')
  )
);

CREATE INDEX idx_notification_deliveries_recipient
  ON notification_deliveries (organization_id, recipient_user_id, status);
CREATE INDEX idx_notification_deliveries_retry
  ON notification_deliveries (status, next_retry_at)
  WHERE status = 'pending';

CREATE TABLE comm_threads (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id UUID NOT NULL REFERENCES organizations (id),
  school_id UUID NOT NULL REFERENCES schools (id),
  thread_type TEXT NOT NULL DEFAULT 'direct',
  subject TEXT,
  parent_user_id UUID,
  teacher_user_id UUID,
  student_id UUID,
  last_message_preview TEXT,
  unread_parent_count INTEGER NOT NULL DEFAULT 0,
  unread_teacher_count INTEGER NOT NULL DEFAULT 0,
  created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),
  CONSTRAINT comm_threads_type_check CHECK (thread_type IN ('direct', 'group'))
);

CREATE INDEX idx_comm_threads_participants
  ON comm_threads (organization_id, school_id, parent_user_id, teacher_user_id);

CREATE TABLE comm_messages (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  thread_id UUID NOT NULL REFERENCES comm_threads (id) ON DELETE CASCADE,
  organization_id UUID NOT NULL REFERENCES organizations (id),
  school_id UUID NOT NULL REFERENCES schools (id),
  sender_user_id UUID NOT NULL,
  sender_role TEXT NOT NULL,
  body TEXT NOT NULL,
  locale TEXT NOT NULL DEFAULT 'en',
  created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),
  CONSTRAINT comm_messages_sender_role_check CHECK (
    sender_role IN ('parent', 'teacher', 'staff', 'system')
  )
);

CREATE INDEX idx_comm_messages_thread ON comm_messages (thread_id, created_at);

CREATE TABLE comm_broadcasts (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id UUID NOT NULL REFERENCES organizations (id),
  school_id UUID REFERENCES schools (id),
  audience TEXT NOT NULL,
  title TEXT NOT NULL,
  body TEXT NOT NULL,
  status TEXT NOT NULL DEFAULT 'draft',
  scheduled_at TIMESTAMPTZ,
  sent_at TIMESTAMPTZ,
  created_by UUID NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),
  CONSTRAINT comm_broadcasts_audience_check CHECK (
    audience IN ('all_parents', 'all_teachers', 'all_students', 'school_wide')
  ),
  CONSTRAINT comm_broadcasts_status_check CHECK (
    status IN ('draft', 'scheduled', 'sending', 'sent', 'cancelled')
  )
);

CREATE TABLE comm_recipients (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  broadcast_id UUID NOT NULL REFERENCES comm_broadcasts (id) ON DELETE CASCADE,
  organization_id UUID NOT NULL REFERENCES organizations (id),
  user_id UUID NOT NULL,
  delivery_status TEXT NOT NULL DEFAULT 'pending',
  created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),
  CONSTRAINT comm_recipients_status_check CHECK (
    delivery_status IN ('pending', 'sent', 'failed', 'skipped')
  )
);

CREATE UNIQUE INDEX idx_comm_recipients_unique
  ON comm_recipients (broadcast_id, user_id);

CREATE TABLE comm_device_tokens (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id UUID NOT NULL REFERENCES organizations (id),
  user_id UUID NOT NULL,
  platform TEXT NOT NULL,
  token TEXT NOT NULL,
  is_active BOOLEAN NOT NULL DEFAULT true,
  created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),
  CONSTRAINT comm_device_tokens_platform_check CHECK (
    platform IN ('ios', 'android', 'web')
  )
);

CREATE UNIQUE INDEX idx_comm_device_tokens_user_platform
  ON comm_device_tokens (organization_id, user_id, platform, token);

CREATE TRIGGER notification_templates_updated_at
  BEFORE UPDATE ON notification_templates FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE TRIGGER notification_deliveries_updated_at
  BEFORE UPDATE ON notification_deliveries FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE TRIGGER comm_threads_updated_at
  BEFORE UPDATE ON comm_threads FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE TRIGGER comm_broadcasts_updated_at
  BEFORE UPDATE ON comm_broadcasts FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE TRIGGER comm_device_tokens_updated_at
  BEFORE UPDATE ON comm_device_tokens FOR EACH ROW EXECUTE FUNCTION set_updated_at();

ALTER TABLE notification_templates ENABLE ROW LEVEL SECURITY;
ALTER TABLE notification_templates FORCE ROW LEVEL SECURITY;
ALTER TABLE notification_deliveries ENABLE ROW LEVEL SECURITY;
ALTER TABLE notification_deliveries FORCE ROW LEVEL SECURITY;
ALTER TABLE comm_threads ENABLE ROW LEVEL SECURITY;
ALTER TABLE comm_threads FORCE ROW LEVEL SECURITY;
ALTER TABLE comm_messages ENABLE ROW LEVEL SECURITY;
ALTER TABLE comm_messages FORCE ROW LEVEL SECURITY;
ALTER TABLE comm_broadcasts ENABLE ROW LEVEL SECURITY;
ALTER TABLE comm_broadcasts FORCE ROW LEVEL SECURITY;
ALTER TABLE comm_recipients ENABLE ROW LEVEL SECURITY;
ALTER TABLE comm_recipients FORCE ROW LEVEL SECURITY;
ALTER TABLE comm_device_tokens ENABLE ROW LEVEL SECURITY;
ALTER TABLE comm_device_tokens FORCE ROW LEVEL SECURITY;

CREATE POLICY notification_templates_school_read ON notification_templates
  FOR SELECT USING (
    organization_id = app_current_tenant_id()
    AND app_current_scope() = 'school'
    AND (school_id IS NULL OR school_id = app_current_school_id())
  );

CREATE POLICY notification_deliveries_recipient ON notification_deliveries
  FOR ALL USING (
    organization_id = app_current_tenant_id()
    AND recipient_user_id = app_current_user_id()
    AND (
      (app_current_scope() = 'parent' AND school_id = app_current_school_id())
      OR (app_current_scope() = 'student' AND school_id = app_current_school_id())
      OR app_current_scope() = 'school'
    )
  ) WITH CHECK (
    organization_id = app_current_tenant_id()
    AND recipient_user_id = app_current_user_id()
  );

CREATE POLICY notification_deliveries_school_manage ON notification_deliveries
  FOR ALL USING (
    organization_id = app_current_tenant_id()
    AND app_current_scope() = 'school'
    AND school_id = app_current_school_id()
  );

CREATE POLICY comm_threads_participant ON comm_threads
  FOR ALL USING (
    organization_id = app_current_tenant_id()
    AND school_id = app_current_school_id()
    AND (
      (app_current_scope() = 'parent' AND parent_user_id = app_current_user_id())
      OR (app_current_scope() = 'school' AND teacher_user_id = app_current_user_id())
      OR app_current_scope() = 'school'
    )
  ) WITH CHECK (
    organization_id = app_current_tenant_id()
    AND school_id = app_current_school_id()
  );

CREATE POLICY comm_messages_thread ON comm_messages
  FOR ALL USING (
    organization_id = app_current_tenant_id()
    AND school_id = app_current_school_id()
    AND app_current_scope() IN ('parent', 'school')
  ) WITH CHECK (
    organization_id = app_current_tenant_id()
    AND school_id = app_current_school_id()
  );

CREATE POLICY comm_broadcasts_school ON comm_broadcasts
  FOR ALL USING (
    organization_id = app_current_tenant_id()
    AND (
      (app_current_scope() = 'school' AND (school_id IS NULL OR school_id = app_current_school_id()))
      OR (app_current_scope() = 'organization' AND school_id IS NULL)
    )
  );

CREATE POLICY comm_recipients_school ON comm_recipients
  FOR ALL USING (
    organization_id = app_current_tenant_id()
    AND app_current_scope() IN ('school', 'organization')
  );

CREATE POLICY comm_device_tokens_owner ON comm_device_tokens
  FOR ALL USING (
    organization_id = app_current_tenant_id()
    AND user_id = app_current_user_id()
  ) WITH CHECK (
    organization_id = app_current_tenant_id()
    AND user_id = app_current_user_id()
  );

GRANT SELECT, INSERT, UPDATE ON notification_templates TO erp_tenant;
GRANT SELECT, INSERT, UPDATE ON notification_deliveries TO erp_tenant;
GRANT SELECT, INSERT, UPDATE, DELETE ON comm_threads TO erp_tenant;
GRANT SELECT, INSERT, UPDATE, DELETE ON comm_messages TO erp_tenant;
GRANT SELECT, INSERT, UPDATE ON comm_broadcasts TO erp_tenant;
GRANT SELECT, INSERT, UPDATE ON comm_recipients TO erp_tenant;
GRANT SELECT, INSERT, UPDATE, DELETE ON comm_device_tokens TO erp_tenant;

-- Seed templates (School A)
INSERT INTO notification_templates (
  id, organization_id, school_id, code, channel, subject_template, body_template, variables
) VALUES (
  'd2500000-0000-4000-8000-000000000001',
  'a1000000-0000-4000-8000-000000000001',
  'a2000000-0000-4000-8000-000000000001',
  'fee_reminder_push',
  'push',
  'Fee reminder — {{term}}',
  '₹{{amount}} due by {{due_date}} for {{child_name}}.',
  '["term","amount","due_date","child_name"]'::jsonb
);

INSERT INTO notification_deliveries (
  id, organization_id, school_id, recipient_user_id, channel, template_id,
  category, rendered_subject, rendered_body, status, is_read, child_context, sent_at
) VALUES (
  'd2000000-0000-4000-8000-000000000001',
  'a1000000-0000-4000-8000-000000000001',
  'a2000000-0000-4000-8000-000000000001',
  'a3000000-0000-4000-8000-000000000003',
  'push',
  'd2500000-0000-4000-8000-000000000001',
  'fee',
  'Fee reminder — Term 2',
  '₹4200 due by 15 Jun for Ravi Kumar.',
  'sent',
  false,
  'Ravi · 8-A',
  timezone('utc', now())
);

INSERT INTO notification_deliveries (
  id, organization_id, school_id, recipient_user_id, channel,
  category, rendered_subject, rendered_body, status, is_read, child_context, sent_at
) VALUES (
  'd2000000-0000-4000-8000-000000000002',
  'a1000000-0000-4000-8000-000000000001',
  'a2000000-0000-4000-8000-000000000002',
  'a3000000-0000-4000-8000-000000000003',
  'push',
  'announcement',
  'School B probe',
  'Cross-school notification probe.',
  'sent',
  false,
  NULL,
  timezone('utc', now())
);

INSERT INTO comm_threads (
  id, organization_id, school_id, thread_type, subject,
  parent_user_id, teacher_user_id, student_id,
  last_message_preview, unread_parent_count, unread_teacher_count
) VALUES (
  'd1000000-0000-4000-8000-000000000001',
  'a1000000-0000-4000-8000-000000000001',
  'a2000000-0000-4000-8000-000000000001',
  'direct',
  'Homework Q5',
  'a3000000-0000-4000-8000-000000000003',
  'a3000000-0000-4000-8000-000000000004',
  'a4000000-0000-4000-8000-000000000001',
  'Could you share the homework solution steps?',
  0,
  1
);

INSERT INTO comm_threads (
  id, organization_id, school_id, thread_type, subject,
  parent_user_id, teacher_user_id, student_id,
  last_message_preview
) VALUES (
  'd1000000-0000-4000-8000-000000000002',
  'a1000000-0000-4000-8000-000000000001',
  'a2000000-0000-4000-8000-000000000002',
  'direct',
  'School B thread probe',
  'a3000000-0000-4000-8000-000000000003',
  'a3000000-0000-4000-8000-000000000005',
  'a4000000-0000-4000-8000-000000000002',
  'Cross-school thread probe.'
);

INSERT INTO comm_messages (
  id, thread_id, organization_id, school_id, sender_user_id, sender_role, body
) VALUES (
  'd1000000-0000-4000-8000-000000000011',
  'd1000000-0000-4000-8000-000000000001',
  'a1000000-0000-4000-8000-000000000001',
  'a2000000-0000-4000-8000-000000000001',
  'a3000000-0000-4000-8000-000000000003',
  'parent',
  'Could you share the homework solution steps for Q5?'
);
