-- B2 — Capability Gating → Entitlement Layer · Step 1 (data model + seed) · 3 of 3
--
-- Catalog the two new permissions the entitlement layer needs. Step 2 wires the
-- actual routes; defining the permissions now keeps the catalog the single source
-- of truth and lets the seed land with the rest of the data model.
--
--   managePlatformSubscriptions — assign/change an org's plan, slab, status,
--     overrides (PUT /platform/organizations/{id}/subscription). superAdmin ONLY,
--     organization scope. This is plan assignment, NOT billing.
--   viewSubscription — read the current org's plan, status, entitlements & usage
--     (GET /subscription). Granted to org admins so the client can gate UI.
--
-- Mirrors 20260623400000_evolution_permissions.sql exactly. Additive, idempotent.

INSERT INTO permission_definitions (slug, module, action, scope, description) VALUES
  ('managePlatformSubscriptions', 'Subscription', 'manage', 'organization',
     'Assign or change an organization''s subscription plan (no payment)'),
  ('viewSubscription', 'Subscription', 'view', 'school',
     'View current organization plan, entitlements and usage')
ON CONFLICT (slug) DO NOTHING;

INSERT INTO role_permissions (role_slug, permission_slug) VALUES
  -- Plan assignment is platform-only.
  ('superAdmin', 'managePlatformSubscriptions'),
  -- Reading the plan/entitlements is available to platform + org admins.
  ('superAdmin', 'viewSubscription'),
  ('schoolAdmin', 'viewSubscription'),
  ('principal', 'viewSubscription')
ON CONFLICT DO NOTHING;
