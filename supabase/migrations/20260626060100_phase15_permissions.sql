-- Phase 15 permissions

INSERT INTO permissions (code, module, action, scope, description) VALUES
  ('viewCommunicationAnalytics', 'Communication', 'view', 'school', 'View communication analytics dashboards')
ON CONFLICT (code) DO NOTHING;

INSERT INTO role_permissions (role_code, permission_code) VALUES
  ('superAdmin', 'viewCommunicationAnalytics'),
  ('schoolAdmin', 'viewCommunicationAnalytics'),
  ('principal', 'viewCommunicationAnalytics')
ON CONFLICT DO NOTHING;
