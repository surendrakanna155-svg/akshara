-- Phase 16 permissions

INSERT INTO permissions (code, module, action, scope, description) VALUES
  ('viewTeacherEffectiveness', 'Intelligence', 'view', 'school', 'View teacher effectiveness analytics and planning center')
ON CONFLICT (code) DO NOTHING;

INSERT INTO role_permissions (role_code, permission_code) VALUES
  ('superAdmin', 'viewTeacherEffectiveness'),
  ('schoolAdmin', 'viewTeacherEffectiveness'),
  ('principal', 'viewTeacherEffectiveness'),
  ('teacher', 'viewTeacherEffectiveness')
ON CONFLICT DO NOTHING;
