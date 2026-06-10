/** Server RBAC route inventory — permission + scope requirements for protected API routes. */
export type RbacScope = "school" | "organization" | "parent" | "student";

export interface RbacRouteRule {
  method: string;
  path: string;
  permission: string | null;
  scope: RbacScope;
  module: string;
}

export const RBAC_ROUTE_INVENTORY: RbacRouteRule[] = [
  { method: "GET", path: "/admissions/dashboard", permission: "viewAdmissions", scope: "school", module: "admissions" },
  { method: "POST", path: "/admissions/leads", permission: "manageAdmissions", scope: "school", module: "admissions" },
  { method: "POST", path: "/admissions/approvals/:id/approve", permission: "approveAdmissions", scope: "school", module: "admissions" },
  { method: "GET", path: "/finance/dashboard", permission: "viewFinance", scope: "school", module: "finance" },
  { method: "POST", path: "/finance/fee-structures", permission: "manageFinance", scope: "school", module: "finance" },
  { method: "POST", path: "/finance/refunds/:id/approve", permission: "approveRefunds", scope: "school", module: "finance" },
  { method: "GET", path: "/sis/dashboard", permission: "viewSis", scope: "school", module: "sis" },
  { method: "POST", path: "/sis/students", permission: "manageSis", scope: "school", module: "sis" },
  { method: "GET", path: "/academic/years", permission: "viewSis", scope: "school", module: "academic" },
  { method: "GET", path: "/transport/dashboard", permission: "viewTransport", scope: "school", module: "transport" },
  { method: "GET", path: "/hr/dashboard", permission: "viewHr", scope: "school", module: "hr" },
  { method: "GET", path: "/hostel/dashboard", permission: "viewHostel", scope: "school", module: "hostel" },
  { method: "GET", path: "/library/dashboard", permission: "viewLibrary", scope: "school", module: "library" },
  { method: "GET", path: "/inventory/dashboard", permission: "viewInventory", scope: "school", module: "inventory" },
  { method: "GET", path: "/alumni/dashboard", permission: "viewAlumni", scope: "school", module: "alumni" },
  { method: "GET", path: "/management/dashboard", permission: "viewManagement", scope: "school", module: "management" },
  { method: "GET", path: "/control-center/dashboard", permission: "viewControlCenter", scope: "organization", module: "control_center" },
  { method: "GET", path: "/parent/dashboard", permission: null, scope: "parent", module: "parent" },
  { method: "POST", path: "/parent/payments/initiate", permission: null, scope: "parent", module: "parent" },
  { method: "POST", path: "/parent/payments/confirm", permission: null, scope: "parent", module: "parent" },
  { method: "POST", path: "/payments/intents/initiate", permission: null, scope: "parent", module: "payment" },
  { method: "POST", path: "/payments/intents/confirm", permission: null, scope: "parent", module: "payment" },
  { method: "GET", path: "/payments/intents/:id", permission: "viewPayments", scope: "school", module: "payment" },
  { method: "GET", path: "/teacher/dashboard", permission: "viewAdminHub", scope: "school", module: "teacher" },
  { method: "GET", path: "/student/dashboard", permission: null, scope: "student", module: "student" },
  { method: "POST", path: "/audit/events/batch", permission: null, scope: "school", module: "audit" },
  { method: "GET", path: "/communications/templates", permission: "viewCommunications", scope: "school", module: "communication" },
  { method: "POST", path: "/communications/broadcasts", permission: "sendBroadcast", scope: "school", module: "communication" },
  { method: "GET", path: "/parent/notifications", permission: null, scope: "parent", module: "communication" },
  { method: "GET", path: "/student/notifications", permission: null, scope: "student", module: "communication" },
];

export const RBAC_MODULE_PERMISSIONS = [
  "viewAdmissions", "manageAdmissions", "approveAdmissions",
  "viewFinance", "manageFinance", "approveRefunds",
  "viewSis", "manageSis",
  "viewTransport", "viewHr", "viewHostel", "viewLibrary", "viewInventory", "viewAlumni",
  "viewManagement", "viewControlCenter", "viewAdminHub", "viewPayments",
  "viewCommunications", "manageCommunications", "sendBroadcast",
] as const;
