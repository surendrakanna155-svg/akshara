/**
 * Role model — ports lib/core/security/erp_role.dart (15 ERP staff roles) plus
 * the parent/teacher/student portal roles from lib/features/auth/auth_models.dart.
 *
 * `workspace` groups roles the way the Flutter app's persona shells do; `landing`
 * is where the role lands after login; `modules` is the set of nav module keys
 * the role may access (RBAC — approximate until the live /auth/permissions matrix
 * is wired, at which point the granted set overrides this).
 */
export type RoleKind = 'staff' | 'portal';

export type Workspace = 'erp' | 'management' | 'director' | 'teacher' | 'parent' | 'student';

export type ErpRole =
  | 'superAdmin'
  | 'schoolAdmin'
  | 'principal'
  | 'vicePrincipal'
  | 'management'
  | 'financeAdmin'
  | 'admissionsCounselor'
  | 'teacher'
  | 'parent'
  | 'student'
  | 'transportManager'
  | 'hostelManager'
  | 'librarian'
  | 'inventoryManager'
  | 'storekeeper';

export interface RoleMeta {
  role: ErpRole;
  label: string;
  icon: string;
  kind: RoleKind;
  workspace: Workspace;
  landing: string;
  /** '*' = all ERP modules; otherwise explicit module keys (see navConfig). */
  modules: '*' | string[];
}

export const ROLE_META: Record<ErpRole, RoleMeta> = {
  superAdmin: { role: 'superAdmin', label: 'Super Admin', icon: 'admin_panel_settings', kind: 'staff', workspace: 'erp', landing: '/admin/dashboard', modules: '*' },
  schoolAdmin: { role: 'schoolAdmin', label: 'School Admin', icon: 'shield_person', kind: 'staff', workspace: 'erp', landing: '/admin/dashboard', modules: '*' },
  principal: { role: 'principal', label: 'Principal', icon: 'workspace_premium', kind: 'staff', workspace: 'management', landing: '/management/dashboard', modules: '*' },
  vicePrincipal: { role: 'vicePrincipal', label: 'Vice Principal', icon: 'supervisor_account', kind: 'staff', workspace: 'management', landing: '/management/dashboard', modules: '*' },
  management: { role: 'management', label: 'Management', icon: 'insights', kind: 'staff', workspace: 'management', landing: '/management/dashboard', modules: '*' },
  financeAdmin: {
    role: 'financeAdmin', label: 'Finance Admin', icon: 'account_balance', kind: 'staff', workspace: 'erp', landing: '/finance/dashboard',
    modules: ['dashboard', 'finance', 'sis', 'admissions', 'reports', 'communication', 'settings'],
  },
  admissionsCounselor: {
    role: 'admissionsCounselor', label: 'Admissions Counselor', icon: 'how_to_reg', kind: 'staff', workspace: 'erp', landing: '/admissions/dashboard',
    modules: ['dashboard', 'admissions', 'sis', 'communication', 'reports', 'settings'],
  },
  teacher: { role: 'teacher', label: 'Teacher', icon: 'cast_for_education', kind: 'portal', workspace: 'teacher', landing: '/teacher/today', modules: ['teacher'] },
  parent: { role: 'parent', label: 'Parent', icon: 'family_restroom', kind: 'portal', workspace: 'parent', landing: '/parent/dashboard', modules: ['parent'] },
  student: { role: 'student', label: 'Student', icon: 'school', kind: 'portal', workspace: 'student', landing: '/student/dashboard', modules: ['student'] },
  transportManager: {
    role: 'transportManager', label: 'Transport Manager', icon: 'directions_bus', kind: 'staff', workspace: 'erp', landing: '/transport/dashboard',
    modules: ['dashboard', 'transport', 'sis', 'communication', 'reports', 'settings'],
  },
  hostelManager: {
    role: 'hostelManager', label: 'Hostel Manager', icon: 'night_shelter', kind: 'staff', workspace: 'erp', landing: '/hostel/dashboard',
    modules: ['dashboard', 'hostel', 'sis', 'communication', 'reports', 'settings'],
  },
  librarian: {
    role: 'librarian', label: 'Librarian', icon: 'local_library', kind: 'staff', workspace: 'erp', landing: '/library/dashboard',
    modules: ['dashboard', 'library', 'sis', 'reports', 'settings'],
  },
  inventoryManager: {
    role: 'inventoryManager', label: 'Inventory Manager', icon: 'inventory_2', kind: 'staff', workspace: 'erp', landing: '/inventory/dashboard',
    modules: ['dashboard', 'inventory', 'reports', 'settings'],
  },
  storekeeper: {
    role: 'storekeeper', label: 'Storekeeper', icon: 'warehouse', kind: 'staff', workspace: 'erp', landing: '/inventory/stock',
    modules: ['dashboard', 'inventory', 'settings'],
  },
};

export const ALL_ROLES = Object.values(ROLE_META);

/** Roles offered in the demo role switcher (mirrors ErpRole.staffErpRoles + portals). */
export const DEMO_ROLES: ErpRole[] = [
  'schoolAdmin',
  'principal',
  'management',
  'financeAdmin',
  'admissionsCounselor',
  'teacher',
  'parent',
  'student',
  'transportManager',
  'hostelManager',
  'librarian',
  'inventoryManager',
];

export function roleMeta(role: ErpRole): RoleMeta {
  return ROLE_META[role];
}

export function canAccess(role: ErpRole, moduleKey: string): boolean {
  const m = ROLE_META[role].modules;
  return m === '*' || m.includes(moduleKey);
}
