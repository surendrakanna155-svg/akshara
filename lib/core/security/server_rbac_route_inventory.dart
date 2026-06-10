/// Server-side RBAC route rules mirrored from backend validation inventory.
abstract final class ServerRbacRouteInventory {
  static const modules = [
    'admissions',
    'finance',
    'sis',
    'academic',
    'transport',
    'hr',
    'hostel',
    'library',
    'inventory',
    'alumni',
    'management',
    'control_center',
    'parent',
    'teacher',
    'student',
    'audit',
    'copilot',
    'analytics',
  ];

  static const permissionSlugs = [
    'viewAdmissions',
    'manageAdmissions',
    'approveAdmissions',
    'viewFinance',
    'manageFinance',
    'approveRefunds',
    'viewSis',
    'manageSis',
    'viewTransport',
    'viewHr',
    'viewHostel',
    'viewLibrary',
    'viewInventory',
    'viewAlumni',
    'viewManagement',
    'viewControlCenter',
    'viewAdminHub',
    'viewAiCopilot',
    'runAiCopilot',
    'viewAcademicTimetable',
    'manageAcademicTimetable',
    'publishAcademicTimetable',
    'viewAnalytics',
    'viewSchoolHealth',
  ];

  static const protectedRouteCount = 24;
}
