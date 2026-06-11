-- Phase 15 permissions

INSERT INTO permission_definitions (slug, module, action, scope, description) VALUES
  ('viewCommunicationAnalytics', 'Communication', 'view', 'school', 'View communication analytics dashboards')
ON CONFLICT (slug) DO NOTHING;

INSERT INTO role_permissions (role_slug, permission_slug) VALUES
  ('superAdmin', 'viewCommunicationAnalytics'),
  ('schoolAdmin', 'viewCommunicationAnalytics'),
  ('principal', 'viewCommunicationAnalytics')
ON CONFLICT DO NOTHING;
