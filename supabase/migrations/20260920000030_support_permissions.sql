-- ASIP — Phase 1, migration 4/4: RBAC permissions (reuse the ONE permission
-- engine — no parallel authz path).
--
-- Reporting (create incident / list-view-own / reply / attach) needs NO special
-- permission: any authenticated school-scope user can report a product issue
-- they hit. Only the SUPPORT-MANAGEMENT surface (view all school incidents,
-- collect evidence on demand, run the AI package, transition status) is gated:
--   * viewSupport   — read all support incidents in the school (triage view)
--   * manageSupport — triage: collect evidence, analyze, transition, resolve
--
-- Seeded into permission_definitions + granted via role_permissions exactly like
-- every other module (rbac_foundation.sql). Idempotent (ON CONFLICT DO NOTHING).
-- Additive: no existing grant is removed.

INSERT INTO permission_definitions (slug, module, action, scope, description) VALUES
  ('viewSupport', 'Support', 'view', 'school', 'View support incidents (triage)'),
  ('manageSupport', 'Support', 'manage', 'school', 'Triage, investigate and resolve support incidents')
ON CONFLICT (slug) DO NOTHING;

-- Grant to the tenant-side administrative roles that would triage product issues
-- for the school. (Cross-tenant Akshara support staff are Phase 2 / owner-gated
-- and are NOT granted here.)
INSERT INTO role_permissions (role_slug, permission_slug) VALUES
  ('superAdmin', 'viewSupport'), ('superAdmin', 'manageSupport'),
  ('schoolAdmin', 'viewSupport'), ('schoolAdmin', 'manageSupport'),
  ('principal', 'viewSupport'), ('principal', 'manageSupport'),
  ('vicePrincipal', 'viewSupport'),
  ('management', 'viewSupport'), ('management', 'manageSupport'),
  ('organizationAdmin', 'viewSupport'), ('organizationAdmin', 'manageSupport'),
  ('organizationOwner', 'viewSupport'), ('organizationOwner', 'manageSupport')
ON CONFLICT DO NOTHING;
