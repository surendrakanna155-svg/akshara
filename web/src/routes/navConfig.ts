/**
 * Navigation model for the web platform. Ports the module structure from
 * lib/router/*_navigation.dart into a desktop sidebar IA.
 *
 * `moduleKey` gates the item via RBAC (see roles.ts `canAccess`). Each top-level
 * item routes to its module landing; sub-pages live in the module's in-page nav.
 */
import type { ErpRole, Workspace } from '@/lib/auth/roles';
import { ROLE_META } from '@/lib/auth/roles';

export interface NavItem {
  key: string;
  label: string;
  icon: string;
  path: string;
  moduleKey: string;
}

export interface NavSection {
  label: string;
  items: NavItem[];
}

/** The staff / ERP-console sidebar (schoolAdmin, principal, finance, etc.). */
export const ERP_NAV: NavSection[] = [
  {
    label: 'Overview',
    items: [
      { key: 'dashboard', label: 'Dashboard', icon: 'dashboard', path: '/admin/dashboard', moduleKey: 'dashboard' },
      { key: 'management', label: 'Management', icon: 'insights', path: '/management/dashboard', moduleKey: 'management' },
      { key: 'director', label: 'Director', icon: 'corporate_fare', path: '/director/dashboard', moduleKey: 'management' },
      { key: 'intelligence', label: 'Intelligence', icon: 'auto_awesome', path: '/intelligence', moduleKey: 'management' },
      { key: 'copilot', label: 'Copilot', icon: 'smart_toy', path: '/copilot', moduleKey: 'dashboard' },
    ],
  },
  {
    label: 'People',
    items: [
      { key: 'sis', label: 'Students', icon: 'groups', path: '/sis/registry', moduleKey: 'sis' },
      { key: 'admissions', label: 'Admissions', icon: 'how_to_reg', path: '/admissions/dashboard', moduleKey: 'admissions' },
      { key: 'hr', label: 'Staff & HR', icon: 'badge', path: '/hr/employees', moduleKey: 'hr' },
      { key: 'alumni', label: 'Alumni', icon: 'diversity_3', path: '/alumni/dashboard', moduleKey: 'management' },
    ],
  },
  {
    label: 'Academics',
    items: [
      { key: 'academics', label: 'Academics', icon: 'menu_book', path: '/academics', moduleKey: 'academics' },
      { key: 'exams', label: 'Examinations', icon: 'grading', path: '/academics/exams', moduleKey: 'academics' },
      { key: 'timetable', label: 'Timetable', icon: 'calendar_view_week', path: '/academics/timetable', moduleKey: 'academics' },
    ],
  },
  {
    label: 'Operations',
    items: [
      { key: 'attendance', label: 'Attendance', icon: 'fact_check', path: '/attendance', moduleKey: 'management' },
      { key: 'transport', label: 'Transport', icon: 'directions_bus', path: '/transport/dashboard', moduleKey: 'transport' },
      { key: 'hostel', label: 'Hostel', icon: 'night_shelter', path: '/hostel/dashboard', moduleKey: 'hostel' },
      { key: 'library', label: 'Library', icon: 'local_library', path: '/library/dashboard', moduleKey: 'library' },
      { key: 'inventory', label: 'Inventory', icon: 'inventory_2', path: '/inventory/dashboard', moduleKey: 'inventory' },
    ],
  },
  {
    label: 'Finance',
    items: [{ key: 'finance', label: 'Finance', icon: 'account_balance', path: '/finance/dashboard', moduleKey: 'finance' }],
  },
  {
    label: 'Engage',
    items: [
      { key: 'communication', label: 'Communication', icon: 'campaign', path: '/communication', moduleKey: 'communication' },
      { key: 'reports', label: 'Reports', icon: 'summarize', path: '/reports', moduleKey: 'reports' },
    ],
  },
  {
    label: 'Configure',
    items: [
      { key: 'school_config', label: 'School Setup', icon: 'school', path: '/school-config', moduleKey: 'settings' },
      { key: 'school_ops', label: 'Setup & Ops', icon: 'tune', path: '/school-completion', moduleKey: 'settings' },
      { key: 'operations', label: 'Operations', icon: 'engineering', path: '/operations', moduleKey: 'settings' },
      { key: 'admin', label: 'Admin', icon: 'admin_panel_settings', path: '/admin', moduleKey: 'settings' },
      { key: 'settings', label: 'Settings', icon: 'settings', path: '/settings', moduleKey: 'settings' },
    ],
  },
];

