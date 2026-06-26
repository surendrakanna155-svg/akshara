import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config/chain_scope.dart';
import '../../core/config/school_build_scope.dart';
import '../../core/security/permissions.dart';
import '../../core/entitlements/entitlement_provider.dart';
import '../../core/school_config/school_capability_registry.dart';
import '../../core/school_config/school_configuration_provider.dart';
import '../../core/security/rbac_service.dart';
import '../../core/workspace/workspace_providers.dart';
import 'models/admin_nav_models.dart';
import '../entitlements/entitlement_module_gate.dart';
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
    module: AdminModule.marketing,
    route: RouteNames.growthPlatform,
    label: 'Marketing',
    icon: Icons.campaign_outlined,
    selectedIcon: Icons.campaign,
    requiredPermission: Permission.viewGrowthPlatform,
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
    module: AdminModule.employee,
    route: RouteNames.employees,
    label: 'Employee Platform',
    icon: Icons.work_outline,
    selectedIcon: Icons.work,
    requiredPermission: Permission.viewEmployees,
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
    module: AdminModule.platformOperations,
    route: RouteNames.platformOperations,
    label: 'Platform Ops',
    icon: Icons.monitor_heart_outlined,
    selectedIcon: Icons.monitor_heart,
    requiredPermission: Permission.viewPlatformOperations,
  ),
  AdminNavDestination(
    module: AdminModule.industry,
    route: RouteNames.industry,
    label: 'Industry',
    icon: Icons.category_outlined,
    selectedIcon: Icons.category,
    requiredPermission: Permission.viewIndustryFramework,
  ),
  AdminNavDestination(
    module: AdminModule.healthcare,
    route: RouteNames.healthcare,
    label: 'Healthcare',
    icon: Icons.local_hospital_outlined,
    selectedIcon: Icons.local_hospital,
    requiredPermission: Permission.viewHealthcare,
  ),
  AdminNavDestination(
    module: AdminModule.salon,
    route: RouteNames.salon,
    label: 'Salon',
    icon: Icons.content_cut_outlined,
    selectedIcon: Icons.content_cut,
    requiredPermission: Permission.viewSalonBusiness,
  ),
  AdminNavDestination(
    module: AdminModule.restaurant,
    route: RouteNames.restaurant,
    label: 'Restaurant',
    icon: Icons.restaurant_outlined,
    selectedIcon: Icons.restaurant,
    requiredPermission: Permission.viewRestaurantHospitality,
  ),
  AdminNavDestination(
    module: AdminModule.accommodation,
    route: RouteNames.accommodation,
    label: 'Accommodation',
    icon: Icons.night_shelter_outlined,
    selectedIcon: Icons.night_shelter,
    requiredPermission: Permission.viewAccommodation,
  ),
  AdminNavDestination(
    module: AdminModule.whiteLabel,
    route: RouteNames.whiteLabel,
    label: 'White Label',
    icon: Icons.palette_outlined,
    selectedIcon: Icons.palette,
    requiredPermission: Permission.viewWhiteLabelPlatform,
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
  final capabilities = ref.watch(schoolCapabilitiesProvider);
  final planCeiling = ref.watch(planCapabilityCeilingProvider);
  final isChainOrg = ref.watch(isChainOrgProvider);
  return kAllAdminNavDestinations
      .where(
        (destination) => !SchoolBuildScope.isModuleHidden(destination.module),
      )
      .where(
        // Chain-only modules (M3) appear only for chain orgs.
        (destination) =>
            isChainOrg || !ChainScope.isChainOnlyModule(destination.module),
      )
      .where(
        (destination) => rbac.hasPermission(destination.requiredPermission),
      )
      .map((destination) {
        // Marketing is entitlement-gated outside the 8-flag SchoolCapabilities
        // model; lock it from the resolved plan directly (never hide — B2 UX).
        if (destination.module == AdminModule.marketing) {
          return ref.watch(modulePlanLockedProvider(destination.module))
              ? destination.copyWith(isLocked: true)
              : destination;
        }
        // Effective = school config ∩ plan ceiling. If enabled, show normally.
        if (SchoolCapabilityRegistry.isAdminModuleEnabled(
          destination.module,
          capabilities,
        )) {
          return destination;
        }
        // Disabled: locked by the PLAN (show locked + upgrade, never hide) vs
        // turned off by the SCHOOL within its plan (hide — existing behaviour).
        final planAllows = SchoolCapabilityRegistry.isAdminModuleEnabled(
          destination.module,
          planCeiling,
        );
        return planAllows ? null : destination.copyWith(isLocked: true);
      })
      .whereType<AdminNavDestination>()
      .toList(growable: false);
});

