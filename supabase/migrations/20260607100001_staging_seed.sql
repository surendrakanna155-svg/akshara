-- Staging / local seed data for OTP login validation (no production secrets)

INSERT INTO organizations (id, name, slug, plan, status)
VALUES (
  'a1000000-0000-4000-8000-000000000001',
  'Akshara Staging Organization',
  'akshara-staging',
  'trial',
  'active'
)
ON CONFLICT (slug) DO NOTHING;

INSERT INTO schools (id, organization_id, name, code)
VALUES (
  'a2000000-0000-4000-8000-000000000001',
  'a1000000-0000-4000-8000-000000000001',
  'Akshara Staging School',
  'AKS-001'
)
ON CONFLICT (id) DO NOTHING;

INSERT INTO users (id, phone, email, display_name)
VALUES (
  'a3000000-0000-4000-8000-000000000001',
  '+919876543210',
  'staging.admin@aksharaerp.com',
  'Staging School Admin'
)
ON CONFLICT (phone) DO NOTHING;

INSERT INTO organization_memberships (user_id, organization_id, role, status, permissions_version)
VALUES (
  'a3000000-0000-4000-8000-000000000001',
  'a1000000-0000-4000-8000-000000000001',
  'organizationAdmin',
  'active',
  1
)
ON CONFLICT (user_id, organization_id) DO NOTHING;

INSERT INTO school_memberships (user_id, school_id, role, status, permissions_version)
VALUES (
  'a3000000-0000-4000-8000-000000000001',
  'a2000000-0000-4000-8000-000000000001',
  'schoolAdmin',
  'active',
  1
)
ON CONFLICT (user_id, school_id) DO NOTHING;
