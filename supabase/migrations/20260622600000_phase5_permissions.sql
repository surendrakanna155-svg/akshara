-- Phase 5 permissions (v9.8–v10.3)

INSERT INTO permissions (slug, module, action, scope, description) VALUES
  ('viewParentExperience', 'Parent', 'view', 'parent', 'View parent experience hub'),
  ('viewEmployeeIntelligence', 'HR', 'view', 'school', 'View employee intelligence and 360'),
  ('viewOperationsHub', 'Management', 'view', 'school', 'View school operations hub'),
  ('viewSchoolMemories', 'Alumni', 'view', 'school', 'View school memories'),
  ('manageSchoolMemories', 'Alumni', 'manage', 'school', 'Manage school memories'),
  ('viewAchievementPromotion', 'Management', 'view', 'school', 'View achievement promotions'),
  ('manageAchievementPromotion', 'Management', 'manage', 'school', 'Create and manage promotions'),
  ('approveAchievementPromotion', 'Management', 'approve', 'school', 'Approve achievement promotions')
ON CONFLICT (slug) DO NOTHING;

INSERT INTO role_permissions (role_slug, permission_slug) VALUES
  ('superAdmin', 'viewParentExperience'),
  ('superAdmin', 'viewEmployeeIntelligence'),
  ('superAdmin', 'viewOperationsHub'),
  ('superAdmin', 'viewSchoolMemories'),
  ('superAdmin', 'manageSchoolMemories'),
  ('superAdmin', 'viewAchievementPromotion'),
  ('superAdmin', 'manageAchievementPromotion'),
  ('superAdmin', 'approveAchievementPromotion'),
  ('schoolAdmin', 'viewEmployeeIntelligence'),
  ('schoolAdmin', 'viewOperationsHub'),
  ('schoolAdmin', 'viewSchoolMemories'),
  ('schoolAdmin', 'manageSchoolMemories'),
  ('schoolAdmin', 'viewAchievementPromotion'),
  ('schoolAdmin', 'manageAchievementPromotion'),
  ('schoolAdmin', 'approveAchievementPromotion'),
  ('principal', 'viewEmployeeIntelligence'),
  ('principal', 'viewOperationsHub'),
  ('principal', 'viewSchoolMemories'),
  ('principal', 'manageSchoolMemories'),
  ('principal', 'viewAchievementPromotion'),
  ('principal', 'manageAchievementPromotion'),
  ('principal', 'approveAchievementPromotion'),
  ('teacher', 'viewAchievementPromotion'),
  ('teacher', 'manageAchievementPromotion'),
  ('management', 'viewOperationsHub'),
  ('management', 'viewAchievementPromotion'),
  ('parent', 'viewParentExperience')
ON CONFLICT DO NOTHING;
