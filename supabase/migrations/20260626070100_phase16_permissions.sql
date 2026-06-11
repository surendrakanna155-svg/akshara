-- Phase 16 permissions

INSERT INTO permission_definitions (slug, module, action, scope, description) VALUES
  ('viewTeacherEffectiveness', 'Intelligence', 'view', 'school', 'View teacher effectiveness analytics and planning center')
ON CONFLICT (slug) DO NOTHING;

INSERT INTO role_permissions (role_slug, permission_slug) VALUES
  ('superAdmin', 'viewTeacherEffectiveness'),
  ('schoolAdmin', 'viewTeacherEffectiveness'),
  ('principal', 'viewTeacherEffectiveness'),
  ('teacher', 'viewTeacherEffectiveness')
ON CONFLICT DO NOTHING;
