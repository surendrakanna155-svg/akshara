import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/security/permissions.dart';
import '../../core/security/rbac_service.dart';
import 'models/admin_nav_models.dart';
import '../../router/route_names.dart';

/// All ERP module destinations before permission filtering.
const List<AdminNavDestination> kAllAdminNavDestinations = [
  AdminNavDestination(
    module: AdminModule.admin,
    route: RouteNames.admin,
    label: 'Admin Hub',
    icon: Icons.dashboard_outlined,
    selectedIcon: Icons.dashboard,
    requiredPermission: Permission.viewAdminHub,
  ),
  AdminNavDestination(
    module: AdminModule.admissions,
    route: RouteNames.admissionsDashboard,
    label: 'Admissions',
    icon: Icons.school_outlined,
    selectedIcon: Icons.school,
    requiredPermission: Permission.viewAdmissions,
  ),
  AdminNavDestination(
    module: AdminModule.finance,
    route: RouteNames.financeDashboard,
    label: 'Finance',
    icon: Icons.account_balance_wallet_outlined,
    selectedIcon: Icons.account_balance_wallet,
    requiredPermission: Permission.viewFinance,
  ),
  AdminNavDestination(
    module: AdminModule.sis,
    route: RouteNames.sisDashboard,
    label: 'Student SIS',
    icon: Icons.badge_outlined,
    selectedIcon: Icons.badge,
    requiredPermission: Permission.viewSis,
  ),
  AdminNavDestination(
    module: AdminModule.hr,
    route: RouteNames.hrDashboard,
    label: 'HR',
    icon: Icons.groups_outlined,
    selectedIcon: Icons.groups,
    requiredPermission: Permission.viewHr,
  ),
  AdminNavDestination(
    module: AdminModule.management,
    route: RouteNames.managementDashboard,
    label: 'Management',
    icon: Icons.business_center_outlined,
    selectedIcon: Icons.business_center,
    requiredPermission: Permission.viewManagement,
  ),
  AdminNavDestination(
    module: AdminModule.transport,
    route: RouteNames.transportDashboard,
    label: 'Transport',
    icon: Icons.directions_bus_outlined,
    selectedIcon: Icons.directions_bus,
    requiredPermission: Permission.viewTransport,
  ),
  AdminNavDestination(
    module: AdminModule.hostel,
    route: RouteNames.hostelDashboard,
    label: 'Hostel',
    icon: Icons.hotel_outlined,
    selectedIcon: Icons.hotel,
    requiredPermission: Permission.viewHostel,
  ),
  AdminNavDestination(
    module: AdminModule.library,
    route: RouteNames.libraryDashboard,
    label: 'Library',
    icon: Icons.menu_book_outlined,
    selectedIcon: Icons.menu_book,
    requiredPermission: Permission.viewLibrary,
  ),
  AdminNavDestination(
    module: AdminModule.inventory,
    route: RouteNames.inventoryDashboard,
    label: 'Inventory',
    icon: Icons.inventory_2_outlined,
    selectedIcon: Icons.inventory_2,
    requiredPermission: Permission.viewInventory,
  ),
  AdminNavDestination(
    module: AdminModule.alumni,
    route: RouteNames.alumniDashboard,
    label: 'Alumni',
    icon: Icons.school_outlined,
    selectedIcon: Icons.school,
    requiredPermission: Permission.viewAlumni,
  ),
  AdminNavDestination(
    module: AdminModule.controlCenter,
    route: RouteNames.controlCenterDashboard,
    label: 'Control Center',
    icon: Icons.hub_outlined,
    selectedIcon: Icons.hub,
    requiredPermission: Permission.viewControlCenter,
  ),
  AdminNavDestination(
    module: AdminModule.director,
    route: RouteNames.directorDashboard,
    label: 'Director',
    icon: Icons.insights_outlined,
    selectedIcon: Icons.insights,
    requiredPermission: Permission.viewDirectorPortal,
  ),
  AdminNavDestination(
    module: AdminModule.organizationBuilder,
    route: RouteNames.organizationBuilder,
    label: 'Org Builder',
    icon: Icons.domain_add_outlined,
    selectedIcon: Icons.domain_add,
    requiredPermission: Permission.viewOrganizationBuilder,
  ),
  AdminNavDestination(
    module: AdminModule.dynamicWidgets,
    route: RouteNames.dynamicWidgets,
    label: 'Widgets',
    icon: Icons.widgets_outlined,
    selectedIcon: Icons.widgets,
    requiredPermission: Permission.viewDynamicWidgets,
  ),
];

/// Permission-filtered navigation destinations for the current session.
final adminNavDestinationsProvider = Provider<List<AdminNavDestination>>((ref) {
  final rbac = ref.watch(rbacServiceProvider);
  return kAllAdminNavDestinations
      .where(
        (destination) => rbac.hasPermission(destination.requiredPermission),
      )
      .toList(growable: false);
});

