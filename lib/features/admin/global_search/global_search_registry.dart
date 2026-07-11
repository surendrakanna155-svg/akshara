import 'package:flutter/material.dart';

import '../../../core/school_config/school_capability_registry.dart';
import '../../../core/school_config/school_configuration_models.dart';
import '../../../core/security/permissions.dart';
import '../../../router/route_names.dart';
import '../models/admin_nav_models.dart';

/// Searchable ERP destination for global search overlay.
@immutable
class GlobalSearchEntry {
  const GlobalSearchEntry({
    required this.label,
    required this.route,
    required this.module,
    this.keywords = const [],
    this.requiredPermission,
    this.capabilityModule,
  });

  final String label;
  final String route;
  final String module;
  final List<String> keywords;

  /// View [Permission] required to see and navigate to this entry, matching the
  /// route's real guard (see [kErpRouteViewPermissions]). Null = generic
  /// destination (e.g. role dashboards) visible to all authenticated users.
  final Permission? requiredPermission;

  /// Owning [AdminModule] for dynamic-config capability gating. When the module
  /// is disabled for the school (`effectiveCapability = planAllows ∩
  /// schoolConfigEnabled` is off), the entry is hidden so it never becomes a
  /// dead link to [AccessDeniedScreen] — the SAME source the admin nav uses
  /// (see [SchoolCapabilityRegistry.isAdminModuleEnabled]). Null = core
  /// destination always available regardless of optional-module config.
  final AdminModule? capabilityModule;

  bool matches(String query) {
    if (query.isEmpty) return true;
    final q = query.toLowerCase();
    if (label.toLowerCase().contains(q)) return true;
    if (module.toLowerCase().contains(q)) return true;
    for (final keyword in keywords) {
      if (keyword.toLowerCase().contains(q)) return true;
    }
    return false;
  }

  /// Whether [hasPermission] grants visibility of this entry. Generic entries
  /// (no [requiredPermission]) are visible to everyone; otherwise the same
  /// view-permission that guards the route must be held.
  bool isVisibleTo(bool Function(Permission) hasPermission) {
    final permission = requiredPermission;
    return permission == null || hasPermission(permission);
  }

  /// Whether this entry's owning optional module is enabled for the school under
  /// the dynamic-config rule. Core entries ([capabilityModule] null) are always
  /// enabled. Uses the SAME [SchoolCapabilityRegistry] mapping as the admin nav.
  bool isCapabilityEnabled(SchoolCapabilities capabilities) {
    final module = capabilityModule;
    return module == null ||
        SchoolCapabilityRegistry.isAdminModuleEnabled(module, capabilities);
  }
}

