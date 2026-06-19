-- Student leave approval is the class teacher's responsibility (a principal
-- can't approve hundreds of student leaves). Register the permission (it was
-- only referenced in code, never in the catalog) and grant it to oversight
-- roles plus the teacher; the edge handler additionally scopes a teacher to
-- their own class.

INSERT INTO permission_definitions (slug, module, action, scope, description) VALUES
  ('approveStudentLeave', 'Approvals', 'approve', 'school', 'Approve or reject a student leave request')
ON CONFLICT (slug) DO NOTHING;

INSERT INTO role_permissions (role_slug, permission_slug) VALUES
  ('superAdmin', 'approveStudentLeave'),
  ('schoolAdmin', 'approveStudentLeave'),
  ('principal', 'approveStudentLeave'),
  ('vicePrincipal', 'approveStudentLeave'),
  ('management', 'approveStudentLeave'),
  ('teacher', 'approveStudentLeave')
ON CONFLICT DO NOTHING;
