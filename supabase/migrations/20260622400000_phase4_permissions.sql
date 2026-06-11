-- Phase 4 permissions (v9.4–v9.7)

INSERT INTO permissions (slug, module, action, scope, description) VALUES
  ('viewHomeworkIntelligence', 'Intelligence', 'view', 'school', 'View homework intelligence recommendations'),
  ('manageHomeworkIntelligence', 'Intelligence', 'manage', 'school', 'Apply homework intelligence plans'),
  ('viewStudent360', 'SIS', 'view', 'school', 'View unified student 360 profile'),
  ('viewEmployees', 'HR', 'view', 'school', 'View employee platform'),
  ('manageEmployees', 'HR', 'manage', 'school', 'Manage employees and role assignments'),
  ('viewInventoryDistribution', 'Inventory', 'view', 'school', 'View inventory distribution dashboard'),
  ('manageInventoryDistribution', 'Inventory', 'manage', 'school', 'Manage student inventory distribution lifecycle')
ON CONFLICT (slug) DO NOTHING;

INSERT INTO role_permissions (role_slug, permission_slug) VALUES
  ('superAdmin', 'viewHomeworkIntelligence'),
  ('superAdmin', 'manageHomeworkIntelligence'),
  ('superAdmin', 'viewStudent360'),
  ('superAdmin', 'viewEmployees'),
  ('superAdmin', 'manageEmployees'),
  ('superAdmin', 'viewInventoryDistribution'),
  ('superAdmin', 'manageInventoryDistribution'),
  ('schoolAdmin', 'viewHomeworkIntelligence'),
  ('schoolAdmin', 'manageHomeworkIntelligence'),
  ('schoolAdmin', 'viewStudent360'),
  ('schoolAdmin', 'viewEmployees'),
  ('schoolAdmin', 'manageEmployees'),
  ('schoolAdmin', 'viewInventoryDistribution'),
  ('schoolAdmin', 'manageInventoryDistribution'),
  ('principal', 'viewHomeworkIntelligence'),
  ('principal', 'manageHomeworkIntelligence'),
  ('principal', 'viewStudent360'),
  ('principal', 'viewEmployees'),
  ('principal', 'manageEmployees'),
  ('principal', 'viewInventoryDistribution'),
  ('principal', 'manageInventoryDistribution'),
  ('teacher', 'viewHomeworkIntelligence'),
  ('teacher', 'manageHomeworkIntelligence'),
  ('teacher', 'viewStudent360'),
  ('teacher', 'viewEmployees'),
  ('management', 'viewHomeworkIntelligence'),
  ('management', 'viewStudent360'),
  ('management', 'viewEmployees'),
  ('management', 'viewInventoryDistribution'),
  ('inventoryManager', 'viewInventoryDistribution'),
  ('inventoryManager', 'manageInventoryDistribution')
ON CONFLICT DO NOTHING;
