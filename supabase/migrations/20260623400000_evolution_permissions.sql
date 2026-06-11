-- v10.5–v11.0 Evolution permissions

INSERT INTO permissions (code, module, action, scope, description) VALUES
  ('viewSchoolSetup', 'Setup', 'view', 'school', 'View school setup wizard'),
  ('manageSchoolSetup', 'Setup', 'manage', 'school', 'Run school setup wizard'),
  ('viewDynamicWidgets', 'Dashboard', 'view', 'school', 'View dynamic dashboards'),
  ('manageDynamicWidgets', 'Dashboard', 'manage', 'school', 'Configure dashboard layouts'),
  ('viewTeacherAssistant', 'Teacher', 'view', 'school', 'View teacher assistant insights'),
  ('manageTeacherAssistant', 'Teacher', 'manage', 'school', 'Manage teacher interventions'),
  ('viewParentInsights', 'Parent', 'view', 'school', 'View parent insights center'),
  ('viewPrincipalCommand', 'Principal', 'view', 'school', 'View principal command center'),
  ('viewGrowthPlatform', 'Growth', 'view', 'school', 'View admissions growth analytics'),
  ('manageGrowthPlatform', 'Growth', 'manage', 'school', 'Manage growth campaigns and inquiries')
ON CONFLICT (code) DO NOTHING;

INSERT INTO role_permissions (role_code, permission_code) VALUES
  ('superAdmin', 'viewSchoolSetup'),
  ('superAdmin', 'manageSchoolSetup'),
  ('superAdmin', 'viewDynamicWidgets'),
  ('superAdmin', 'manageDynamicWidgets'),
  ('superAdmin', 'viewTeacherAssistant'),
  ('superAdmin', 'manageTeacherAssistant'),
  ('superAdmin', 'viewParentInsights'),
  ('superAdmin', 'viewPrincipalCommand'),
  ('superAdmin', 'viewGrowthPlatform'),
  ('superAdmin', 'manageGrowthPlatform'),
  ('schoolAdmin', 'viewSchoolSetup'),
  ('schoolAdmin', 'manageSchoolSetup'),
  ('schoolAdmin', 'viewDynamicWidgets'),
  ('schoolAdmin', 'manageDynamicWidgets'),
  ('schoolAdmin', 'viewTeacherAssistant'),
  ('schoolAdmin', 'manageTeacherAssistant'),
  ('schoolAdmin', 'viewParentInsights'),
  ('schoolAdmin', 'viewPrincipalCommand'),
  ('schoolAdmin', 'viewGrowthPlatform'),
  ('schoolAdmin', 'manageGrowthPlatform'),
  ('principal', 'viewSchoolSetup'),
  ('principal', 'manageSchoolSetup'),
  ('principal', 'viewDynamicWidgets'),
  ('principal', 'manageDynamicWidgets'),
  ('principal', 'viewTeacherAssistant'),
  ('principal', 'viewParentInsights'),
  ('principal', 'viewPrincipalCommand'),
  ('principal', 'viewGrowthPlatform'),
  ('principal', 'manageGrowthPlatform'),
  ('teacher', 'viewTeacherAssistant'),
  ('teacher', 'manageTeacherAssistant'),
  ('parent', 'viewParentInsights')
ON CONFLICT DO NOTHING;
