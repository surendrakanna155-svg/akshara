-- v15.8 — Pilot RBAC permission recovery
-- Re-applies role_permissions from phases 8–16 when earlier migrations recorded
-- as applied but failed before INSERT (broken permissions table name).

INSERT INTO school_membership_roles (school_membership_id, role_slug, is_primary, status)
SELECT sm.id, sm.role, true, 'active'
FROM school_memberships sm
INNER JOIN role_definitions rd ON rd.slug = sm.role
WHERE sm.role IS NOT NULL AND sm.role <> ''
ON CONFLICT (school_membership_id, role_slug) DO NOTHING;

-- ─── School admin pilot grants ───────────────────────────────────────────────

INSERT INTO role_permissions (role_slug, permission_slug) VALUES
  ('schoolAdmin', 'viewSubjects'),
  ('schoolAdmin', 'manageSubjects'),
  ('schoolAdmin', 'viewLessonLogs'),
  ('schoolAdmin', 'manageLessonLogs'),
  ('schoolAdmin', 'manageTimetableAutomation'),
  ('schoolAdmin', 'viewSchoolBranding'),
  ('schoolAdmin', 'manageSchoolBranding'),
  ('schoolAdmin', 'viewWhatsAppProvider'),
  ('schoolAdmin', 'manageWhatsAppProvider'),
  ('schoolAdmin', 'viewEducation'),
  ('schoolAdmin', 'manageEducation'),
  ('schoolAdmin', 'viewStudentRisk'),
  ('schoolAdmin', 'generateIntelligence'),
  ('schoolAdmin', 'viewHomeworkIntelligence'),
  ('schoolAdmin', 'manageHomeworkIntelligence'),
  ('schoolAdmin', 'viewStudent360'),
  ('schoolAdmin', 'viewEmployees'),
  ('schoolAdmin', 'manageEmployees'),
  ('schoolAdmin', 'viewInventoryDistribution'),
  ('schoolAdmin', 'manageInventoryDistribution'),
  ('schoolAdmin', 'viewEmployeeIntelligence'),
  ('schoolAdmin', 'viewOperationsHub'),
  ('schoolAdmin', 'viewSchoolMemories'),
  ('schoolAdmin', 'manageSchoolMemories'),
  ('schoolAdmin', 'viewAchievementPromotion'),
  ('schoolAdmin', 'manageAchievementPromotion'),
  ('schoolAdmin', 'approveAchievementPromotion'),
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
  ('schoolAdmin', 'viewSubjectAssignments'),
  ('schoolAdmin', 'manageSubjectAssignments'),
  ('schoolAdmin', 'viewLessonAnalytics'),
  ('schoolAdmin', 'viewTimetableOptimization'),
  ('schoolAdmin', 'viewCommunicationDelivery'),
  ('schoolAdmin', 'manageCommunicationTemplates'),
  ('schoolAdmin', 'viewPilotDashboard'),
  ('schoolAdmin', 'manageSyllabus'),
  ('schoolAdmin', 'viewAcademicProgress'),
  ('schoolAdmin', 'manageAcademicProgress'),
  ('schoolAdmin', 'manageAcademicRooms'),
  ('schoolAdmin', 'viewParentAcademicSummary'),
  ('schoolAdmin', 'viewFinanceIntelligence'),
  ('schoolAdmin', 'viewFinanceExecutiveDashboard'),
  ('schoolAdmin', 'viewInventoryIntelligence'),
  ('schoolAdmin', 'manageAssetLifecycle'),
  ('schoolAdmin', 'manageProcurementWorkflow'),
  ('schoolAdmin', 'viewStudentSuccessIntelligence'),
  ('schoolAdmin', 'viewExamIntelligence'),
  ('schoolAdmin', 'viewCommunicationAnalytics'),
  ('schoolAdmin', 'viewTeacherEffectiveness'),
  ('schoolAdmin', 'viewAnalytics'),
  ('schoolAdmin', 'viewSchoolHealth')
ON CONFLICT DO NOTHING;

-- ─── Principal pilot grants ──────────────────────────────────────────────────

INSERT INTO role_permissions (role_slug, permission_slug) VALUES
  ('principal', 'viewSubjects'),
  ('principal', 'viewLessonLogs'),
  ('principal', 'viewStudentRisk'),
  ('principal', 'generateIntelligence'),
  ('principal', 'viewFinanceIntelligence'),
  ('principal', 'viewFinanceExecutiveDashboard'),
  ('principal', 'viewInventoryIntelligence'),
  ('principal', 'viewStudentSuccessIntelligence'),
  ('principal', 'viewExamIntelligence'),
  ('principal', 'viewCommunicationAnalytics'),
  ('principal', 'viewTeacherEffectiveness'),
  ('principal', 'viewPrincipalCommand'),
  ('principal', 'viewAnalytics'),
  ('principal', 'viewSchoolHealth'),
  ('principal', 'viewParentAcademicSummary'),
  ('principal', 'viewParentInsights')
ON CONFLICT DO NOTHING;

-- ─── Parent mobile grants (reports/insights only — no open AI chat) ───────────

INSERT INTO role_permissions (role_slug, permission_slug) VALUES
  ('parent', 'viewSis'),
  ('parent', 'viewFinance'),
  ('parent', 'viewParentExperience'),
  ('parent', 'viewParentInsights'),
  ('parent', 'viewParentAcademicSummary')
ON CONFLICT DO NOTHING;

-- ─── Teacher daily workflow grants ───────────────────────────────────────────

INSERT INTO role_permissions (role_slug, permission_slug) VALUES
  ('teacher', 'viewSubjects'),
  ('teacher', 'viewLessonLogs'),
  ('teacher', 'manageLessonLogs'),
  ('teacher', 'viewEducation'),
  ('teacher', 'manageEducation'),
  ('teacher', 'viewStudentRisk'),
  ('teacher', 'generateIntelligence'),
  ('teacher', 'viewHomeworkIntelligence'),
  ('teacher', 'manageHomeworkIntelligence'),
  ('teacher', 'viewStudent360'),
  ('teacher', 'viewEmployees'),
  ('teacher', 'viewSubjectAssignments'),
  ('teacher', 'viewLessonAnalytics'),
  ('teacher', 'viewAcademicProgress'),
  ('teacher', 'manageAcademicProgress'),
  ('teacher', 'viewExamIntelligence'),
  ('teacher', 'viewStudentSuccessIntelligence'),
  ('teacher', 'viewTeacherEffectiveness'),
  ('teacher', 'viewTeacherAssistant'),
  ('teacher', 'manageTeacherAssistant'),
  ('teacher', 'viewAchievementPromotion'),
  ('teacher', 'manageAchievementPromotion')
ON CONFLICT DO NOTHING;

UPDATE school_memberships SET permissions_version = permissions_version + 1;
UPDATE organization_memberships SET permissions_version = permissions_version + 1;
