-- PLAT-0 (W2) — Multi-school identity. Owner decision #14 (FINAL): ONE user may
-- belong to MANY schools, with STRICT per-school isolation. This migration is
-- deliberately ADDITIVE and isolation-preserving. It does three things and
-- NOTHING that widens an existing policy:
--
--   1. `app_current_school_group_id()` — the missing RLS helper sibling. The
--      request context already sets `app.school_group_id` (see
--      20260609100000 set_request_context), the JWT already carries
--      `school_group_id`, and the `school_group` AuthScope already exists, but
--      there was no reader function. Added STABLE/read-only, like its siblings.
--
--   2. `school_groups` + `school_group_members` — a MINIMAL, org-owned DISPLAY
--      grouping for the multi-school selector UX (e.g. "St. Xavier — City
--      Campus / Suburb Campus"). This is a LABEL, never an isolation key: no
--      operational table keys off it, and the per-school boundary
--      (`app_current_school_id()`) is untouched. Reads are org-scope (list your
--      org's groups) or school-scope (read the group your CURRENT school belongs
--      to). No cross-school data is ever reachable through a group.
--
--   3. Isolation FIXTURES for the enforced negative-isolation probe: a staff
--      user who is an ACTIVE member of BOTH staging School A and School B — the
--      canonical multi-school identity. The probe (tenant_isolation_probes.ts)
--      switches this user between the two schools and proves NO cross-school
--      read leaks in either direction.
--
-- SECURITY: no RLS policy on any existing table is dropped, recreated, or
-- broadened here. The two new tables are read-only to erp_tenant and fenced by
-- the SAME `app_current_*` helpers every other policy uses.

-- ─── 1. RLS helper: current school-group id ────────────────────────────────────

CREATE OR REPLACE FUNCTION app_current_school_group_id()
RETURNS UUID
LANGUAGE sql
STABLE
AS $$
  SELECT NULLIF(current_setting('app.school_group_id', true), '')::uuid;
$$;

-- ─── 2. School groups (display-only grouping for the selector) ──────────────────

CREATE TABLE IF NOT EXISTS school_groups (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id UUID NOT NULL REFERENCES organizations (id),
  name TEXT NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now())
);

CREATE INDEX IF NOT EXISTS idx_school_groups_org ON school_groups (organization_id);

DROP TRIGGER IF EXISTS school_groups_updated_at ON school_groups;
CREATE TRIGGER school_groups_updated_at
  BEFORE UPDATE ON school_groups
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- Membership of a school in a display group. A school belongs to at most one
-- group per row; the group is purely a label surfaced in the selector.
CREATE TABLE IF NOT EXISTS school_group_members (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id UUID NOT NULL REFERENCES organizations (id),
  school_group_id UUID NOT NULL REFERENCES school_groups (id) ON DELETE CASCADE,
  school_id UUID NOT NULL REFERENCES schools (id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),
  UNIQUE (school_group_id, school_id)
);

CREATE INDEX IF NOT EXISTS idx_school_group_members_school
  ON school_group_members (school_id);

ALTER TABLE school_groups ENABLE ROW LEVEL SECURITY;
ALTER TABLE school_groups FORCE ROW LEVEL SECURITY;
ALTER TABLE school_group_members ENABLE ROW LEVEL SECURITY;
ALTER TABLE school_group_members FORCE ROW LEVEL SECURITY;

-- school_groups: an org reads its own groups; a school reads the group(s) its
-- CURRENT school belongs to (so the selector can show a label). Never crosses
-- the tenant boundary; never exposes another school's operational data.
DROP POLICY IF EXISTS school_groups_scope_read ON school_groups;
CREATE POLICY school_groups_scope_read ON school_groups
  FOR SELECT
  USING (
    organization_id = app_current_tenant_id()
    AND (
      app_current_scope() = 'organization'
      OR (
        app_current_scope() = 'school'
        AND EXISTS (
          SELECT 1 FROM school_group_members sgm
          WHERE sgm.school_group_id = school_groups.id
            AND sgm.school_id = app_current_school_id()
        )
      )
    )
  );

-- school_group_members: org lists its own; a school reads ONLY its own row
-- (school_id = the current school). A school can NEVER enumerate the other
-- schools in its group through this table — the row is scoped to itself.
DROP POLICY IF EXISTS school_group_members_scope_read ON school_group_members;
CREATE POLICY school_group_members_scope_read ON school_group_members
  FOR SELECT
  USING (
    organization_id = app_current_tenant_id()
    AND (
      app_current_scope() = 'organization'
      OR (
        app_current_scope() = 'school'
        AND school_id = app_current_school_id()
      )
    )
  );

GRANT SELECT ON school_groups TO erp_tenant;
GRANT SELECT ON school_group_members TO erp_tenant;

-- ─── 3. Multi-school identity fixtures (enforced-isolation probe) ───────────────
-- A staff user who is an ACTIVE member of BOTH staging schools. The probe logs
-- in-context as this user at School A and at School B and asserts each context
-- sees ONLY its own school's rows. Reuses the schools seeded in 20260609100000
-- (School A a2..01, School B a2..02) and its students (STUDENT_A a4..01 @ A,
-- STUDENT_B a4..02 @ B).

INSERT INTO users (id, phone, email, display_name)
VALUES (
  'a3000000-0000-4000-8000-000000000006',
  '+919876543216',
  'staging.multischool@aksharaerp.com',
  'Staging Multi-School Staff'
)
ON CONFLICT (phone) DO NOTHING;

-- Active membership in School A and School B (the multi-school identity).
INSERT INTO school_memberships (user_id, school_id, role, status, permissions_version)
VALUES
  (
    'a3000000-0000-4000-8000-000000000006',
    'a2000000-0000-4000-8000-000000000001',
    'teacher',
    'active',
    1
  ),
  (
    'a3000000-0000-4000-8000-000000000006',
    'a2000000-0000-4000-8000-000000000002',
    'teacher',
    'active',
    1
  )
ON CONFLICT (user_id, school_id) DO NOTHING;

-- Primary role per membership (resolved by membership id, robust to the
-- gen_random_uuid() PK).
INSERT INTO school_membership_roles (school_membership_id, role_slug, is_primary, status)
SELECT sm.id, 'teacher', true, 'active'
FROM school_memberships sm
WHERE sm.user_id = 'a3000000-0000-4000-8000-000000000006'
  AND sm.school_id IN (
    'a2000000-0000-4000-8000-000000000001',
    'a2000000-0000-4000-8000-000000000002'
  )
ON CONFLICT (school_membership_id, role_slug) DO NOTHING;

-- Display group binding both schools — proves the selector grouping while the
-- isolation boundary stays strictly per-school.
INSERT INTO school_groups (id, organization_id, name)
VALUES (
  'a7000000-0000-4000-8000-000000000001',
  'a1000000-0000-4000-8000-000000000001',
  'Akshara Staging Campuses'
)
ON CONFLICT (id) DO NOTHING;

INSERT INTO school_group_members (organization_id, school_group_id, school_id)
VALUES
  (
    'a1000000-0000-4000-8000-000000000001',
    'a7000000-0000-4000-8000-000000000001',
    'a2000000-0000-4000-8000-000000000001'
  ),
  (
    'a1000000-0000-4000-8000-000000000001',
    'a7000000-0000-4000-8000-000000000001',
    'a2000000-0000-4000-8000-000000000002'
  )
ON CONFLICT (school_group_id, school_id) DO NOTHING;
