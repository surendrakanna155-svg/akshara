-- Phase 12 permissions — Inventory Intelligence

INSERT INTO permissions (code, module, action, scope, description) VALUES
  ('viewInventoryIntelligence', 'Inventory', 'view', 'school', 'View inventory copilot forecasts and risk alerts'),
  ('manageAssetLifecycle', 'Inventory', 'manage', 'school', 'Record asset lifecycle events (purchase through retirement)'),
  ('manageProcurementWorkflow', 'Inventory', 'manage', 'school', 'Advance procurement workflow steps and approvals')
ON CONFLICT (code) DO NOTHING;

INSERT INTO role_permissions (role_code, permission_code) VALUES
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
