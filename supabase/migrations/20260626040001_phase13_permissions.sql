-- Phase 13 permissions — Student Success Intelligence

INSERT INTO permission_definitions (slug, module, action, scope, description) VALUES
  ('viewStudentSuccessIntelligence', 'Intelligence', 'view', 'school', 'View student success predictions and intervention tracking')
ON CONFLICT (slug) DO NOTHING;

INSERT INTO role_permissions (role_slug, permission_slug) VALUES
  ('superAdmin', 'viewStudentSuccessIntelligence'),
  ('schoolAdmin', 'viewStudentSuccessIntelligence'),
  ('principal', 'viewStudentSuccessIntelligence'),
  ('teacher', 'viewStudentSuccessIntelligence'),
  ('management', 'viewStudentSuccessIntelligence')
ON CONFLICT DO NOTHING;
