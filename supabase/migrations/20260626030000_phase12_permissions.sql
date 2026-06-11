-- Phase 12 permissions — Inventory Intelligence

INSERT INTO permission_definitions (slug, module, action, scope, description) VALUES
  ('viewInventoryIntelligence', 'Inventory', 'view', 'school', 'View inventory copilot forecasts and risk alerts'),
  ('manageAssetLifecycle', 'Inventory', 'manage', 'school', 'Record asset lifecycle events (purchase through retirement)'),
  ('manageProcurementWorkflow', 'Inventory', 'manage', 'school', 'Advance procurement workflow steps and approvals')
ON CONFLICT (slug) DO NOTHING;

INSERT INTO role_permissions (role_slug, permission_slug) VALUES
  ('superAdmin', 'viewInventoryIntelligence'),
  ('superAdmin', 'manageAssetLifecycle'),
  ('superAdmin', 'manageProcurementWorkflow'),
  ('schoolAdmin', 'viewInventoryIntelligence'),
  ('schoolAdmin', 'manageAssetLifecycle'),
  ('schoolAdmin', 'manageProcurementWorkflow'),
  ('inventoryManager', 'viewInventoryIntelligence'),
  ('inventoryManager', 'manageAssetLifecycle'),
  ('inventoryManager', 'manageProcurementWorkflow'),
  ('principal', 'viewInventoryIntelligence')
ON CONFLICT DO NOTHING;
