import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/config/chain_scope.dart';
import '../core/config/school_build_scope.dart';
import '../core/school_config/school_capability_registry.dart';
import '../core/school_config/school_configuration_models.dart';
import '../core/school_config/school_configuration_provider.dart';
import '../core/security/denied_access_audit.dart';
import '../core/security/erp_role.dart';
import '../core/testing/qa_test_keys.dart';
import '../core/security/permissions.dart';
import '../core/security/rbac_service.dart';
import '../features/admin/models/admin_nav_models.dart';
import '../features/auth/auth_models.dart';
import '../features/auth/auth_provider.dart';
import '../shared/widgets/akshara_error_state.dart';
import 'admin_navigation.dart';
import 'route_names.dart';

/// Required [Permission] for each admin ERP route prefix.
const Map<String, Permission> kErpRouteViewPermissions = {
  RouteNames.admin: Permission.viewAdminHub,
  RouteNames.admissions: Permission.viewAdmissions,
  RouteNames.finance: Permission.viewFinance,
  RouteNames.financeQrPayment: Permission.viewFinance,
  RouteNames.sis: Permission.viewSis,
  RouteNames.management: Permission.viewManagement,
  RouteNames.managementWorkflowAutomation: Permission.viewManagement,
  RouteNames.transport: Permission.viewTransport,
  RouteNames.hr: Permission.viewHr,
  RouteNames.hostel: Permission.viewHostel,
  RouteNames.library: Permission.viewLibrary,
  RouteNames.inventory: Permission.viewInventory,
  RouteNames.alumni: Permission.viewAlumni,
  RouteNames.controlCenter: Permission.viewControlCenter,
  RouteNames.director: Permission.viewDirectorPortal,
  RouteNames.copilot: Permission.viewAiCopilot,
  RouteNames.education: Permission.viewEducation,
  RouteNames.intelligence: Permission.viewStudentRisk,
  RouteNames.studentSuccessIntelligence:
      Permission.viewStudentSuccessIntelligence,
  RouteNames.examIntelligence: Permission.viewExamIntelligence,
  RouteNames.homeworkIntelligence: Permission.viewHomeworkIntelligence,
  RouteNames.student360: Permission.viewStudent360,
  RouteNames.employees: Permission.viewEmployees,
  RouteNames.inventoryDistribution: Permission.viewInventoryDistribution,
  RouteNames.inventoryReplacements: Permission.viewInventoryDistribution,
  RouteNames.operationsHub: Permission.viewOperationsHub,
  RouteNames.resourceOptimization: Permission.viewOperationsHub,
  RouteNames.aiContent: Permission.runAiCopilot,
  RouteNames.organizationIntelligence: Permission.viewOrganizationIntelligence,
  RouteNames.branches: Permission.viewBranchOperations,
  RouteNames.franchise: Permission.viewFranchiseOperations,
  RouteNames.schoolMemories: Permission.viewSchoolMemories,
  RouteNames.achievementPromotion: Permission.viewAchievementPromotion,
  RouteNames.setupWizard: Permission.viewSchoolSetup,
  RouteNames.dynamicDashboard: Permission.viewDynamicWidgets,
  RouteNames.dynamicWidgets: Permission.viewDynamicWidgets,
  RouteNames.dynamicWidgetLayout: Permission.viewDynamicWidgets,
  RouteNames.dynamicWidgetRuntime: Permission.viewDynamicWidgets,
  RouteNames.teacherAssistant: Permission.viewTeacherAssistant,
  RouteNames.parentInsights: Permission.viewParentInsights,
  RouteNames.principalCommand: Permission.viewPrincipalCommand,
  RouteNames.growthPlatform: Permission.viewGrowthPlatform,
  RouteNames.schoolCompletionHub: Permission.viewSubjects,
  RouteNames.subjectsManagement: Permission.viewSubjects,
  RouteNames.examAdministration: Permission.viewExams,
  RouteNames.lessonLogs: Permission.viewLessonLogs,
  RouteNames.timetableAutomation: Permission.manageTimetableAutomation,
  RouteNames.schoolBranding: Permission.viewSchoolBranding,
  RouteNames.whatsAppProvider: Permission.viewWhatsAppProvider,
  RouteNames.subjectAssignments: Permission.viewSubjectAssignments,
  RouteNames.lessonAnalytics: Permission.viewLessonAnalytics,
  RouteNames.timetableOptimization: Permission.viewTimetableOptimization,
  RouteNames.substituteManager: Permission.manageAcademicTimetable,
  RouteNames.teacherReassignment: Permission.manageAcademicTimetable,
  RouteNames.classTeacherAssignments: Permission.manageAcademicTimetable,
  RouteNames.communicationDelivery: Permission.viewCommunicationDelivery,
  RouteNames.communicationBroadcastAdmin: Permission.manageCommunication,
  RouteNames.communicationAnalytics: Permission.viewCommunicationAnalytics,
  RouteNames.pilotDashboard: Permission.viewPilotDashboard,
  RouteNames.parentActivationDashboard: Permission.viewPilotDashboard,
  RouteNames.roomAllocation: Permission.manageAcademicRooms,
  RouteNames.teacherEffectiveness: Permission.viewTeacherEffectiveness,
  RouteNames.syllabusAutomation: Permission.manageSyllabus,
  RouteNames.academicProgress: Permission.viewAcademicProgress,
  RouteNames.timetableIntelligence: Permission.manageAcademicRooms,
  RouteNames.parentMeetings: Permission.viewAcademicProgress,
  RouteNames.financeIntelligence: Permission.viewFinanceIntelligence,
  RouteNames.financeExecutiveDashboard:
      Permission.viewFinanceExecutiveDashboard,
  RouteNames.inventoryCopilot: Permission.viewInventoryIntelligence,
  RouteNames.inventoryLifecycle: Permission.viewInventoryIntelligence,
  RouteNames.multiSchoolPortfolio: Permission.viewMultiSchoolOperations,
  RouteNames.multiSchoolOnboarding: Permission.viewMultiSchoolOperations,
  RouteNames.organizationBuilder: Permission.viewOrganizationBuilder,
  RouteNames.organizationBuilderInterview: Permission.viewOrganizationBuilder,
  RouteNames.organizationBuilderPreview: Permission.viewOrganizationBuilder,
  RouteNames.organizationBuilderProvisioning:
      Permission.viewOrganizationBuilder,
  RouteNames.schoolDiscovery: Permission.viewSchoolSetup,
  RouteNames.platformOperations: Permission.viewPlatformOperations,
  RouteNames.platformOperationsAlerts: Permission.viewPlatformOperations,
  RouteNames.platformOperationsSecurity: Permission.viewPlatformOperations,
  RouteNames.platformOperationsTenantIsolation:
      Permission.viewPlatformOperations,
  RouteNames.platformOperationsReadiness: Permission.viewPlatformOperations,
  RouteNames.industry: Permission.viewIndustryFramework,
  RouteNames.industryFramework: Permission.viewIndustryFramework,
  RouteNames.healthcare: Permission.viewHealthcare,
  RouteNames.healthcarePatients: Permission.viewHealthcare,
  RouteNames.healthcareAppointments: Permission.viewHealthcare,
  RouteNames.healthcarePractitioners: Permission.viewHealthcare,
  RouteNames.healthcareIntelligence: Permission.viewHealthcare,
  RouteNames.salon: Permission.viewSalonBusiness,
  RouteNames.salonCustomers: Permission.viewSalonBusiness,
  RouteNames.salonAppointments: Permission.viewSalonBusiness,
  RouteNames.salonServices: Permission.viewSalonBusiness,
  RouteNames.salonIntelligence: Permission.viewSalonBusiness,
  RouteNames.restaurant: Permission.viewRestaurantHospitality,
  RouteNames.restaurantTables: Permission.viewRestaurantHospitality,
  RouteNames.restaurantOrders: Permission.viewRestaurantHospitality,
  RouteNames.restaurantKitchen: Permission.viewRestaurantHospitality,
  RouteNames.restaurantIntelligence: Permission.viewRestaurantHospitality,
  RouteNames.accommodation: Permission.viewAccommodation,
  RouteNames.accommodationResidents: Permission.viewAccommodation,
  RouteNames.accommodationOccupancy: Permission.viewAccommodation,
  RouteNames.accommodationAllocations: Permission.viewAccommodation,
  RouteNames.accommodationIntelligence: Permission.viewAccommodation,
  RouteNames.whiteLabel: Permission.viewWhiteLabelPlatform,
  RouteNames.whiteLabelBranding: Permission.viewWhiteLabelPlatform,
  RouteNames.whiteLabelTheme: Permission.viewWhiteLabelPlatform,
  RouteNames.whiteLabelLogo: Permission.viewWhiteLabelPlatform,
  RouteNames.whiteLabelDeployment: Permission.viewWhiteLabelPlatform,
};

