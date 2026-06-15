import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/security/denied_access_audit.dart';
import '../core/security/erp_role.dart';
import '../core/security/permissions.dart';
import '../core/security/rbac_service.dart';
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
  RouteNames.lessonLogs: Permission.viewLessonLogs,
  RouteNames.timetableAutomation: Permission.manageTimetableAutomation,
  RouteNames.schoolBranding: Permission.viewSchoolBranding,
  RouteNames.whatsAppProvider: Permission.viewWhatsAppProvider,
  RouteNames.subjectAssignments: Permission.viewSubjectAssignments,
  RouteNames.lessonAnalytics: Permission.viewLessonAnalytics,
  RouteNames.timetableOptimization: Permission.viewTimetableOptimization,
  RouteNames.substituteManager: Permission.manageAcademicTimetable,
  RouteNames.teacherReassignment: Permission.manageAcademicTimetable,
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
  for (final entry in kErpRouteViewPermissions.entries) {
    if (location == entry.key || location.startsWith('${entry.key}/')) {
      return entry.value;
    }
  }
  return null;
}

/// Whether [location] is allowed for the given [RbacService].
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
    return const Scaffold(
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
    final role = ref.watch(rbacServiceProvider).role;
    if (role == null || !allowedRoles.contains(role)) {
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
    if (rbac.role != ErpRole.superAdmin ||
        !rbac.hasPermission(Permission.viewControlCenter)) {
      return const AccessDeniedScreen();
    }
    return child;
  }
}
