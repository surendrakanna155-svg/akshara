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
INSERT INTO role_definitions (slug, display_name, scope, is_system)
VALUES ('aksharaSupport', 'Akshara Support', 'organization', false)
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
