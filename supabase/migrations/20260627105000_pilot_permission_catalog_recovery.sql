-- v15.8 — Pilot permission catalog recovery (runs before role_permissions backfill)
-- Ensures permission_definitions exist when phase 8–16 migrations were marked applied
-- but failed before INSERT (broken permissions table name in v15.7 chain).

-- from 20260620000001_education_permissions.sql
INSERT INTO permission_definitions (slug, module, action, scope, description) VALUES
  ('viewEducation', 'Education', 'view', 'school', 'View question papers, question bank, homework, and report remarks'),
  ('manageEducation', 'Education', 'manage', 'school', 'Generate and publish education content')
ON CONFLICT (slug) DO NOTHING;

-- from 20260621000001_intelligence_permissions.sql
INSERT INTO permission_definitions (slug, module, action, scope, description) VALUES
  ('viewStudentRisk', 'Intelligence', 'view', 'school', 'View student risk dashboards and alerts'),
  ('generateIntelligence', 'Intelligence', 'manage', 'school', 'Generate risk scores, messages, and guidance reports')
ON CONFLICT (slug) DO NOTHING;

-- from 20260622400000_phase4_permissions.sql
INSERT INTO permission_definitions (slug, module, action, scope, description) VALUES
  ('viewHomeworkIntelligence', 'Intelligence', 'view', 'school', 'View homework intelligence recommendations'),
  ('manageHomeworkIntelligence', 'Intelligence', 'manage', 'school', 'Apply homework intelligence plans'),
  ('viewStudent360', 'SIS', 'view', 'school', 'View unified student 360 profile'),
  ('viewEmployees', 'HR', 'view', 'school', 'View employee platform'),
  ('manageEmployees', 'HR', 'manage', 'school', 'Manage employees and role assignments'),
  ('viewInventoryDistribution', 'Inventory', 'view', 'school', 'View inventory distribution dashboard'),
  ('manageInventoryDistribution', 'Inventory', 'manage', 'school', 'Manage student inventory distribution lifecycle')
ON CONFLICT (slug) DO NOTHING;

-- from 20260622600000_phase5_permissions.sql
INSERT INTO permission_definitions (slug, module, action, scope, description) VALUES
  ('viewParentExperience', 'Parent', 'view', 'parent', 'View parent experience hub'),
  ('viewEmployeeIntelligence', 'HR', 'view', 'school', 'View employee intelligence and 360'),
  ('viewOperationsHub', 'Management', 'view', 'school', 'View school operations hub'),
  ('viewSchoolMemories', 'Alumni', 'view', 'school', 'View school memories'),
  ('manageSchoolMemories', 'Alumni', 'manage', 'school', 'Manage school memories'),
  ('viewAchievementPromotion', 'Management', 'view', 'school', 'View achievement promotions'),
  ('manageAchievementPromotion', 'Management', 'manage', 'school', 'Create and manage promotions'),
  ('approveAchievementPromotion', 'Management', 'approve', 'school', 'Approve achievement promotions')
ON CONFLICT (slug) DO NOTHING;

-- from 20260623400000_evolution_permissions.sql
INSERT INTO permission_definitions (slug, module, action, scope, description) VALUES
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
ON CONFLICT (slug) DO NOTHING;

-- from 20260624100000_school_completion_permissions.sql
INSERT INTO permission_definitions (slug, module, action, scope, description) VALUES
  ('viewSubjects', 'Academic', 'view', 'school', 'View academic subject catalog'),
  ('manageSubjects', 'Academic', 'manage', 'school', 'Manage academic subjects'),
  ('viewLessonLogs', 'Teacher', 'view', 'school', 'View teacher lesson logs'),
  ('manageLessonLogs', 'Teacher', 'manage', 'school', 'Create and update lesson logs'),
  ('manageTimetableAutomation', 'Academic', 'manage', 'school', 'Run timetable automation engine'),
  ('viewSchoolBranding', 'School', 'view', 'school', 'View school branding'),
  ('manageSchoolBranding', 'School', 'manage', 'school', 'Manage school branding'),
  ('viewWhatsAppProvider', 'Communication', 'view', 'school', 'View WhatsApp provider config'),
  ('manageWhatsAppProvider', 'Communication', 'manage', 'school', 'Manage WhatsApp provider config')
ON CONFLICT (slug) DO NOTHING;