/// Resolves the view permission required for [location].
Permission? erpRoutePermissionFor(String location) {
  if (location == RouteNames.managementTimetable ||
      location.startsWith('${RouteNames.managementTimetable}/')) {
    return Permission.viewAcademicTimetable;
  }
  if (location == RouteNames.managementIntelligence ||
      location.startsWith('${RouteNames.managementIntelligence}/')) {
    return Permission.viewAnalytics;
  }
  if (location.startsWith('${RouteNames.employee360}/')) {
    return Permission.viewEmployeeIntelligence;
  }
  // Longest-prefix match: a specific child route (e.g. /finance/intelligence)
  // must resolve to its own permission, not the broader parent (/finance).
  // Insertion-order first-match would return the weaker parent permission and
  // let a role that only holds the parent perm reach the child — a privilege
  // escalation. Pick the most specific (longest) matching key instead.
  Permission? best;
  int bestLength = -1;
  for (final entry in kErpRouteViewPermissions.entries) {
    if (location == entry.key || location.startsWith('${entry.key}/')) {
      if (entry.key.length > bestLength) {
        bestLength = entry.key.length;
        best = entry.value;
      }
    }
  }
  return best;
}

/// Maps a gated ERP route prefix to the [AdminModule] whose [SchoolCapabilities]
/// flag governs it. A school that turned a module off in the Smart School
/// Discovery wizard must not be able to deep-link past the hidden nav entry —
/// [ErpRouteGuard] resolves this to a capability check (B1). Only the
/// capability-bearing modules appear here; everything else is always allowed.
const Map<String, AdminModule> kErpRouteCapabilityModules = {
  RouteNames.transport: AdminModule.transport,
  RouteNames.hostel: AdminModule.hostel,
  RouteNames.library: AdminModule.library,
  RouteNames.inventory: AdminModule.inventory,
  RouteNames.inventoryDistribution: AdminModule.inventory,
  RouteNames.inventoryReplacements: AdminModule.inventory,
  RouteNames.alumni: AdminModule.alumni,
  RouteNames.hr: AdminModule.hr,
  RouteNames.director: AdminModule.director,
  RouteNames.controlCenter: AdminModule.controlCenter,
};

