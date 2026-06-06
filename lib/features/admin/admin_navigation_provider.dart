import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/auth_models.dart';
import '../auth/auth_provider.dart';
import 'models/admin_nav_models.dart';
import '../../router/route_names.dart';

/// Demo persona for staff users until dedicated admin auth lands.
final adminPersonaProvider = Provider<AdminPersona>((ref) {
  final role = ref.watch(authProvider).role;
  return switch (role) {
    UserRole.staff => AdminPersona.superAdmin,
    _ => AdminPersona.superAdmin,
  };
});

/// All ERP module destinations before persona filtering.
const List<AdminNavDestination> kAllAdminNavDestinations = [
  AdminNavDestination(
    module: AdminModule.admin,
    route: RouteNames.admin,
    label: 'Admin Hub',
    icon: Icons.dashboard_outlined,
    selectedIcon: Icons.dashboard,
    allowedPersonas: {
      AdminPersona.superAdmin,
      AdminPersona.counselor,
      AdminPersona.marketingExecutive,
      AdminPersona.principal,
      AdminPersona.management,
      AdminPersona.financeAdmin,
      AdminPersona.hrAdmin,
      AdminPersona.transportAdmin,
      AdminPersona.hostelAdmin,
    },
  ),
  AdminNavDestination(
    module: AdminModule.admissions,
    route: RouteNames.admissionsDashboard,
    label: 'Admissions',
    icon: Icons.school_outlined,
    selectedIcon: Icons.school,
    allowedPersonas: {
      AdminPersona.superAdmin,
      AdminPersona.counselor,
      AdminPersona.marketingExecutive,
      AdminPersona.principal,
      AdminPersona.management,
    },
  ),
  AdminNavDestination(
    module: AdminModule.finance,
    route: RouteNames.financeDashboard,
    label: 'Finance',
    icon: Icons.account_balance_wallet_outlined,
    selectedIcon: Icons.account_balance_wallet,
    allowedPersonas: {
      AdminPersona.superAdmin,
      AdminPersona.financeAdmin,
      AdminPersona.management,
    },
  ),
  AdminNavDestination(
    module: AdminModule.sis,
    route: RouteNames.sisDashboard,
    label: 'Student SIS',
    icon: Icons.badge_outlined,
    selectedIcon: Icons.badge,
    allowedPersonas: {
      AdminPersona.superAdmin,
      AdminPersona.counselor,
      AdminPersona.principal,
      AdminPersona.management,
    },
  ),
  AdminNavDestination(
    module: AdminModule.hr,
    route: RouteNames.hr,
    label: 'HR',
    icon: Icons.groups_outlined,
    selectedIcon: Icons.groups,
    allowedPersonas: {
      AdminPersona.superAdmin,
      AdminPersona.hrAdmin,
      AdminPersona.management,
    },
  ),
  AdminNavDestination(
    module: AdminModule.management,
    route: RouteNames.management,
    label: 'Management',
    icon: Icons.business_center_outlined,
    selectedIcon: Icons.business_center,
    allowedPersonas: {
      AdminPersona.superAdmin,
      AdminPersona.management,
      AdminPersona.principal,
    },
  ),
  AdminNavDestination(
    module: AdminModule.transport,
    route: RouteNames.transport,
    label: 'Transport',
    icon: Icons.directions_bus_outlined,
    selectedIcon: Icons.directions_bus,
    allowedPersonas: {
      AdminPersona.superAdmin,
      AdminPersona.transportAdmin,
      AdminPersona.management,
    },
  ),
  AdminNavDestination(
    module: AdminModule.hostel,
    route: RouteNames.hostel,
    label: 'Hostel',
    icon: Icons.hotel_outlined,
    selectedIcon: Icons.hotel,
    allowedPersonas: {
      AdminPersona.superAdmin,
      AdminPersona.hostelAdmin,
      AdminPersona.management,
    },
  ),
];

/// Role-filtered navigation destinations for the current session.
final adminNavDestinationsProvider = Provider<List<AdminNavDestination>>((ref) {
  final persona = ref.watch(adminPersonaProvider);
  return kAllAdminNavDestinations
      .where((destination) => destination.isVisibleFor(persona))
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
    description: 'Human resources module screens will appear here in a future release.',
    route: RouteNames.hr,
  ),
  AdminModule.management: AdminModuleInfo(
    module: AdminModule.management,
    title: 'Management',
    description: 'Management dashboards will appear here in a future release.',
    route: RouteNames.management,
  ),
  AdminModule.transport: AdminModuleInfo(
    module: AdminModule.transport,
    title: 'Transport',
    description: 'Transport operations will appear here in a future release.',
    route: RouteNames.transport,
  ),
  AdminModule.hostel: AdminModuleInfo(
    module: AdminModule.hostel,
    title: 'Hostel',
    description: 'Hostel management will appear here in a future release.',
    route: RouteNames.hostel,
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
