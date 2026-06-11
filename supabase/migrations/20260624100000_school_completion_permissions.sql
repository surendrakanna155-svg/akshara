-- Phase 8 — School Completion permissions

INSERT INTO permissions (code, module, action, scope, description) VALUES
  ('viewSubjects', 'Academic', 'view', 'school', 'View academic subject catalog'),
  ('manageSubjects', 'Academic', 'manage', 'school', 'Manage academic subjects'),
  ('viewLessonLogs', 'Teacher', 'view', 'school', 'View teacher lesson logs'),
  ('manageLessonLogs', 'Teacher', 'manage', 'school', 'Create and update lesson logs'),
  ('manageTimetableAutomation', 'Academic', 'manage', 'school', 'Run timetable automation engine'),
  ('viewSchoolBranding', 'School', 'view', 'school', 'View school branding'),
  ('manageSchoolBranding', 'School', 'manage', 'school', 'Manage school branding'),
  ('viewWhatsAppProvider', 'Communication', 'view', 'school', 'View WhatsApp provider config'),
  ('manageWhatsAppProvider', 'Communication', 'manage', 'school', 'Manage WhatsApp provider config')
ON CONFLICT (code) DO NOTHING;

INSERT INTO role_permissions (role_code, permission_code) VALUES
  ('superAdmin', 'viewSubjects'),
  ('superAdmin', 'manageSubjects'),
  ('superAdmin', 'viewLessonLogs'),
  ('superAdmin', 'manageLessonLogs'),
  ('superAdmin', 'manageTimetableAutomation'),
  ('superAdmin', 'viewSchoolBranding'),
  ('superAdmin', 'manageSchoolBranding'),
  ('superAdmin', 'viewWhatsAppProvider'),
  ('superAdmin', 'manageWhatsAppProvider'),
  ('schoolAdmin', 'viewSubjects'),
  ('schoolAdmin', 'manageSubjects'),
  ('schoolAdmin', 'viewLessonLogs'),
  ('schoolAdmin', 'manageLessonLogs'),
  ('schoolAdmin', 'manageTimetableAutomation'),
  ('schoolAdmin', 'viewSchoolBranding'),
  ('schoolAdmin', 'manageSchoolBranding'),
  ('schoolAdmin', 'viewWhatsAppProvider'),
  ('schoolAdmin', 'manageWhatsAppProvider'),
  ('principal', 'viewSubjects'),
  ('principal', 'manageSubjects'),
  ('principal', 'viewLessonLogs'),
  ('principal', 'manageTimetableAutomation'),
  ('principal', 'viewSchoolBranding'),
  ('principal', 'manageSchoolBranding'),
  ('principal', 'viewWhatsAppProvider'),
  ('teacher', 'viewSubjects'),
  ('teacher', 'viewLessonLogs'),
  ('teacher', 'manageLessonLogs')
ON CONFLICT DO NOTHING;