-- from 20260624210000_phase9_permissions.sql
INSERT INTO permission_definitions (slug, module, action, scope, description) VALUES
  ('viewSubjectAssignments', 'Academic', 'view', 'school', 'View class and teacher subject assignments'),
  ('manageSubjectAssignments', 'Academic', 'manage', 'school', 'Manage class and teacher subject assignments'),
  ('viewLessonAnalytics', 'Teacher', 'view', 'school', 'View lesson and syllabus analytics'),
  ('viewTimetableOptimization', 'Academic', 'view', 'school', 'View timetable optimization insights'),
  ('viewCommunicationDelivery', 'Communication', 'view', 'school', 'View communication delivery analytics'),
  ('manageCommunicationTemplates', 'Communication', 'manage', 'school', 'Manage school communication templates'),
  ('viewPilotDashboard', 'Onboarding', 'view', 'school', 'View real-school pilot dashboard'),
  ('managePlatformWhatsApp', 'Platform', 'manage', 'organization', 'Manage platform WhatsApp provider (super admin only)')
ON CONFLICT (slug) DO NOTHING;

-- from 20260625010000_phase10_permissions.sql
INSERT INTO permission_definitions (slug, module, action, scope, description) VALUES
  ('manageSyllabus', 'Academic', 'manage', 'school', 'Manage syllabus generation and templates'),
  ('viewAcademicProgress', 'Academic', 'view', 'school', 'View academic progress dashboards'),
  ('manageAcademicProgress', 'Academic', 'manage', 'school', 'Record topic and chapter completion'),
  ('managePlatformProviders', 'Platform', 'manage', 'organization', 'Manage AI/WhatsApp/SMS providers (super admin)'),
  ('viewPlatformUsage', 'Platform', 'view', 'organization', 'View platform usage and cost analytics'),
  ('managePlatformVault', 'Platform', 'manage', 'organization', 'Manage encrypted provider credentials'),
  ('managePlatformFeatures', 'Platform', 'manage', 'organization', 'Enable/disable features per school'),
  ('manageAcademicRooms', 'Academic', 'manage', 'school', 'Manage rooms and exam timetables'),
  ('viewParentAcademicSummary', 'Parent', 'view', 'school', 'View structured parent academic summary')
ON CONFLICT (slug) DO NOTHING;

-- from 20260626010000_phase11_permissions.sql
INSERT INTO permission_definitions (slug, module, action, scope, description) VALUES
  ('viewFinanceIntelligence', 'Finance', 'view', 'school', 'View finance copilot forecasts and trends'),
  ('viewFinanceExecutiveDashboard', 'Finance', 'view', 'school', 'View finance executive collection health dashboard')
ON CONFLICT (slug) DO NOTHING;

-- from 20260626030000_phase12_permissions.sql
INSERT INTO permission_definitions (slug, module, action, scope, description) VALUES
  ('viewInventoryIntelligence', 'Inventory', 'view', 'school', 'View inventory copilot forecasts and risk alerts'),
  ('manageAssetLifecycle', 'Inventory', 'manage', 'school', 'Record asset lifecycle events (purchase through retirement)'),
  ('manageProcurementWorkflow', 'Inventory', 'manage', 'school', 'Advance procurement workflow steps and approvals')
ON CONFLICT (slug) DO NOTHING;

-- from 20260626040001_phase13_permissions.sql
INSERT INTO permission_definitions (slug, module, action, scope, description) VALUES
  ('viewStudentSuccessIntelligence', 'Intelligence', 'view', 'school', 'View student success predictions and intervention tracking')
ON CONFLICT (slug) DO NOTHING;

-- from 20260626050001_phase14_permissions.sql
INSERT INTO permission_definitions (slug, module, action, scope, description) VALUES
  ('viewExamIntelligence', 'Intelligence', 'view', 'school', 'View exam analytics, weak chapters, and academic forecasting')
ON CONFLICT (slug) DO NOTHING;

-- from 20260626060100_phase15_permissions.sql
INSERT INTO permission_definitions (slug, module, action, scope, description) VALUES
  ('viewCommunicationAnalytics', 'Communication', 'view', 'school', 'View communication analytics dashboards')
ON CONFLICT (slug) DO NOTHING;

-- from 20260626070100_phase16_permissions.sql
INSERT INTO permission_definitions (slug, module, action, scope, description) VALUES
  ('viewTeacherEffectiveness', 'Intelligence', 'view', 'school', 'View teacher effectiveness analytics and planning center')
ON CONFLICT (slug) DO NOTHING;
