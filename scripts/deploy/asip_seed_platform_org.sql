-- ASIP — seed the Akshara Platform Support organization + support-team RBAC.
-- Idempotent (ON CONFLICT DO NOTHING). PLATFORM_ORG matches
-- app_support_platform_org() in migration 20260920000040.
--
-- The 4 principals are created with NON-DIALABLE sentinel phones (phone is
-- UNIQUE, no format check) so they can never collide with a real number and
-- cannot receive an OTP: they are RBAC-ready but the OWNER sets real phone
-- numbers to enable OTP login. Add more support staff by granting the
-- 'aksharaSupport' role to their org membership on PLATFORM_ORG.

-- 1. Platform-support organization
INSERT INTO organizations (id, name, slug)
VALUES ('a5100000-0000-4000-8000-000000000001', 'Akshara Platform Support', 'akshara-platform-support')
ON CONFLICT (id) DO NOTHING;

-- 2. The support role + its permission grant (permission 'platformSupport' is
--    seeded by migration 20260920000040).
--
-- is_system MUST be true. Migration 20260920000200 enforces
--   (organization_id IS NULL AND is_system) OR (organization_id IS NOT NULL AND NOT is_system)
-- and this row is a PLATFORM role: it is granted only inside PLATFORM_ORG, it is
-- shipped by us rather than created by a tenant, and its slug is camelCase (tenant
-- custom slugs are generated as custom_<org>_<name>). Seeding it false left
-- organization_id NULL and is_system false, which satisfies neither branch — on
-- 2026-07-31 that blocked 20260920000200 on production and, because the resolver
-- selects role_permissions.organization_id, kept every staff login returning 500.
--
-- Do NOT "fix" this by giving the row organization_id = PLATFORM_ORG instead:
-- 20260920000200's tenant policies are USING (organization_id = app_current_tenant_id()
-- AND is_system = false), so that would let support staff edit and delete their own
-- role. NULL org + is_system true keeps it immutable to every tenant session.
INSERT INTO role_definitions (slug, display_name, scope, is_system)
VALUES ('aksharaSupport', 'Akshara Support', 'organization', true)
ON CONFLICT (slug) DO NOTHING;

INSERT INTO role_permissions (role_slug, permission_slug)
VALUES ('aksharaSupport', 'platformSupport')
ON CONFLICT DO NOTHING;

-- 3. Support principals (Support Admin / L1 / L2 / Engineer).
INSERT INTO public.users (id, phone, display_name, profile) VALUES
  ('a5200000-0000-4000-8000-000000000001', 'asip-support-admin',    'Akshara Support Admin',    '{"asip_seed": true, "tier": "admin"}'::jsonb),
  ('a5200000-0000-4000-8000-000000000002', 'asip-support-l1',       'Akshara Support L1',       '{"asip_seed": true, "tier": "l1"}'::jsonb),
  ('a5200000-0000-4000-8000-000000000003', 'asip-support-l2',       'Akshara Support L2',       '{"asip_seed": true, "tier": "l2"}'::jsonb),
  ('a5200000-0000-4000-8000-000000000004', 'asip-support-engineer', 'Akshara Support Engineer', '{"asip_seed": true, "tier": "engineer"}'::jsonb)
ON CONFLICT (id) DO NOTHING;

-- 4. Memberships to PLATFORM_ORG (legacy role column + multi-role table).
INSERT INTO organization_memberships (id, user_id, organization_id, role, status) VALUES
  ('a5300000-0000-4000-8000-000000000001', 'a5200000-0000-4000-8000-000000000001', 'a5100000-0000-4000-8000-000000000001', 'aksharaSupport', 'active'),
  ('a5300000-0000-4000-8000-000000000002', 'a5200000-0000-4000-8000-000000000002', 'a5100000-0000-4000-8000-000000000001', 'aksharaSupport', 'active'),
  ('a5300000-0000-4000-8000-000000000003', 'a5200000-0000-4000-8000-000000000003', 'a5100000-0000-4000-8000-000000000001', 'aksharaSupport', 'active'),
  ('a5300000-0000-4000-8000-000000000004', 'a5200000-0000-4000-8000-000000000004', 'a5100000-0000-4000-8000-000000000001', 'aksharaSupport', 'active')
ON CONFLICT (id) DO NOTHING;

INSERT INTO organization_membership_roles (organization_membership_id, role_slug, is_primary, status) VALUES
  ('a5300000-0000-4000-8000-000000000001', 'aksharaSupport', true, 'active'),
  ('a5300000-0000-4000-8000-000000000002', 'aksharaSupport', true, 'active'),
  ('a5300000-0000-4000-8000-000000000003', 'aksharaSupport', true, 'active'),
  ('a5300000-0000-4000-8000-000000000004', 'aksharaSupport', true, 'active')
ON CONFLICT (organization_membership_id, role_slug) DO NOTHING;
