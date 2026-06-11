-- Phase 9 permissions

INSERT INTO permissions (code, module, action, scope, description) VALUES
  ('viewSubjectAssignments', 'Academic', 'view', 'school', 'View class and teacher subject assignments'),
  ('manageSubjectAssignments', 'Academic', 'manage', 'school', 'Manage class and teacher subject assignments'),
  ('viewLessonAnalytics', 'Teacher', 'view', 'school', 'View lesson and syllabus analytics'),
  ('viewTimetableOptimization', 'Academic', 'view', 'school', 'View timetable optimization insights'),
  ('viewCommunicationDelivery', 'Communication', 'view', 'school', 'View communication delivery analytics'),
  ('manageCommunicationTemplates', 'Communication', 'manage', 'school', 'Manage school communication templates'),
  ('viewPilotDashboard', 'Onboarding', 'view', 'school', 'View real-school pilot dashboard'),
  ('managePlatformWhatsApp', 'Platform', 'manage', 'organization', 'Manage platform WhatsApp provider (super admin only)')
ON CONFLICT (code) DO NOTHING;

-- Revoke school-level WhatsApp provider management from school roles (v12.5)
DELETE FROM role_permissions
WHERE permission_code = 'manageWhatsAppProvider'
  AND role_code IN ('schoolAdmin', 'principal');

INSERT INTO role_permissions (role_code, permission_code) VALUES
  ('superAdmin', 'viewSubjectAssignments'),
  ('superAdmin', 'manageSubjectAssignments'),
  ('superAdmin', 'viewLessonAnalytics'),
  ('superAdmin', 'viewTimetableOptimization'),
  ('superAdmin', 'viewCommunicationDelivery'),
  ('superAdmin', 'manageCommunicationTemplates'),
  ('superAdmin', 'viewPilotDashboard'),
  ('superAdmin', 'managePlatformWhatsApp'),
  ('schoolAdmin', 'viewSubjectAssignments'),
  ('schoolAdmin', 'manageSubjectAssignments'),
  ('schoolAdmin', 'viewLessonAnalytics'),
  ('schoolAdmin', 'viewTimetableOptimization'),
  ('schoolAdmin', 'viewCommunicationDelivery'),
  ('schoolAdmin', 'manageCommunicationTemplates'),
  ('schoolAdmin', 'viewPilotDashboard'),
  ('schoolAdmin', 'viewWhatsAppProvider'),
  ('principal', 'viewSubjectAssignments'),
  ('principal', 'manageSubjectAssignments'),
  ('principal', 'viewLessonAnalytics'),
  ('principal', 'viewTimetableOptimization'),
  ('principal', 'viewCommunicationDelivery'),
  ('principal', 'manageCommunicationTemplates'),
  ('principal', 'viewPilotDashboard'),
  ('principal', 'viewWhatsAppProvider'),
  ('teacher', 'viewSubjectAssignments'),
  ('teacher', 'viewLessonAnalytics')
ON CONFLICT DO NOTHING;