const Map<AdminModule, AdminModuleInfo> kAdminModuleInfo = {
  AdminModule.admin: AdminModuleInfo(
    module: AdminModule.admin,
    title: 'Admin Hub',
    description:
        'Web ERP foundation is ready. Module screens will be added in upcoming releases.',
    route: RouteNames.admin,
  ),
  AdminModule.admissions: AdminModuleInfo(
    module: AdminModule.admissions,
    title: 'Admissions',
    description:
        'Admissions CRM (AD-01 → AD-10) will be built on this shell. Not started yet.',
    route: RouteNames.admissionsDashboard,
  ),
  AdminModule.finance: AdminModuleInfo(
    module: AdminModule.finance,
    title: 'Finance',
    description:
        'Finance operations (FN-01 → FN-05) — fee structures, accounts, collections.',
    route: RouteNames.financeDashboard,
  ),
  AdminModule.sis: AdminModuleInfo(
    module: AdminModule.sis,
    title: 'Student SIS',
    description:
        'Student Information System (SIS-01 → SIS-05) — registry, profiles, conversion.',
    route: RouteNames.sisDashboard,
  ),
  AdminModule.hr: AdminModuleInfo(
    module: AdminModule.hr,
    title: 'HR',
    description:
        'Employee registry, attendance, leave, payroll, recruitment, and performance (HR-01 → HR-09).',
    route: RouteNames.hrDashboard,
  ),
  AdminModule.management: AdminModuleInfo(
    module: AdminModule.management,
    title: 'Management',
    description:
        'Executive dashboards, analytics, approvals, and school performance (MG-01 → MG-08).',
    route: RouteNames.managementDashboard,
  ),
  AdminModule.transport: AdminModuleInfo(
    module: AdminModule.transport,
    title: 'Transport',
    description:
        'Fleet operations, routes, allocation, attendance, and GPS tracking (TR-01 → TR-09).',
    route: RouteNames.transportDashboard,
  ),
  AdminModule.hostel: AdminModuleInfo(
    module: AdminModule.hostel,
    title: 'Hostel',
    description:
        'Residential operations — rooms, students, attendance, leave, mess, and visitors (HO-01 → HO-08).',
    route: RouteNames.hostelDashboard,
  ),
  AdminModule.library: AdminModuleInfo(
    module: AdminModule.library,
    title: 'Library',
    description:
        'Book catalog, issue/return, members, fines, digital resources, and reports (LB-01 → LB-08).',
    route: RouteNames.libraryDashboard,
  ),
  AdminModule.inventory: AdminModuleInfo(
    module: AdminModule.inventory,
    title: 'Inventory',
    description:
        'Asset registry, categories, allocation, maintenance, procurement, vendors, and reports (INV-01 → INV-08).',
    route: RouteNames.inventoryDashboard,
  ),
  AdminModule.alumni: AdminModuleInfo(
    module: AdminModule.alumni,
    title: 'Alumni',
    description:
        'Alumni registry, events, donations, campaigns, mentorship, and mobile companion (AL-01 → AL-10).',
    route: RouteNames.alumniDashboard,
  ),
  AdminModule.controlCenter: AdminModuleInfo(
    module: AdminModule.controlCenter,
    title: 'Control Center',
    description:
        'Platform operations — schools, subscriptions, billing, CRM, support, analytics, and white label (ACC-01 → ACC-12). Super Admin only.',
    route: RouteNames.controlCenterDashboard,
  ),
  AdminModule.director: AdminModuleInfo(
    module: AdminModule.director,
    title: 'Director Portal',
    description:
        'Multi-school executive oversight for revenue, growth, admissions, compliance, and strategic reporting (DR-01 → DR-09).',
    route: RouteNames.directorDashboard,
  ),
  AdminModule.organizationBuilder: AdminModuleInfo(
    module: AdminModule.organizationBuilder,
    title: 'Organization Builder',
    description:
        'AI-guided vertical pack interview to provision schools, salons, hospitals, and restaurants (FV-30).',
    route: RouteNames.organizationBuilder,
  ),
  AdminModule.dynamicWidgets: AdminModuleInfo(
    module: AdminModule.dynamicWidgets,
    title: 'Dynamic Widgets',
    description:
        'Versioned widget layouts, data source registry, and role-bound dashboards (FV-31).',
    route: RouteNames.dynamicWidgets,
  ),
};

/// Resolves breadcrumbs for a module placeholder route.
List<AdminBreadcrumb> adminBreadcrumbsForModule(AdminModule module) {
  final info = kAdminModuleInfo[module]!;
  if (module == AdminModule.admin) {
    return [AdminBreadcrumb(label: info.title)];
  }
  return [
    const AdminBreadcrumb(
      label: 'Admin Hub',
      route: RouteNames.admin,
    ),
    AdminBreadcrumb(label: info.title),
  ];
}

/// Maps a location path to the active [AdminModule].
AdminModule? adminModuleForLocation(String location) {
  for (final entry in kAdminModuleInfo.entries) {
    if (location == entry.value.route ||
        location.startsWith('${entry.value.route}/')) {
      return entry.key;
    }
  }
  return null;
}