/// Navigation destinations scoped to the user's **active workspace** — the
/// USER → ROLE → WORKSPACE → TASK model. A finance admin sees only the Finance
/// workspace's modules; a multi-hat user sees only the active hat's modules.
/// The Admin-Hub root card is always available as the workspace landing.
final workspaceScopedNavDestinationsProvider =
    Provider<List<AdminNavDestination>>((ref) {
  final all = ref.watch(adminNavDestinationsProvider);
  final workspace = ref.watch(activeWorkspaceProvider);
  if (workspace == null) return all;
  return all
      .where(
        (destination) =>
            destination.module == AdminModule.admin ||
            workspace.containsModule(destination.module),
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
  AdminModule.marketing: AdminModuleInfo(
    module: AdminModule.marketing,
    title: 'Marketing',
    description:
        'Marketing engine — lead capture, campaigns, and source attribution feeding '
        'the Admissions CRM.',
    route: RouteNames.growthPlatform,
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
  AdminModule.employee: AdminModuleInfo(
    module: AdminModule.employee,
    title: 'Employee Platform',
    description:
        'Unified staff platform — Employee 360 profiles, role assignment, and '
        'workforce operations across departments.',
    route: RouteNames.employees,
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
  AdminModule.platformOperations: AdminModuleInfo(
    module: AdminModule.platformOperations,
    title: 'Platform Operations',
    description:
        'Observability, security hardening, tenant isolation, alerting, and production readiness (FV-PLAT-06/08/09/12).',
    route: RouteNames.platformOperations,
  ),
  AdminModule.industry: AdminModuleInfo(
    module: AdminModule.industry,
    title: 'Industry Framework',
    description:
        'Multi-industry capability registry, module activation, and vertical pack routing (FV-32).',
    route: RouteNames.industry,
  ),
  AdminModule.healthcare: AdminModuleInfo(
    module: AdminModule.healthcare,
    title: 'Healthcare',
    description:
        'Patient registry, appointments, practitioners, and clinical intelligence (FV-33).',
    route: RouteNames.healthcare,
  ),
  AdminModule.salon: AdminModuleInfo(
    module: AdminModule.salon,
    title: 'Salon Business',
    description:
        'Customer registry, appointment scheduling, services, and salon intelligence (FV-34).',
    route: RouteNames.salon,
  ),
  AdminModule.restaurant: AdminModuleInfo(
    module: AdminModule.restaurant,
    title: 'Restaurant Hospitality',
    description:
        'Table management, orders, kitchen workflow, and hospitality intelligence (FV-35).',
    route: RouteNames.restaurant,
  ),
  AdminModule.accommodation: AdminModuleInfo(
    module: AdminModule.accommodation,
    title: 'Accommodation',
    description:
        'Resident lifecycle, occupancy, room allocation, and accommodation intelligence (FV-36).',
    route: RouteNames.accommodation,
  ),
  AdminModule.whiteLabel: AdminModuleInfo(
    module: AdminModule.whiteLabel,
    title: 'White Label Platform',
    description:
        'Branding profiles, themes, logos, and deployment profiles (FV-PLAT-11).',
    route: RouteNames.whiteLabel,
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
