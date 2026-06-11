-- Phase 11 permissions — Finance Intelligence

INSERT INTO permissions (code, module, action, scope, description) VALUES
  ('viewFinanceIntelligence', 'Finance', 'view', 'school', 'View finance copilot forecasts and trends'),
  ('viewFinanceExecutiveDashboard', 'Finance', 'view', 'school', 'View finance executive collection health dashboard')
ON CONFLICT (code) DO NOTHING;

INSERT INTO role_permissions (role_code, permission_code) VALUES
  ('superAdmin', 'viewFinanceIntelligence'),
  ('superAdmin', 'viewFinanceExecutiveDashboard'),
  ('schoolAdmin', 'viewFinanceIntelligence'),
  ('schoolAdmin', 'viewFinanceExecutiveDashboard'),
  ('financeManager', 'viewFinanceIntelligence'),
  ('financeManager', 'viewFinanceExecutiveDashboard'),
  ('principal', 'viewFinanceExecutiveDashboard')
ON CONFLICT DO NOTHING;