/// Resolves the capability-gating [AdminModule] for [location] (longest match).
AdminModule? erpRouteCapabilityModuleFor(String location) {
  AdminModule? best;
  int bestLength = -1;
  for (final entry in kErpRouteCapabilityModules.entries) {
    if (location == entry.key || location.startsWith('${entry.key}/')) {
      if (entry.key.length > bestLength) {
        bestLength = entry.key.length;
        best = entry.value;
      }
    }
  }
  return best;
}

/// Whether [location] is permitted under the school's enabled [capabilities].
/// Routes for modules the school disabled are blocked regardless of permission.
bool isRouteEnabledForCapabilities(
  String location,
  SchoolCapabilities capabilities,
) {
  final module = erpRouteCapabilityModuleFor(location);
  if (module == null) return true;
  return SchoolCapabilityRegistry.isAdminModuleEnabled(module, capabilities);
}

/// Whether [location] is allowed for the given [RbacService].
///
/// This is pure RBAC (permission-based). The school-build module hide is
/// enforced separately in [ErpRouteGuard] so permission wiring stays testable.
bool canAccessErpRoute(RbacService rbac, String location) {
  if (!isAdminErpRoute(location)) return true;

  if (location == RouteNames.resourceOptimization ||
      location.startsWith('${RouteNames.resourceOptimization}/')) {
    return rbac.hasPermission(Permission.viewOperationsHub) ||
        rbac.hasPermission(Permission.manageManagement);
  }

  final permission = erpRoutePermissionFor(location);
  if (permission == null) return true;

  return rbac.hasPermission(permission);
}

/// Whether [auth] may enter the admin ERP shell at all.
bool canAccessAdminErpShell(AuthState auth) {
  return auth.isAuthenticated && auth.role == UserRole.staff;
}

/// Access denied placeholder for unauthorized ERP routes.
class AccessDeniedScreen extends StatelessWidget {
  const AccessDeniedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: QaTestKeys.accessDeniedScreen,
      body: AksharaErrorState(
        message: 'Access Denied',
        icon: Icons.lock_outline,
      ),
    );
  }
}

/// Requires an authenticated session.
class AuthenticatedGuard extends ConsumerWidget {
  const AuthenticatedGuard({
    super.key,
    required this.child,
    this.fallback = const AccessDeniedScreen(),
  });

  final Widget child;
  final Widget fallback;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authProvider);
    if (!auth.isAuthenticated) {
      return fallback;
    }
    return child;
  }
}

