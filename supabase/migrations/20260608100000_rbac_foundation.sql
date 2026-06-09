-- v6.1 Sprint 3 Phase 1 — RBAC foundation (permission catalog, roles, multi-role, overrides)
-- Architecture: v6.1 §5, §4; RBACArchitecture.md §2–4; ClientBackendAlignment.md §3

-- ─── Permission catalog ─────────────────────────────────────────────────────

CREATE TABLE permission_definitions (
  slug TEXT PRIMARY KEY,
  module TEXT NOT NULL,
  action TEXT NOT NULL,
  scope TEXT NOT NULL CHECK (scope IN ('organization', 'school', 'school_group', 'self', 'platform')),
  description TEXT NOT NULL DEFAULT '',
  is_system BOOLEAN NOT NULL DEFAULT true,
  created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now())
);

CREATE TABLE permission_groups (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  slug TEXT NOT NULL UNIQUE,
  name TEXT NOT NULL,
  module TEXT NOT NULL DEFAULT '',
  created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now())
);

CREATE TABLE permission_group_members (
  group_id UUID NOT NULL REFERENCES permission_groups (id) ON DELETE CASCADE,
  permission_slug TEXT NOT NULL REFERENCES permission_definitions (slug) ON DELETE CASCADE,
  PRIMARY KEY (group_id, permission_slug)
);

CREATE TABLE role_definitions (
  slug TEXT PRIMARY KEY,
  display_name TEXT NOT NULL,
  scope TEXT NOT NULL CHECK (scope IN ('organization', 'school', 'school_group', 'self', 'platform')),
  is_system BOOLEAN NOT NULL DEFAULT true,
  created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now())
);

CREATE TABLE role_permissions (
  role_slug TEXT NOT NULL REFERENCES role_definitions (slug) ON DELETE CASCADE,
  permission_slug TEXT NOT NULL REFERENCES permission_definitions (slug) ON DELETE CASCADE,
  PRIMARY KEY (role_slug, permission_slug)
);

CREATE INDEX idx_role_permissions_role ON role_permissions (role_slug);

-- ─── Multi-role memberships (v6.1 §4.2) ─────────────────────────────────────

CREATE TABLE school_membership_roles (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  school_membership_id UUID NOT NULL REFERENCES school_memberships (id) ON DELETE CASCADE,
  role_slug TEXT NOT NULL REFERENCES role_definitions (slug),
  is_primary BOOLEAN NOT NULL DEFAULT false,
  effective_from DATE,
  effective_to DATE,
  status TEXT NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'suspended')),
  created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),
  UNIQUE (school_membership_id, role_slug)
);

CREATE INDEX idx_school_membership_roles_membership ON school_membership_roles (school_membership_id);

CREATE TABLE organization_membership_roles (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_membership_id UUID NOT NULL REFERENCES organization_memberships (id) ON DELETE CASCADE,
  role_slug TEXT NOT NULL REFERENCES role_definitions (slug),
  is_primary BOOLEAN NOT NULL DEFAULT false,
  effective_from DATE,
  effective_to DATE,
  status TEXT NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'suspended')),
  created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),
  UNIQUE (organization_membership_id, role_slug)
);

CREATE INDEX idx_org_membership_roles_membership ON organization_membership_roles (organization_membership_id);

-- ─── Permission overrides (v6.1 §5.3 — DENY wins) ───────────────────────────

CREATE TABLE membership_permission_overrides (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  school_membership_id UUID REFERENCES school_memberships (id) ON DELETE CASCADE,
  organization_membership_id UUID REFERENCES organization_memberships (id) ON DELETE CASCADE,
  permission_slug TEXT NOT NULL REFERENCES permission_definitions (slug) ON DELETE CASCADE,
  effect TEXT NOT NULL CHECK (effect IN ('grant', 'deny')),
  reason TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),
  CHECK (
    (school_membership_id IS NOT NULL AND organization_membership_id IS NULL)
    OR (school_membership_id IS NULL AND organization_membership_id IS NOT NULL)
  )
);

