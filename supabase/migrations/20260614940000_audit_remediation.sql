-- v7.3 audit remediation — RBAC seeds, webhook RLS, probe seeds

INSERT INTO permission_definitions (slug, module, action, scope, description) VALUES
  ('viewCommunications', 'Communications', 'view', 'school', 'View communication threads and notifications'),
  ('manageCommunications', 'Communications', 'manage', 'school', 'Manage notification queue and domain event processing'),
  ('sendBroadcast', 'Communications', 'manage', 'school', 'Send broadcast messages'),
  ('viewPayments', 'Payments', 'view', 'school', 'View payment intents and requests')
ON CONFLICT (slug) DO NOTHING;

INSERT INTO role_permissions (role_slug, permission_slug) VALUES
  ('superAdmin', 'viewOnboarding'),
  ('superAdmin', 'manageOnboarding'),
  ('superAdmin', 'viewCommunications'),
  ('superAdmin', 'manageCommunications'),
  ('superAdmin', 'sendBroadcast'),
  ('superAdmin', 'viewPayments'),
  ('schoolAdmin', 'viewCommunications'),
  ('schoolAdmin', 'manageCommunications'),
  ('schoolAdmin', 'sendBroadcast'),
  ('schoolAdmin', 'viewPayments'),
  ('principal', 'viewCommunications'),
  ('principal', 'sendBroadcast'),
  ('principal', 'viewPayments'),
  ('financeAdmin', 'viewPayments'),
  ('financeManager', 'viewPayments')
ON CONFLICT DO NOTHING;

DROP POLICY IF EXISTS payment_webhook_events_service ON payment_webhook_events;

CREATE POLICY payment_webhook_events_tenant ON payment_webhook_events
  FOR ALL USING (
    resolved_organization_id = app_current_tenant_id()
    AND app_current_scope() IN ('school', 'organization')
    AND (
      app_current_scope() = 'organization'
      OR resolved_school_id = app_current_school_id()
    )
  ) WITH CHECK (
    resolved_organization_id = app_current_tenant_id()
    AND app_current_scope() IN ('school', 'organization')
    AND (
      app_current_scope() = 'organization'
      OR resolved_school_id = app_current_school_id()
    )
  );

-- Tenant isolation probe seeds for payment_webhook_events
INSERT INTO payment_webhook_events (
  id, organization_id, event_type, payload,
  resolved_organization_id, resolved_school_id
) VALUES (
  'd0300000-0000-4000-8000-000000000001',
  'a1000000-0000-4000-8000-000000000001',
  'payment.captured',
  '{"probe": true}'::jsonb,
  'a1000000-0000-4000-8000-000000000001',
  'a2000000-0000-4000-8000-000000000001'
), (
  'd0300000-0000-4000-8000-000000000002',
  'a1000000-0000-4000-8000-000000000001',
  'payment.captured',
  '{"probe": true}'::jsonb,
  'a1000000-0000-4000-8000-000000000001',
  'a2000000-0000-4000-8000-000000000002'
) ON CONFLICT (id) DO NOTHING;
