-- Phase 14 permissions — Exam & Academic Intelligence

INSERT INTO permissions (code, module, action, scope, description) VALUES
  ('viewExamIntelligence', 'Intelligence', 'view', 'school', 'View exam analytics, weak chapters, and academic forecasting')
ON CONFLICT (code) DO NOTHING;

INSERT INTO role_permissions (role_code, permission_code) VALUES
  ('superAdmin', 'viewExamIntelligence'),
  ('schoolAdmin', 'viewExamIntelligence'),
  ('principal', 'viewExamIntelligence'),
  ('teacher', 'viewExamIntelligence'),
  ('management', 'viewExamIntelligence')
ON CONFLICT DO NOTHING;