CREATE UNIQUE INDEX idx_membership_override_school
  ON membership_permission_overrides (school_membership_id, permission_slug)
  WHERE school_membership_id IS NOT NULL;

CREATE UNIQUE INDEX idx_membership_override_org
  ON membership_permission_overrides (organization_membership_id, permission_slug)
  WHERE organization_membership_id IS NOT NULL;

-- ─── Seed: permissions (22 client + 4 org per ClientBackendAlignment v6.1) ─

INSERT INTO permission_definitions (slug, module, action, scope, description) VALUES
  ('viewAdmissions', 'Admissions', 'view', 'school', 'View admissions module'),
  ('manageAdmissions', 'Admissions', 'manage', 'school', 'Manage admissions'),
  ('approveAdmissions', 'Admissions', 'approve', 'school', 'Approve admissions'),
  ('viewFinance', 'Finance', 'view', 'school', 'View finance'),
  ('manageFinance', 'Finance', 'manage', 'school', 'Manage finance'),
  ('approveRefunds', 'Finance', 'approve', 'school', 'Approve refunds'),
  ('viewSis', 'SIS', 'view', 'school', 'View SIS'),
  ('manageSis', 'SIS', 'manage', 'school', 'Manage SIS'),
  ('viewManagement', 'Management', 'view', 'school', 'View management'),
  ('manageManagement', 'Management', 'manage', 'school', 'Manage management'),
  ('viewTransport', 'Transport', 'view', 'school', 'View transport'),
  ('manageTransport', 'Transport', 'manage', 'school', 'Manage transport'),
  ('viewHr', 'HR', 'view', 'school', 'View HR'),
  ('manageHr', 'HR', 'manage', 'school', 'Manage HR'),
  ('viewHostel', 'Hostel', 'view', 'school', 'View hostel'),
  ('manageHostel', 'Hostel', 'manage', 'school', 'Manage hostel'),
  ('viewLibrary', 'Library', 'view', 'school', 'View library'),
  ('manageLibrary', 'Library', 'manage', 'school', 'Manage library'),
  ('viewInventory', 'Inventory', 'view', 'school', 'View inventory'),
  ('manageInventory', 'Inventory', 'manage', 'school', 'Manage inventory'),
  ('viewAlumni', 'Alumni', 'view', 'school', 'View alumni'),
  ('manageAlumni', 'Alumni', 'manage', 'school', 'Manage alumni'),
  ('viewControlCenter', 'ControlCenter', 'view', 'platform', 'View control center'),
  ('manageControlCenter', 'ControlCenter', 'manage', 'platform', 'Manage control center'),
  ('viewAdminHub', 'AdminHub', 'view', 'school', 'View admin hub'),
  ('viewOrganization', 'Organization', 'view', 'organization', 'View organization'),
  ('manageOrganization', 'Organization', 'manage', 'organization', 'Manage organization'),
  ('viewSchoolGroups', 'SchoolGroups', 'view', 'organization', 'View school groups'),
  ('manageSchoolGroups', 'SchoolGroups', 'manage', 'organization', 'Manage school groups')
ON CONFLICT (slug) DO NOTHING;

-- ─── Seed: permission groups (RBACArchitecture.md §4) ───────────────────────

INSERT INTO permission_groups (id, slug, name, module) VALUES
  ('b1000000-0000-4000-8000-000000000001', 'admissions_full', 'Admissions Full', 'Admissions'),
  ('b1000000-0000-4000-8000-000000000002', 'finance_operations', 'Finance Operations', 'Finance'),
  ('b1000000-0000-4000-8000-000000000003', 'finance_approvals', 'Finance Approvals', 'Finance'),
  ('b1000000-0000-4000-8000-000000000004', 'sis_operations', 'SIS Operations', 'SIS'),
  ('b1000000-0000-4000-8000-000000000005', 'org_administration', 'Organization Administration', 'Organization')
ON CONFLICT (slug) DO NOTHING;