/// Requires a specific [ErpRole].
class RoleGuard extends ConsumerWidget {
  const RoleGuard({
    super.key,
    required this.allowedRoles,
    required this.child,
    this.fallback = const AccessDeniedScreen(),
  });

  final Set<ErpRole> allowedRoles;
  final Widget child;
  final Widget fallback;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Multi-role: any of the user's held roles satisfying the gate is enough.
    final roles = ref.watch(rbacServiceProvider).roles;
    if (!roles.any(allowedRoles.contains)) {
      return fallback;
    }
    return child;
  }
}

/// Requires a single [Permission].
class PermissionGuard extends ConsumerWidget {
  const PermissionGuard({
    super.key,
    required this.permission,
    required this.child,
    this.fallback = const AccessDeniedScreen(),
  });

  final Permission permission;
  final Widget child;
  final Widget fallback;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(rbacServiceProvider).hasPermission(permission)) {
      return fallback;
    }
    return child;
  }
}

/// Requires a manage [Permission] (e.g. [Permission.manageFinance]).
class ManagePermissionGuard extends ConsumerWidget {
  const ManagePermissionGuard({
    super.key,
    required this.permission,
    required this.child,
    this.fallback = const AccessDeniedScreen(),
    this.auditRoute,
  });

  final Permission permission;
  final Widget child;
  final Widget fallback;
  final String? auditRoute;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rbac = ref.watch(rbacServiceProvider);
    if (!rbac.hasManagePermission(permission)) {
      final route = auditRoute ?? GoRouterState.of(context).uri.path;
      unawaited(
        recordDeniedAccess(
          ref,
          route: route,
          permission: permission,
        ),
      );
      return fallback;
    }
    return child;
  }
}

/// Requires an approve [Permission] (e.g. [Permission.approveAdmissions]).
class ApprovePermissionGuard extends ConsumerWidget {
  const ApprovePermissionGuard({
    super.key,
    required this.permission,
    required this.child,
    this.fallback = const AccessDeniedScreen(),
    this.auditRoute,
  });

  final Permission permission;
  final Widget child;
  final Widget fallback;
  final String? auditRoute;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rbac = ref.watch(rbacServiceProvider);
    if (!rbac.hasApprovePermission(permission)) {
      final route = auditRoute ?? GoRouterState.of(context).uri.path;
      unawaited(
        recordDeniedAccess(
          ref,
          route: route,
          permission: permission,
        ),
      );
      return fallback;
    }
    return child;
  }
}

/// Guards admin ERP child routes based on the current location.
class ErpRouteGuard extends ConsumerWidget {
  const ErpRouteGuard({
    super.key,
    required this.child,
  });

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final location = GoRouterState.of(context).uri.path;
    final rbac = ref.watch(rbacServiceProvider);

    // Modules hidden for the school-only build are blocked regardless of
    // permission. Reversible via SchoolBuildScope (hide now, delete later).
    if (SchoolBuildScope.isRouteHidden(location)) {
      return const AccessDeniedScreen();
    }

    // Chain-only modules (franchise / multi-school / organization-builder) are
    // blocked for single independent schools regardless of permission. They
    // surface only when the active org is a chain (M3, 2026-06-22).
    if (ChainScope.isChainOnlyRoute(location) &&
        !ref.watch(isChainOrgProvider)) {
      return const AccessDeniedScreen();
    }

    // Per-school capability gating (B1): a module the school disabled in the
    // Smart School Discovery wizard is not deep-linkable, even by URL. Mirrors
    // the nav filtering in adminNavDestinationsProvider.
    if (!isRouteEnabledForCapabilities(
      location,
      ref.watch(schoolCapabilitiesProvider),
    )) {
      return const AccessDeniedScreen();
    }

    if (!canAccessErpRoute(rbac, location)) {
      final permission = erpRoutePermissionFor(location);
      if (permission != null) {
        unawaited(
          recordDeniedAccess(
            ref,
            route: location,
            permission: permission,
          ),
        );
      }
      return const AccessDeniedScreen();
    }

    return child;
  }
}

/// Control Center is restricted to Super Admin only.
class ControlCenterGuard extends ConsumerWidget {
  const ControlCenterGuard({
    super.key,
    required this.child,
  });

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rbac = ref.watch(rbacServiceProvider);
    if (!rbac.hasRole(ErpRole.superAdmin) ||
        !rbac.hasPermission(Permission.viewControlCenter)) {
      return const AccessDeniedScreen();
    }
    return child;
  }
}
