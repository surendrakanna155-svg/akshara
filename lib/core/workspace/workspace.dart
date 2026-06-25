import 'package:flutter/material.dart';

import '../../features/admin/models/admin_nav_models.dart';
import '../../features/auth/auth_models.dart';
import '../../router/route_names.dart';
import '../security/erp_role.dart';

/// A first-class **workspace** — a named bundle of modules/tasks for ONE
/// responsibility (a "hat" the user wears). The target model is
/// USER → ROLE → WORKSPACE → TASK: a user holds one or more roles, each role
/// grants one or more workspaces, and a workspace bounds what the user sees.
///
/// A multi-hat user (e.g. Teacher + Inventory Manager) gets several workspaces
/// and flips between them with the workspace switcher.
enum WorkspaceId {
  schoolAdministration,
  teaching,
  finance,
  frontOffice,
  inventory,
  transport,
  hostel,
  library,
  parentSpace,
  studentSpace,
}

@immutable
class Workspace {
  const Workspace({
    required this.id,
    required this.title,
    required this.shortTitle,
    required this.icon,
    required this.homeRoute,
    required this.shell,
    this.modules = const <AdminModule>{},
  });

  final WorkspaceId id;
  final String title;
  final String shortTitle;
  final IconData icon;

  /// Where the switcher lands when this workspace is activated.
  final String homeRoute;

  /// Which app shell this workspace lives in (staff/teacher/parent/student).
  final UserRole shell;

  /// Admin ERP modules this workspace contains (empty for non-staff shells,
  /// which are their own dedicated apps).
  final Set<AdminModule> modules;

  bool containsModule(AdminModule module) => modules.contains(module);
}

/// Canonical workspace definitions.
const Map<WorkspaceId, Workspace> kWorkspaceCatalog = {
  WorkspaceId.schoolAdministration: Workspace(
    id: WorkspaceId.schoolAdministration,
    title: 'School Administration',
    shortTitle: 'Administration',
    icon: Icons.account_balance_outlined,
    homeRoute: RouteNames.admin,
    shell: UserRole.staff,
    modules: {
      AdminModule.admin,
      AdminModule.admissions,
      AdminModule.marketing,
      AdminModule.finance,
      AdminModule.sis,
      AdminModule.hr,
      AdminModule.management,
      AdminModule.transport,
      AdminModule.hostel,
      AdminModule.library,
      AdminModule.inventory,
      AdminModule.alumni,
      // Multi-school management (permission-gated: superAdmin / management).
      AdminModule.controlCenter,
      AdminModule.director,
      AdminModule.dynamicWidgets,
    },
  ),
  WorkspaceId.teaching: Workspace(
    id: WorkspaceId.teaching,
    title: 'Teacher Workspace',
    shortTitle: 'Teaching',
    icon: Icons.co_present_outlined,
    homeRoute: RouteNames.teacherDashboard,
    shell: UserRole.teacher,
  ),
  WorkspaceId.finance: Workspace(
    id: WorkspaceId.finance,
    title: 'Finance Workspace',
    shortTitle: 'Finance',
    icon: Icons.account_balance_wallet_outlined,
    homeRoute: RouteNames.financeDashboard,
    shell: UserRole.staff,
    modules: {AdminModule.finance},
  ),
  WorkspaceId.frontOffice: Workspace(
    id: WorkspaceId.frontOffice,
    title: 'Front Office Workspace',
    shortTitle: 'Front Office',
    icon: Icons.support_agent_outlined,
    homeRoute: RouteNames.admissionsDashboard,
    shell: UserRole.staff,
    modules: {AdminModule.admissions, AdminModule.marketing},
  ),
  WorkspaceId.inventory: Workspace(
    id: WorkspaceId.inventory,
    title: 'Inventory Workspace',
    shortTitle: 'Inventory',
    icon: Icons.inventory_2_outlined,
    homeRoute: RouteNames.inventoryDashboard,
    shell: UserRole.staff,
    modules: {AdminModule.inventory},
  ),
  WorkspaceId.transport: Workspace(
    id: WorkspaceId.transport,
    title: 'Transport Workspace',
    shortTitle: 'Transport',
    icon: Icons.directions_bus_outlined,
    homeRoute: RouteNames.transportDashboard,
    shell: UserRole.staff,
    modules: {AdminModule.transport},
  ),
  WorkspaceId.hostel: Workspace(
    id: WorkspaceId.hostel,
    title: 'Hostel Workspace',
    shortTitle: 'Hostel',
    icon: Icons.hotel_outlined,
    homeRoute: RouteNames.hostelDashboard,
    shell: UserRole.staff,
    modules: {AdminModule.hostel},
  ),
  WorkspaceId.library: Workspace(
    id: WorkspaceId.library,
    title: 'Library Workspace',
    shortTitle: 'Library',
    icon: Icons.menu_book_outlined,
    homeRoute: RouteNames.libraryDashboard,
    shell: UserRole.staff,
    modules: {AdminModule.library},
  ),
  WorkspaceId.parentSpace: Workspace(
    id: WorkspaceId.parentSpace,
    title: 'Parent',
    shortTitle: 'Parent',
    icon: Icons.family_restroom_outlined,
    homeRoute: RouteNames.parentDashboard,
    shell: UserRole.parent,
  ),
  WorkspaceId.studentSpace: Workspace(
    id: WorkspaceId.studentSpace,
    title: 'Student',
    shortTitle: 'Student',
    icon: Icons.backpack_outlined,
    homeRoute: RouteNames.studentDashboard,
    shell: UserRole.student,
  ),
};

/// Which workspace(s) each role grants. Many-to-many: a user's workspaces are
/// the union across all the roles they hold.
const Map<ErpRole, List<WorkspaceId>> kRoleWorkspaces = {
  ErpRole.superAdmin: [WorkspaceId.schoolAdministration],
  ErpRole.schoolAdmin: [WorkspaceId.schoolAdministration],
  ErpRole.principal: [WorkspaceId.schoolAdministration],
  ErpRole.vicePrincipal: [WorkspaceId.schoolAdministration],
  ErpRole.management: [WorkspaceId.schoolAdministration],
  ErpRole.financeAdmin: [WorkspaceId.finance],
  ErpRole.admissionsCounselor: [WorkspaceId.frontOffice],
  ErpRole.teacher: [WorkspaceId.teaching],
  ErpRole.parent: [WorkspaceId.parentSpace],
  ErpRole.student: [WorkspaceId.studentSpace],
  ErpRole.transportManager: [WorkspaceId.transport],
  ErpRole.hostelManager: [WorkspaceId.hostel],
  ErpRole.librarian: [WorkspaceId.library],
  ErpRole.inventoryManager: [WorkspaceId.inventory],
  ErpRole.storekeeper: [WorkspaceId.inventory],
};

/// Resolves the deduped, ordered list of workspaces a multi-role user holds.
/// Order follows the order of [roles] (primary role's workspaces first).
List<Workspace> workspacesForRoles(Iterable<ErpRole> roles) {
  final ids = <WorkspaceId>[];
  for (final role in roles) {
    for (final id in kRoleWorkspaces[role] ?? const <WorkspaceId>[]) {
      if (!ids.contains(id)) ids.add(id);
    }
  }
  return ids
      .map((id) => kWorkspaceCatalog[id])
      .whereType<Workspace>()
      .toList(growable: false);
}