INSERT INTO permission_group_members (group_id, permission_slug)
SELECT 'b1000000-0000-4000-8000-000000000001', unnest(ARRAY['viewAdmissions', 'manageAdmissions', 'approveAdmissions'])
ON CONFLICT DO NOTHING;

INSERT INTO permission_group_members (group_id, permission_slug)
SELECT 'b1000000-0000-4000-8000-000000000002', unnest(ARRAY['viewFinance', 'manageFinance'])
ON CONFLICT DO NOTHING;

INSERT INTO permission_group_members (group_id, permission_slug)
SELECT 'b1000000-0000-4000-8000-000000000003', unnest(ARRAY['approveRefunds'])
ON CONFLICT DO NOTHING;

INSERT INTO permission_group_members (group_id, permission_slug)
SELECT 'b1000000-0000-4000-8000-000000000004', unnest(ARRAY['viewSis', 'manageSis'])
ON CONFLICT DO NOTHING;

INSERT INTO permission_group_members (group_id, permission_slug)
SELECT 'b1000000-0000-4000-8000-000000000005', unnest(ARRAY['viewOrganization', 'manageOrganization', 'viewSchoolGroups', 'manageSchoolGroups'])
ON CONFLICT DO NOTHING;

-- ─── Seed: roles (v6.1 §3 + v6.0 compat slugs) ────────────────────────────

INSERT INTO role_definitions (slug, display_name, scope) VALUES
  ('superAdmin', 'Super Admin', 'platform'),
  ('organizationOwner', 'Organization Owner', 'organization'),
  ('organizationAdmin', 'Organization Admin', 'organization'),
  ('schoolGroupDirector', 'School Group Director', 'school_group'),
  ('schoolAdmin', 'School Admin', 'school'),
  ('principal', 'Principal', 'school'),
  ('vicePrincipal', 'Vice Principal', 'school'),
  ('financeAdmin', 'Finance Admin', 'school'),
  ('financeManager', 'Finance Manager', 'school'),
  ('hrManager', 'HR Manager', 'school'),
  ('inventoryManager', 'Inventory Manager', 'school'),
  ('transportManager', 'Transport Manager', 'school'),
  ('marketingManager', 'Marketing Manager', 'school'),
  ('teacher', 'Teacher', 'school'),
  ('classTeacher', 'Class Teacher', 'school'),
  ('coordinator', 'Coordinator', 'school'),
  ('counselor', 'Counselor', 'school'),
  ('admissionsCounselor', 'Admissions Counselor', 'school'),
  ('petTeacher', 'PET', 'school'),
  ('danceTeacher', 'Dance Teacher', 'school'),
  ('musicTeacher', 'Music Teacher', 'school'),
  ('librarian', 'Librarian', 'school'),
  ('officeStaff', 'Office Staff', 'school'),
  ('management', 'Management', 'school'),
  ('parent', 'Parent', 'self'),
  ('student', 'Student', 'self'),
  ('hostelManager', 'Hostel Manager', 'school')
ON CONFLICT (slug) DO NOTHING;

-- Helper: bulk role_permissions via temp mapping
CREATE TEMP TABLE _role_perm_seed (role_slug TEXT, permission_slug TEXT) ON COMMIT DROP;

