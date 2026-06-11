-- Phase 10 permissions

INSERT INTO permissions (code, module, action, scope, description) VALUES
  ('manageSyllabus', 'Academic', 'manage', 'school', 'Manage syllabus generation and templates'),
  ('viewAcademicProgress', 'Academic', 'view', 'school', 'View academic progress dashboards'),
  ('manageAcademicProgress', 'Academic', 'manage', 'school', 'Record topic and chapter completion'),
  ('managePlatformProviders', 'Platform', 'manage', 'organization', 'Manage AI/WhatsApp/SMS providers (super admin)'),
  ('viewPlatformUsage', 'Platform', 'view', 'organization', 'View platform usage and cost analytics'),
  ('managePlatformVault', 'Platform', 'manage', 'organization', 'Manage encrypted provider credentials'),
  ('managePlatformFeatures', 'Platform', 'manage', 'organization', 'Enable/disable features per school'),
  ('manageAcademicRooms', 'Academic', 'manage', 'school', 'Manage rooms and exam timetables'),
  ('viewParentAcademicSummary', 'Parent', 'view', 'school', 'View structured parent academic summary')
ON CONFLICT (code) DO NOTHING;

INSERT INTO role_permissions (role_code, permission_code) VALUES
  ('superAdmin', 'manageSyllabus'),
  ('superAdmin', 'viewAcademicProgress'),
  ('superAdmin', 'manageAcademicProgress'),
  ('superAdmin', 'managePlatformProviders'),
  ('superAdmin', 'viewPlatformUsage'),
  ('superAdmin', 'managePlatformVault'),
  ('superAdmin', 'managePlatformFeatures'),
  ('superAdmin', 'manageAcademicRooms'),
  ('superAdmin', 'viewParentAcademicSummary'),
  ('schoolAdmin', 'manageSyllabus'),
  ('schoolAdmin', 'viewAcademicProgress'),
  ('schoolAdmin', 'manageAcademicProgress'),
  ('schoolAdmin', 'manageAcademicRooms'),
  ('schoolAdmin', 'viewParentAcademicSummary'),
  ('principal', 'manageSyllabus'),
  ('principal', 'viewAcademicProgress'),
  ('principal', 'manageAcademicProgress'),
  ('principal', 'manageAcademicRooms'),
  ('principal', 'viewParentAcademicSummary'),
  ('teacher', 'viewAcademicProgress'),
  ('teacher', 'manageAcademicProgress'),
  ('parent', 'viewParentAcademicSummary')
ON CONFLICT DO NOTHING;