/**
 * ASIP Platform Support Console nav (scoped unfreeze, ASIP_DESIGN.md §6.1).
 * Deliberately a SEPARATE section — NOT part of ERP_NAV / PORTAL_NAV — so the
 * router's scaffold generator (which walks only those) never routes it, and it
 * only ever appears for a session holding the `platformSupport` permission
 * (appended by AppShell). `moduleKey` is a sentinel; RBAC is the permission gate.
 */
export const SUPPORT_CONSOLE_NAV: NavSection = {
  label: 'Platform Support',
  items: [
    { key: 'support-console', label: 'Support Console', icon: 'support_agent', path: '/support-console', moduleKey: 'supportConsole' },
  ],
};

/** Portal navs — parent / teacher / student (mobile-first screens on web). */
export const PORTAL_NAV: Record<'teacher' | 'parent' | 'student', NavItem[]> = {
  teacher: [
    { key: 't-today', label: 'Today', icon: 'today', path: '/teacher/today', moduleKey: 'teacher' },
    { key: 't-dash', label: 'Dashboard', icon: 'dashboard', path: '/teacher/dashboard', moduleKey: 'teacher' },
    { key: 't-attn', label: 'Attendance', icon: 'fact_check', path: '/teacher/attendance', moduleKey: 'teacher' },
    { key: 't-tt', label: 'Timetable', icon: 'calendar_view_week', path: '/teacher/timetable', moduleKey: 'teacher' },
    { key: 't-hw', label: 'Homework', icon: 'assignment', path: '/teacher/homework', moduleKey: 'teacher' },
    { key: 't-exams', label: 'Exams', icon: 'grading', path: '/teacher/exams', moduleKey: 'teacher' },
    { key: 't-msg', label: 'Messages', icon: 'forum', path: '/teacher/messages', moduleKey: 'teacher' },
    { key: 't-leave', label: 'Leave', icon: 'event_busy', path: '/teacher/leave', moduleKey: 'teacher' },
  ],
  parent: [
    { key: 'p-dash', label: 'Home', icon: 'home', path: '/parent/dashboard', moduleKey: 'parent' },
    { key: 'p-attn', label: 'Attendance', icon: 'fact_check', path: '/parent/attendance', moduleKey: 'parent' },
    { key: 'p-tt', label: 'Timetable', icon: 'calendar_view_week', path: '/parent/timetable', moduleKey: 'parent' },
    { key: 'p-hw', label: 'Homework', icon: 'assignment', path: '/parent/homework', moduleKey: 'parent' },
    { key: 'p-exams', label: 'Exams', icon: 'grading', path: '/parent/exams', moduleKey: 'parent' },
    { key: 'p-fees', label: 'Fees', icon: 'payments', path: '/parent/fees', moduleKey: 'parent' },
    { key: 'p-notice', label: 'Notices', icon: 'notifications', path: '/parent/notices', moduleKey: 'parent' },
    { key: 'p-msg', label: 'Messages', icon: 'forum', path: '/parent/messages', moduleKey: 'parent' },
    { key: 'p-transport', label: 'Transport', icon: 'directions_bus', path: '/parent/transport', moduleKey: 'parent' },
  ],
  student: [
    { key: 's-dash', label: 'Home', icon: 'home', path: '/student/dashboard', moduleKey: 'student' },
    { key: 's-attn', label: 'Attendance', icon: 'fact_check', path: '/student/attendance', moduleKey: 'student' },
    { key: 's-tt', label: 'Timetable', icon: 'calendar_view_week', path: '/student/timetable', moduleKey: 'student' },
    { key: 's-hw', label: 'Homework', icon: 'assignment', path: '/student/homework', moduleKey: 'student' },
    { key: 's-exams', label: 'Exams', icon: 'grading', path: '/student/exams', moduleKey: 'student' },
    { key: 's-report', label: 'Report Card', icon: 'assessment', path: '/student/report-card', moduleKey: 'student' },
    { key: 's-notice', label: 'Notices', icon: 'notifications', path: '/student/notices', moduleKey: 'student' },
  ],
};