/// Client-side route index for global search (no backend).
abstract final class GlobalSearchRegistry {
  static const entries = <GlobalSearchEntry>[
    GlobalSearchEntry(
      label: 'Management Dashboard',
      route: RouteNames.managementDashboard,
      module: 'Management',
      keywords: ['principal', 'overview', 'health'],
      requiredPermission: Permission.viewManagement,
    ),
    GlobalSearchEntry(
      label: 'Analytics Hub',
      route: RouteNames.managementIntelligence,
      module: 'Management',
      keywords: ['risk', 'trends', 'executive'],
      requiredPermission: Permission.viewAnalytics,
    ),
    GlobalSearchEntry(
      label: 'Finance Dashboard',
      route: RouteNames.financeDashboard,
      module: 'Finance',
      keywords: ['fees', 'collection', 'revenue'],
      requiredPermission: Permission.viewFinance,
    ),
    GlobalSearchEntry(
      label: 'Fee Defaulters',
      route: RouteNames.financeDefaulters,
      module: 'Finance',
      keywords: ['outstanding', 'dues'],
      requiredPermission: Permission.viewFinance,
    ),
    GlobalSearchEntry(
      label: 'Finance Executive Dashboard',
      route: RouteNames.financeExecutiveDashboard,
      module: 'Finance',
      keywords: ['executive', 'health score'],
      requiredPermission: Permission.viewFinanceExecutiveDashboard,
    ),
    GlobalSearchEntry(
      label: 'Finance Reports',
      route: RouteNames.financeReports,
      module: 'Finance',
      keywords: ['export', 'analytics'],
      requiredPermission: Permission.viewFinance,
    ),
    GlobalSearchEntry(
      label: 'Admissions Dashboard',
      route: RouteNames.admissionsDashboard,
      module: 'Admissions',
      keywords: ['leads', 'pipeline'],
      requiredPermission: Permission.viewAdmissions,
    ),
    GlobalSearchEntry(
      label: 'Student Enrollment',
      route: RouteNames.admissionsEnrollment,
      module: 'Admissions',
      keywords: ['register', 'admit', 'form'],
      requiredPermission: Permission.viewAdmissions,
    ),
    GlobalSearchEntry(
      label: 'Admissions Reports',
      route: RouteNames.admissionsReports,
      module: 'Admissions',
      keywords: ['funnel', 'conversion'],
      requiredPermission: Permission.viewAdmissions,
    ),
    GlobalSearchEntry(
      label: 'SIS Student Registry',
      route: RouteNames.sisStudents,
      module: 'SIS',
      keywords: ['students', 'registry', 'search'],
      requiredPermission: Permission.viewSis,
    ),
    GlobalSearchEntry(
      label: 'Academic Assignment',
      route: RouteNames.sisAcademicAssignment,
      module: 'SIS',
      keywords: ['class', 'section'],
      requiredPermission: Permission.viewSis,
    ),
    GlobalSearchEntry(
      label: 'Inventory Dashboard',
      route: RouteNames.inventoryDashboard,
      module: 'Inventory',
      keywords: ['stock', 'procurement'],
      requiredPermission: Permission.viewInventory,
      capabilityModule: AdminModule.inventory,
    ),
    GlobalSearchEntry(
      label: 'Inventory Reports',
      route: RouteNames.inventoryReports,
      module: 'Inventory',
      keywords: ['analytics', 'trends'],
      requiredPermission: Permission.viewInventory,
      capabilityModule: AdminModule.inventory,
    ),
    GlobalSearchEntry(
      label: 'Inventory Lifecycle',
      route: RouteNames.inventoryLifecycle,
      module: 'Inventory',
      keywords: ['lifecycle', 'intelligence'],
      requiredPermission: Permission.viewInventoryIntelligence,
      capabilityModule: AdminModule.inventory,
    ),
    GlobalSearchEntry(
      label: 'Communication Analytics',
      route: RouteNames.communicationAnalytics,
      module: 'Communication',
      keywords: ['messages', 'delivery'],
      requiredPermission: Permission.viewCommunicationAnalytics,
    ),
    GlobalSearchEntry(
      label: 'Exam Analytics',
      route: RouteNames.examIntelligence,
      module: 'Intelligence',
      keywords: ['exams', 'results'],
      requiredPermission: Permission.viewExamIntelligence,
    ),
    GlobalSearchEntry(
      label: 'Student Success Analytics',
      route: RouteNames.studentSuccessIntelligence,
      module: 'Intelligence',
      keywords: ['at-risk', 'success'],
      requiredPermission: Permission.viewStudentSuccessIntelligence,
    ),
    GlobalSearchEntry(
      label: 'Parent Dashboard',
      route: RouteNames.parentDashboard,
      module: 'Parent',
      keywords: ['home', 'child'],
    ),
    GlobalSearchEntry(
      label: 'Teacher Dashboard',
      route: RouteNames.teacherDashboard,
      module: 'Teacher',
      keywords: ['classes', 'attendance'],
    ),
    GlobalSearchEntry(
      label: 'Student Dashboard',
      route: RouteNames.studentDashboard,
      module: 'Student',
      keywords: ['homework', 'exams'],
    ),
  ];

  /// Entries matching [query]. When [hasPermission] is provided, entries the
  /// user lacks the view-permission for are excluded so they neither appear nor
  /// are navigable (MJ-L8 / ADMIN-6 RBAC fix). When [capabilities] is provided,
  /// entries whose optional module is disabled for the school are excluded too,
  /// so a turned-off module (transport/hostel/library/inventory/alumni/hr) never
  /// becomes a dead link to [AccessDeniedScreen] (gap G6) — using the same
  /// capability source as the admin nav.
  static List<GlobalSearchEntry> search(
    String query, {
    bool Function(Permission)? hasPermission,
    SchoolCapabilities? capabilities,
  }) {
    return entries
        .where((entry) => entry.matches(query))
        .where(
          (entry) => hasPermission == null || entry.isVisibleTo(hasPermission),
        )
        .where(
          (entry) =>
              capabilities == null || entry.isCapabilityEnabled(capabilities),
        )
        .toList();
  }
}