INSERT INTO _role_perm_seed (role_slug, permission_slug) VALUES
  ('superAdmin', 'viewAdminHub'), ('superAdmin', 'viewAdmissions'), ('superAdmin', 'manageAdmissions'),
  ('superAdmin', 'approveAdmissions'), ('superAdmin', 'viewFinance'), ('superAdmin', 'manageFinance'),
  ('superAdmin', 'approveRefunds'), ('superAdmin', 'viewSis'), ('superAdmin', 'manageSis'),
  ('superAdmin', 'viewManagement'), ('superAdmin', 'manageManagement'), ('superAdmin', 'viewTransport'),
  ('superAdmin', 'manageTransport'), ('superAdmin', 'viewHr'), ('superAdmin', 'manageHr'),
  ('superAdmin', 'viewHostel'), ('superAdmin', 'manageHostel'), ('superAdmin', 'viewLibrary'),
  ('superAdmin', 'manageLibrary'), ('superAdmin', 'viewInventory'), ('superAdmin', 'manageInventory'),
  ('superAdmin', 'viewAlumni'), ('superAdmin', 'manageAlumni'), ('superAdmin', 'viewControlCenter'),
  ('superAdmin', 'manageControlCenter'),
  ('schoolAdmin', 'viewAdminHub'), ('schoolAdmin', 'viewAdmissions'), ('schoolAdmin', 'manageAdmissions'),
  ('schoolAdmin', 'approveAdmissions'), ('schoolAdmin', 'viewFinance'), ('schoolAdmin', 'manageFinance'),
  ('schoolAdmin', 'approveRefunds'), ('schoolAdmin', 'viewSis'), ('schoolAdmin', 'manageSis'),
  ('schoolAdmin', 'viewManagement'), ('schoolAdmin', 'manageManagement'), ('schoolAdmin', 'viewTransport'),
  ('schoolAdmin', 'manageTransport'), ('schoolAdmin', 'viewHr'), ('schoolAdmin', 'manageHr'),
  ('schoolAdmin', 'viewHostel'), ('schoolAdmin', 'manageHostel'), ('schoolAdmin', 'viewLibrary'),
  ('schoolAdmin', 'manageLibrary'), ('schoolAdmin', 'viewInventory'), ('schoolAdmin', 'manageInventory'),
  ('schoolAdmin', 'viewAlumni'), ('schoolAdmin', 'manageAlumni'),
  ('principal', 'viewAdminHub'), ('principal', 'viewAdmissions'), ('principal', 'manageAdmissions'),
  ('principal', 'approveAdmissions'), ('principal', 'viewFinance'), ('principal', 'viewSis'),
  ('principal', 'manageSis'), ('principal', 'viewManagement'), ('principal', 'manageManagement'),
  ('principal', 'viewLibrary'), ('principal', 'viewHr'), ('principal', 'viewAlumni'),
  ('vicePrincipal', 'viewAdminHub'), ('vicePrincipal', 'viewAdmissions'), ('vicePrincipal', 'manageAdmissions'),
  ('vicePrincipal', 'viewFinance'), ('vicePrincipal', 'viewSis'), ('vicePrincipal', 'manageSis'),
  ('vicePrincipal', 'viewManagement'), ('vicePrincipal', 'viewLibrary'), ('vicePrincipal', 'viewHr'),
  ('financeAdmin', 'viewAdminHub'), ('financeAdmin', 'viewFinance'), ('financeAdmin', 'manageFinance'),
  ('financeAdmin', 'approveRefunds'),
  ('financeManager', 'viewAdminHub'), ('financeManager', 'viewFinance'), ('financeManager', 'manageFinance'),
  ('financeManager', 'approveRefunds'),
  ('hrManager', 'viewAdminHub'), ('hrManager', 'viewHr'), ('hrManager', 'manageHr'),
  ('teacher', 'viewAdminHub'),
  ('classTeacher', 'viewAdminHub'), ('classTeacher', 'viewSis'),
  ('coordinator', 'viewAdminHub'), ('coordinator', 'viewSis'), ('coordinator', 'viewAdmissions'),
  ('coordinator', 'manageAdmissions'),
  ('counselor', 'viewAdminHub'), ('counselor', 'viewAdmissions'), ('counselor', 'manageAdmissions'),
  ('admissionsCounselor', 'viewAdminHub'), ('admissionsCounselor', 'viewAdmissions'),
  ('admissionsCounselor', 'manageAdmissions'),
  ('petTeacher', 'viewAdminHub'), ('danceTeacher', 'viewAdminHub'), ('musicTeacher', 'viewAdminHub'),
  ('librarian', 'viewAdminHub'), ('librarian', 'viewLibrary'), ('librarian', 'manageLibrary'),
  ('officeStaff', 'viewAdminHub'),
  ('management', 'viewAdminHub'), ('management', 'viewManagement'), ('management', 'manageManagement'),
  ('management', 'viewFinance'), ('management', 'viewSis'), ('management', 'viewAdmissions'),
  ('management', 'viewHr'),
  ('transportManager', 'viewAdminHub'), ('transportManager', 'viewTransport'), ('transportManager', 'manageTransport'),
  ('hostelManager', 'viewAdminHub'), ('hostelManager', 'viewHostel'), ('hostelManager', 'manageHostel'),
  ('inventoryManager', 'viewAdminHub'), ('inventoryManager', 'viewInventory'), ('inventoryManager', 'manageInventory'),
  ('marketingManager', 'viewAdminHub'),
  ('organizationAdmin', 'viewOrganization'), ('organizationAdmin', 'manageOrganization'),
  ('organizationAdmin', 'viewSchoolGroups'), ('organizationAdmin', 'manageSchoolGroups'),
  ('organizationAdmin', 'viewControlCenter'), ('organizationAdmin', 'manageControlCenter'),
  ('organizationAdmin', 'viewManagement'), ('organizationAdmin', 'viewAdminHub'),
  ('organizationAdmin', 'viewAdmissions'), ('organizationAdmin', 'viewFinance'), ('organizationAdmin', 'viewSis'),
  ('organizationAdmin', 'viewTransport'), ('organizationAdmin', 'viewHr'), ('organizationAdmin', 'viewHostel'),
  ('organizationAdmin', 'viewLibrary'), ('organizationAdmin', 'viewInventory'), ('organizationAdmin', 'viewAlumni'),
  ('organizationOwner', 'viewOrganization'), ('organizationOwner', 'manageOrganization'),
  ('organizationOwner', 'viewSchoolGroups'), ('organizationOwner', 'manageSchoolGroups'),
  ('organizationOwner', 'viewControlCenter'), ('organizationOwner', 'manageControlCenter'),
  ('organizationOwner', 'viewManagement'), ('organizationOwner', 'viewAdminHub'),
  ('organizationOwner', 'viewAdmissions'), ('organizationOwner', 'viewFinance'), ('organizationOwner', 'viewSis'),
  ('organizationOwner', 'viewTransport'), ('organizationOwner', 'viewHr'), ('organizationOwner', 'viewHostel'),
  ('organizationOwner', 'viewLibrary'), ('organizationOwner', 'viewInventory'), ('organizationOwner', 'viewAlumni'),
  ('schoolGroupDirector', 'viewSchoolGroups'), ('schoolGroupDirector', 'viewManagement'),
  ('schoolGroupDirector', 'viewAdminHub'), ('schoolGroupDirector', 'viewAdmissions'),
  ('schoolGroupDirector', 'viewFinance'), ('schoolGroupDirector', 'viewSis'), ('schoolGroupDirector', 'viewTransport'),
  ('schoolGroupDirector', 'viewHr'), ('schoolGroupDirector', 'viewHostel'), ('schoolGroupDirector', 'viewLibrary'),
  ('schoolGroupDirector', 'viewInventory'), ('schoolGroupDirector', 'viewAlumni');

INSERT INTO role_permissions (role_slug, permission_slug)
SELECT role_slug, permission_slug FROM _role_perm_seed
ON CONFLICT DO NOTHING;

-- ─── Backfill multi-role from legacy membership.role column ─────────────────

INSERT INTO school_membership_roles (school_membership_id, role_slug, is_primary, status)
SELECT id, role, true, 'active'
FROM school_memberships
WHERE role IS NOT NULL AND role <> ''
ON CONFLICT (school_membership_id, role_slug) DO NOTHING;

INSERT INTO organization_membership_roles (organization_membership_id, role_slug, is_primary, status)
SELECT id, role, true, 'active'
FROM organization_memberships
WHERE role IS NOT NULL AND role <> ''
ON CONFLICT (organization_membership_id, role_slug) DO NOTHING;
