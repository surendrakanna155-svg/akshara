import 'erp_role.dart';
import 'permissions.dart';

/// View / manage / approve permissions for each ERP module.
class ModulePermissionSet {
  const ModulePermissionSet({
    required this.moduleId,
    required this.view,
    this.manage,
    this.approve,
  });

  final String moduleId;
  final Permission view;
  final Permission? manage;
  final Permission? approve;
}

/// Canonical RBAC mapping used by validation suites and coverage inventory.
class RbacModuleRegistry {
  const RbacModuleRegistry._();

  static const modules = <ModulePermissionSet>[
    ModulePermissionSet(
      moduleId: 'admissions',
      view: Permission.viewAdmissions,
      manage: Permission.manageAdmissions,
      approve: Permission.approveAdmissions,
    ),
    ModulePermissionSet(
      moduleId: 'finance',
      view: Permission.viewFinance,
      manage: Permission.manageFinance,
      approve: Permission.approveRefunds,
    ),
    ModulePermissionSet(
      moduleId: 'sis',
      view: Permission.viewSis,
      manage: Permission.manageSis,
    ),
    ModulePermissionSet(
      moduleId: 'management',
      view: Permission.viewManagement,
      manage: Permission.manageManagement,
    ),
    ModulePermissionSet(
      moduleId: 'transport',
      view: Permission.viewTransport,
      manage: Permission.manageTransport,
    ),
    ModulePermissionSet(
      moduleId: 'hr',
      view: Permission.viewHr,
      manage: Permission.manageHr,
    ),
    ModulePermissionSet(
      moduleId: 'hostel',
      view: Permission.viewHostel,
      manage: Permission.manageHostel,
    ),
    ModulePermissionSet(
      moduleId: 'library',
      view: Permission.viewLibrary,
      manage: Permission.manageLibrary,
    ),
    ModulePermissionSet(
      moduleId: 'inventory',
      view: Permission.viewInventory,
      manage: Permission.manageInventory,
    ),
    ModulePermissionSet(
      moduleId: 'alumni',
      view: Permission.viewAlumni,
      manage: Permission.manageAlumni,
    ),
    ModulePermissionSet(
      moduleId: 'control_center',
      view: Permission.viewControlCenter,
      manage: Permission.manageControlCenter,
    ),
    ModulePermissionSet(
      moduleId: 'admin',
      view: Permission.viewAdminHub,
    ),
  ];

  static ModulePermissionSet? forModule(String moduleId) {
    for (final module in modules) {
      if (module.moduleId == moduleId) return module;
    }
    return null;
  }

  /// Control Center requires Super Admin role in addition to view permission.
  static bool canAccessControlCenter({
    required ErpRole? role,
    required bool hasViewPermission,
  }) {
    return role == ErpRole.superAdmin && hasViewPermission;
  }
}
