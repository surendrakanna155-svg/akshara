-- Intelligence Layer RBAC (v8.9–v9.3)

INSERT INTO permission_definitions (slug, module, action, scope, description) VALUES
  ('viewStudentRisk', 'Intelligence', 'view', 'school', 'View student risk dashboards and alerts'),
  ('generateIntelligence', 'Intelligence', 'manage', 'school', 'Generate risk scores, messages, and guidance reports')
ON CONFLICT (slug) DO NOTHING;

INSERT INTO role_permissions (role_slug, permission_slug) VALUES
  ('superAdmin', 'viewStudentRisk'),
  ('superAdmin', 'generateIntelligence'),
  ('schoolAdmin', 'viewStudentRisk'),
  ('schoolAdmin', 'generateIntelligence'),
  ('principal', 'viewStudentRisk'),
  ('principal', 'generateIntelligence'),
  ('teacher', 'viewStudentRisk'),
  ('teacher', 'generateIntelligence'),
  ('management', 'viewStudentRisk'),
  ('management', 'generateIntelligence')
ON CONFLICT DO NOTHING;
