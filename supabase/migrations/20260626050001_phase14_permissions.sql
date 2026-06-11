-- Phase 14 permissions — Exam & Academic Intelligence

INSERT INTO permission_definitions (slug, module, action, scope, description) VALUES
  ('viewExamIntelligence', 'Intelligence', 'view', 'school', 'View exam analytics, weak chapters, and academic forecasting')
ON CONFLICT (slug) DO NOTHING;

INSERT INTO role_permissions (role_slug, permission_slug) VALUES
  ('superAdmin', 'viewExamIntelligence'),
  ('schoolAdmin', 'viewExamIntelligence'),
  ('principal', 'viewExamIntelligence'),
  ('teacher', 'viewExamIntelligence'),
  ('management', 'viewExamIntelligence')
ON CONFLICT DO NOTHING;
