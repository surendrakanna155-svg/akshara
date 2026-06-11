-- v8.5–v8.8 Education Suite RBAC permissions

INSERT INTO permission_definitions (slug, module, action, scope, description) VALUES
  ('viewEducation', 'Education', 'view', 'school', 'View question papers, question bank, homework, and report remarks'),
  ('manageEducation', 'Education', 'manage', 'school', 'Generate and publish education content')
ON CONFLICT (slug) DO NOTHING;

INSERT INTO role_permissions (role_slug, permission_slug) VALUES
  ('superAdmin', 'viewEducation'),
  ('superAdmin', 'manageEducation'),
  ('schoolAdmin', 'viewEducation'),
  ('schoolAdmin', 'manageEducation'),
  ('principal', 'viewEducation'),
  ('principal', 'manageEducation'),
  ('teacher', 'viewEducation'),
  ('teacher', 'manageEducation')
ON CONFLICT DO NOTHING;