/** Secondary (in-module) tab navigation, keyed by module. */
export const MODULE_TABS: Record<string, { label: string; path: string }[]> = {
  attendance: [
    { label: 'Overview', path: '/attendance' },
    { label: 'Register', path: '/attendance/register' },
    { label: 'Corrections', path: '/attendance/corrections' },
  ],
  management: [
    { label: 'Dashboard', path: '/management/dashboard' },
    { label: 'Analytics', path: '/management/analytics' },
    { label: 'Admissions', path: '/management/admissions' },
    { label: 'Finance', path: '/management/finance' },
    { label: 'Academics', path: '/management/academics' },
    { label: 'Performance', path: '/management/performance' },
    { label: 'Approvals', path: '/management/approvals' },
    { label: 'Tasks', path: '/management/tasks' },
    { label: 'Settings', path: '/management/settings' },
  ],
  director: [
    { label: 'Dashboard', path: '/director/dashboard' },
    { label: 'Schools', path: '/director/schools' },
    { label: 'Portfolio', path: '/director/portfolio' },
    { label: 'Revenue', path: '/director/revenue' },
    { label: 'Admissions', path: '/director/admissions' },
    { label: 'Growth', path: '/director/growth' },
    { label: 'Marketing', path: '/director/marketing' },
    { label: 'Compliance', path: '/director/compliance' },
    { label: 'Reports', path: '/director/reports' },
  ],
  intelligence: [
    { label: 'Overview', path: '/intelligence' },
    { label: 'Student Success', path: '/intelligence/student-success' },
    { label: 'Teacher Effectiveness', path: '/intelligence/teacher-effectiveness' },
    { label: 'Exam Intelligence', path: '/intelligence/exams' },
    { label: 'Homework Intelligence', path: '/intelligence/homework' },
    { label: 'Trust', path: '/intelligence/trust' },
    { label: 'AI Economics', path: '/intelligence/ai-economics' },
  ],
  academics: [
    { label: 'Examinations', path: '/academics/exams' },
    { label: 'Marks Entry', path: '/academics/exams/marks-entry' },
    { label: 'Progress', path: '/academics/exams/progress' },
    { label: 'Reports', path: '/academics/exams/reports' },
    { label: 'Timetable', path: '/academics/timetable' },
    { label: 'Substitutions', path: '/academics/substitutions' },
  ],
  sis: [
    { label: 'Overview', path: '/sis/dashboard' },
    { label: 'Registry', path: '/sis/registry' },
    { label: 'Academic Assignment', path: '/sis/academic-assignment' },
    { label: 'Admissions Conversion', path: '/sis/admissions-conversion' },
    { label: 'Promotion', path: '/sis/promotion' },
    { label: 'Reshuffle', path: '/sis/reshuffle' },
    { label: 'Section Balance', path: '/sis/section-balance' },
    { label: 'Transfers', path: '/sis/transfers' },
  ],
  admissions: [
    { label: 'Overview', path: '/admissions/dashboard' },
    { label: 'Leads', path: '/admissions/leads' },
    { label: 'Applications', path: '/admissions/applications' },
    { label: 'Approvals', path: '/admissions/approval' },
    { label: 'Documents', path: '/admissions/documents' },
    { label: 'Enrolment', path: '/admissions/enrollment' },
    { label: 'Reports', path: '/admissions/reports' },
    { label: 'Settings', path: '/admissions/settings' },
  ],
  alumni: [
    { label: 'Overview', path: '/alumni/dashboard' },
    { label: 'Registry', path: '/alumni/registry' },
    { label: 'Campaigns', path: '/alumni/campaigns' },
    { label: 'Donations', path: '/alumni/donations' },
    { label: 'Events', path: '/alumni/events' },
    { label: 'Mentorship', path: '/alumni/mentorship' },
    { label: 'Reports', path: '/alumni/reports' },
    { label: 'Settings', path: '/alumni/settings' },
  ],
  inventory: [
    { label: 'Overview', path: '/inventory/dashboard' },
    { label: 'Stock', path: '/inventory/stock' },
    { label: 'Approvals', path: '/inventory/stock-approvals' },
    { label: 'Assets', path: '/inventory/assets' },
    { label: 'Categories', path: '/inventory/categories' },
    { label: 'Allocations', path: '/inventory/allocation' },
    { label: 'Distribution', path: '/inventory/distribution' },
    { label: 'Maintenance', path: '/inventory/maintenance' },
    { label: 'Replacement', path: '/inventory/replacement' },
    { label: 'Procurement', path: '/inventory/procurement' },
    { label: 'Vendors', path: '/inventory/vendors' },
    { label: 'Lifecycle', path: '/inventory/lifecycle' },
    { label: 'Reports', path: '/inventory/reports' },
    { label: 'Copilot', path: '/inventory/copilot' },
  ],
  hostel: [
    { label: 'Overview', path: '/hostel/dashboard' },
    { label: 'Residents', path: '/hostel/students' },
    { label: 'Rooms', path: '/hostel/rooms' },
    { label: 'Attendance', path: '/hostel/attendance' },
    { label: 'Leave', path: '/hostel/leave' },
    { label: 'Mess', path: '/hostel/mess' },
    { label: 'Visitors', path: '/hostel/visitors' },
    { label: 'Reports', path: '/hostel/reports' },
  ],
  library: [
    { label: 'Overview', path: '/library/dashboard' },
    { label: 'Catalog', path: '/library/catalog' },
    { label: 'Issues', path: '/library/issues' },
    { label: 'Returns', path: '/library/returns' },
    { label: 'Members', path: '/library/members' },
    { label: 'Fines', path: '/library/fines' },
    { label: 'Overdue', path: '/library/overdue' },
    { label: 'Resources', path: '/library/resources' },
    { label: 'Reports', path: '/library/reports' },
  ],
  transport: [
    { label: 'Overview', path: '/transport/dashboard' },
    { label: 'Routes', path: '/transport/routes' },
    { label: 'Vehicles', path: '/transport/vehicles' },
    { label: 'Drivers', path: '/transport/drivers' },
    { label: 'Allocations', path: '/transport/allocation' },
    { label: 'Attendance', path: '/transport/attendance' },
    { label: 'Live Tracking', path: '/transport/tracking' },
    { label: 'Reports', path: '/transport/reports' },
    { label: 'Settings', path: '/transport/settings' },
  ],
  finance: [
    { label: 'Overview', path: '/finance/dashboard' },
    { label: 'Collections', path: '/finance/collections' },
    { label: 'Student Accounts', path: '/finance/student-accounts' },
    { label: 'Fee Structures', path: '/finance/fee-structures' },
    { label: 'Defaulters', path: '/finance/defaulters' },
    { label: 'Discounts', path: '/finance/discounts' },
    { label: 'Refunds', path: '/finance/refunds' },
    { label: 'Offline', path: '/finance/offline-payments' },
    { label: 'QR', path: '/finance/qr-payment' },
    { label: 'Reconciliation', path: '/finance/reconciliation' },
    { label: 'Executive', path: '/finance/executive' },
    { label: 'Copilot', path: '/finance/copilot' },
    { label: 'Reports', path: '/finance/reports' },
    { label: 'Settings', path: '/finance/settings' },
  ],
  hr: [
    { label: 'Overview', path: '/hr/dashboard' },
    { label: 'Employees', path: '/hr/employees' },
    { label: 'Attendance', path: '/hr/attendance' },
    { label: 'Leave', path: '/hr/leave' },
    { label: 'Payroll', path: '/hr/payroll' },
    { label: 'Recruitment', path: '/hr/recruitment' },
    { label: 'Performance', path: '/hr/performance' },
    { label: 'Reports', path: '/hr/reports' },
    { label: 'Settings', path: '/hr/settings' },
  ],
};

/**
 * Filters the ERP sidebar to sections/items the role may access.
 * When `granted` (live grants from /auth/permissions) is provided, it OVERRIDES
 * the approximate role→module map; otherwise the role map is used.
 */
export function navForRole(role: ErpRole, granted?: string[] | null): NavSection[] {
  const modules = ROLE_META[role].modules;
  const allow = (moduleKey: string): boolean => {
    if (granted && granted.length > 0) return granted.includes(moduleKey);
    return modules === '*' || modules.includes(moduleKey);
  };
  if (!granted && modules === '*') return ERP_NAV;
  return ERP_NAV.map((s) => ({ ...s, items: s.items.filter((i) => allow(i.moduleKey)) })).filter(
    (s) => s.items.length > 0,
  );
}

export function workspaceForRole(role: ErpRole): Workspace {
  return ROLE_META[role].workspace;
}
