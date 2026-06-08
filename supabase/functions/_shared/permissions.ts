const ROLE_PERMISSIONS: Record<string, string[]> = {
  superAdmin: [
    "viewAdminHub", "viewAdmissions", "manageAdmissions", "approveAdmissions",
    "viewFinance", "manageFinance", "approveRefunds", "viewSis", "manageSis",
    "viewManagement", "manageManagement", "viewTransport", "manageTransport",
    "viewHr", "manageHr", "viewHostel", "manageHostel", "viewLibrary",
    "manageLibrary", "viewInventory", "manageInventory", "viewAlumni",
    "manageAlumni", "viewControlCenter", "manageControlCenter",
  ],
  schoolAdmin: [
    "viewAdminHub", "viewAdmissions", "manageAdmissions", "approveAdmissions",
    "viewFinance", "manageFinance", "approveRefunds", "viewSis", "manageSis",
    "viewManagement", "manageManagement", "viewTransport", "manageTransport",
    "viewHr", "manageHr", "viewHostel", "manageHostel", "viewLibrary",
    "manageLibrary", "viewInventory", "manageInventory", "viewAlumni",
    "manageAlumni",
  ],
  principal: [
    "viewAdminHub", "viewAdmissions", "manageAdmissions", "approveAdmissions",
    "viewFinance", "viewSis", "manageSis", "viewManagement", "manageManagement",
    "viewLibrary", "viewHr", "viewAlumni",
  ],
  financeAdmin: [
    "viewAdminHub", "viewFinance", "manageFinance", "approveRefunds",
  ],
  teacher: ["viewAdminHub"],
  parent: [],
  student: [],
  management: [
    "viewAdminHub", "viewManagement", "manageManagement", "viewFinance",
    "viewSis", "viewAdmissions", "viewHr",
  ],
  admissionsCounselor: [
    "viewAdminHub", "viewAdmissions", "manageAdmissions",
  ],
  transportManager: ["viewAdminHub", "viewTransport", "manageTransport"],
  hostelManager: ["viewAdminHub", "viewHostel", "manageHostel"],
  librarian: ["viewAdminHub", "viewLibrary", "manageLibrary"],
  inventoryManager: ["viewAdminHub", "viewInventory", "manageInventory"],
  organizationAdmin: [
    "viewOrganization", "manageOrganization", "viewSchoolGroups",
    "manageSchoolGroups", "viewControlCenter", "manageControlCenter",
    "viewManagement", "viewAdminHub", "viewAdmissions", "viewFinance",
    "viewSis", "viewTransport", "viewHr", "viewHostel", "viewLibrary",
    "viewInventory", "viewAlumni",
  ],
};

export function permissionsForRole(role: string): string[] {
  return ROLE_PERMISSIONS[role] ?? ["viewAdminHub"];
}

export function permissionsPayload(role: string) {
  return permissionsForRole(role).map((permission) => ({
    permission,
    source: "server",
  }));
}
