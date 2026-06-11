-- Phase 13 permissions — Student Success Intelligence

INSERT INTO permissions (code, module, action, scope, description) VALUES
  ('viewStudentSuccessIntelligence', 'Intelligence', 'view', 'school', 'View student success predictions and intervention tracking')
ON CONFLICT (code) DO NOTHING;

INSERT INTO role_permissions (role_code, permission_code) VALUES
  ('superAdmin', 'viewStudentSuccessIntelligence'),
  ('schoolAdmin', 'viewStudentSuccessIntelligence'),
  ('principal', 'viewStudentSuccessIntelligence'),
  ('teacher', 'viewStudentSuccessIntelligence'),
  ('management', 'viewStudentSuccessIntelligence')
ON CONFLICT DO NOTHING;
