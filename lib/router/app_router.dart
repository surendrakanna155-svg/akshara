import 'dart:async';

import 'package:flutter/foundation.dart' show kReleaseMode;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/security/erp_role.dart';
import '../features/auth/auth_models.dart';
import '../features/auth/qa_login_persona.dart';
import '../features/auth/login_screen.dart';
import '../features/predictions/predictions_screen.dart';
import '../features/auth/otp_verification_screen.dart';
import '../features/auth/qa_login_screen.dart';
import '../features/auth/splash_screen.dart';
import '../features/auth/staff/staff_login_screen.dart';
import '../features/auth/staff/staff_otp_screen.dart';
import '../features/auth/staff/staff_login_provider.dart';
import '../features/legal/legal_acceptance_screen.dart';
import '../features/notifications/notifications_screen.dart';
import '../features/support/report_issue_screen.dart';
import '../features/support/my_reported_issues_screen.dart';
import '../features/support/support_incident_detail_screen.dart';
import '../features/finance/finance_models.dart';
import '../features/parent/attendance/parent_attendance_screen.dart';
import '../features/parent/academics/parent_academic_report_screen.dart';
import '../features/parent/dashboard/parent_dashboard_screen.dart';
import '../features/parent/events/parent_events_screen.dart';
import '../features/parent/exams/parent_exams_screen.dart';
import '../features/parent/fees/parent_fees_screen.dart';
import '../features/parent/homework/parent_homework_screen.dart';
import '../features/parent/leave/parent_leave_screen.dart';
import '../features/parent/payment/parent_payment_screen.dart';
import '../features/parent/receipts/parent_receipt_pdf_service.dart';
import '../features/parent/receipts/parent_receipt_detail_screen.dart';
import '../features/parent/receipts/parent_receipts_screen.dart';
import '../features/parent/notices/parent_notices_screen.dart';
import '../features/parent/profile/parent_profile_screen.dart';
import '../features/parent/messages/parent_conversation_screen.dart';
import '../features/parent/communication/parent_communication_detail_screen.dart';
import '../features/parent/messages/parent_messages_screen.dart';
import '../features/parent/shell/parent_shell.dart';
import '../features/parent/ptm/parent_ptm_screen.dart';
import '../features/parent/family/parent_family_view_screen.dart';
import '../features/parent/actions/parent_action_inbox_screen.dart';
import '../features/parent/transport/parent_transport_screen.dart';
import '../features/parent/timetable/parent_timetable_screen.dart';
import '../features/student_app/progress/student_progress_screen.dart';
import '../features/student_app/progress/student_report_card_screen.dart';
import '../features/student_app/attendance/student_attendance_screen.dart';
import '../features/student_app/dashboard/student_dashboard_screen.dart';
import '../features/student_app/exams/student_exams_screen.dart';
import '../features/student_app/homework/student_homework_screen.dart';
import '../features/student_app/notices/student_notices_screen.dart';
import '../features/student_app/profile/student_profile_screen.dart';
import '../features/student_app/shell/student_shell.dart';
import '../features/student_app/timetable/student_timetable_screen.dart';
import '../features/teacher/attendance/teacher_attendance_screen.dart';
import '../features/teacher/attendance/teacher_my_attendance_screen.dart';
import '../features/teacher/dashboard/teacher_dashboard_screen.dart';
import '../features/teacher/dashboard/teacher_class_teacher_dashboard_screen.dart';
import '../features/teacher/student_risk/teacher_student_risk_screen.dart';
import '../features/teacher/communication/teacher_parent_communication_screen.dart';
import '../features/teacher/exams/teacher_exams_screen.dart';
import '../features/teacher/homework/teacher_homework_screen.dart';
import '../features/teacher/homework/teacher_homework_create_screen.dart';
import '../features/teacher/homework/teacher_homework_history_screen.dart';
import '../features/teacher/leave/teacher_leave_screen.dart';
import '../features/teacher/profile/teacher_profile_screen.dart';
import '../features/teacher/settings/teacher_settings_screen.dart';
import '../features/teacher/messages/teacher_conversation_screen.dart';
import '../features/teacher/messages/teacher_messages_screen.dart';
import '../features/teacher/shell/teacher_shell.dart';
import '../features/teacher/timetable/teacher_timetable_screen.dart';
import '../features/copilot/dock/copilot_dock_host.dart';
import '../features/admin/admin_shell.dart';
import '../features/admin/backup/backup_restore_screen.dart';
import '../features/entitlements/plan_entitlements_screen.dart';
import '../features/entitlements/organization_plan_assignment_screen.dart';
import '../features/onboarding/unified_onboarding_flow_screen.dart';
import '../features/onboarding/student_onboarding_screen.dart';
import '../core/repositories/repository_providers.dart';
import '../core/tenant/tenant_provider.dart';
import '../core/config/school_build_scope.dart';
import '../core/testing/qa_test_keys.dart';
import 'admin_navigation.dart';
import 'route_guards.dart';
import 'admissions_navigation.dart';
import 'finance_navigation.dart';
import '../features/settings/appearance_settings_screen.dart';
import '../core/reliability/sync_center/sync_center_screen.dart';
import 'copilot_navigation.dart';
import 'education_navigation.dart';
import 'intelligence_navigation.dart';
import 'phase4_navigation.dart';
import 'phase5_navigation.dart';
import 'branch_navigation.dart';
import 'franchise_navigation.dart';
import 'evolution_navigation.dart';
import 'school_completion_navigation.dart';
import '../features/academics/exam_admin/exam_admin_navigation.dart';
import 'management_navigation.dart';
import 'hostel_navigation.dart';
import 'hr_navigation.dart';
import 'alumni_navigation.dart';
import 'inventory_navigation.dart';
import 'library_navigation.dart';
import 'transport_navigation.dart';
import 'control_center_navigation.dart';
import 'director_navigation.dart';
import 'sis_navigation.dart';
import 'parent_navigation.dart';
import 'parent_meetings_navigation.dart';
import 'multi_school_navigation.dart';
import 'organization_builder_navigation.dart';
import 'platform_operations_navigation.dart';
import 'industry_navigation.dart';
import 'healthcare_navigation.dart';
import 'salon_navigation.dart';
import 'restaurant_navigation.dart';
import 'accommodation_navigation.dart';
import 'white_label_navigation.dart';
import 'dynamic_widget_navigation.dart';
import 'route_names.dart';
import 'school_config_navigation.dart';
import 'student_navigation.dart';
import 'teacher_navigation.dart';

/// Creates the application [GoRouter] with auth flow and parent shell routes.
///
/// [readAuth] is invoked on every redirect so auth updates do not require
/// recreating the router (which would reset navigation back to splash).
GoRouter createAppRouter({
  Listenable? refreshListenable,
  required AuthState Function() readAuth,
  bool Function()? readQaLoginEnabled,
  bool Function()? readLegalBlocked,
  List<NavigatorObserver> observers = const [],
}) {
  final rootNavigatorKey = GlobalKey<NavigatorState>();
  String authEntryRoute() => (readQaLoginEnabled?.call() ?? false)
      ? RouteNames.qaLogin
      : RouteNames.login;

  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: RouteNames.splash,
    refreshListenable: refreshListenable,
    observers: observers,
    debugLogDiagnostics: true,
    redirect: (context, state) {
      final auth = readAuth();
      final authResult =
          _authRedirect(auth, state.uri.path, authEntryRoute());
      if (authResult != null) {
        return authResult;
      }
      // Auth is satisfied for this location; now enforce the legal gate.
      return legalGateRedirect(
        auth,
        readLegalBlocked?.call() ?? false,
        state.uri.path,
      );
    },
    routes: [
      GoRoute(
        path: RouteNames.root,
        redirect: (context, state) => RouteNames.splash,
      ),
      GoRoute(
        path: RouteNames.splash,
        name: 'splash',
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: RouteNames.login,
        name: 'login',
        builder: (context, state) => const LoginScreen(),
      ),
      // SEC-10: the QA persona-login route is registered ONLY in non-release
      // builds. `kReleaseMode` is a compile-time const, so in a release build
      // this element is dead-code-eliminated and `QaLoginScreen` (with its
      // hardcoded personas/phone numbers) is tree-shaken out of the binary.
      // QA login is already runtime-disabled in production (SEC-1); this removes
      // the code path and data from the shipped app entirely.
      if (!kReleaseMode)
        GoRoute(
          path: RouteNames.qaLogin,
          name: 'qaLogin',
          builder: (context, state) => const QaLoginScreen(),
        ),
      GoRoute(
        path: RouteNames.otpVerification,
        name: 'otp',
        builder: (context, state) {
          final phone = state.uri.queryParameters['phone'] ?? '';
          final role = UserRole.fromName(state.uri.queryParameters['role']);
          return OtpVerificationScreen(
            phoneNumber: phone,
            role: role,
          );
        },
      ),
      GoRoute(
        path: RouteNames.staffLogin,
        name: 'staffLogin',
        builder: (context, state) => const StaffLoginScreen(),
      ),
      GoRoute(
        path: RouteNames.staffOtp,
        name: 'staffOtp',
        builder: (context, state) {
          final identifier = state.uri.queryParameters['id'] ?? '';
          final typeName = state.uri.queryParameters['type'] ?? 'email';
          final type = StaffLoginIdentifierType.values.firstWhere(
            (t) => t.name == typeName,
            orElse: () => StaffLoginIdentifierType.email,
          );
          return StaffOtpScreen(
            identifier: identifier,
            identifierType: type,
          );
        },
      ),
      GoRoute(
        path: RouteNames.legalAcceptance,
        name: 'legalAcceptance',
        builder: (context, state) => const LegalAcceptanceScreen(),
      ),
      GoRoute(
        path: RouteNames.parent,
        redirect: (context, state) => RouteNames.parentDashboard,
      ),
      GoRoute(
        path: RouteNames.aiAssistantSettings,
        name: 'aiAssistantSettings',
        builder: (context, state) =>
            aiAssistantSettingsRouteBuilder(context, state),
      ),
      GoRoute(
        path: RouteNames.appearanceSettings,
        name: 'appearanceSettings',
        builder: (context, state) => const AppearanceSettingsScreen(),
      ),
      GoRoute(
        path: RouteNames.syncCenter,
        name: 'syncCenter',
        builder: (context, state) => const SyncCenterScreen(),
      ),
      GoRoute(
        path: RouteNames.aiAssistant,
        name: 'aiAssistant',
        builder: (context, state) => aiAssistantRouteBuilder(context, state),
      ),
      GoRoute(
        path: RouteNames.parentNotifications,
        name: 'parentNotifications',
        builder: (context, state) => const NotificationsScreen(),
      ),
      // ASIP Phase 1 — "Report an issue to Akshara Support". Top-level, auth-gated
      // for every persona (see _isSharedSettingsRoute). `/support/new` is declared
      // before `/support/:id` so the literal wins over the id parameter.
      GoRoute(
        path: RouteNames.support,
        name: 'support',
        builder: (context, state) =>
            const AuthenticatedGuard(child: MyReportedIssuesScreen()),
      ),
      GoRoute(
        path: RouteNames.supportNew,
        name: 'supportNew',
        builder: (context, state) =>
            const AuthenticatedGuard(child: ReportIssueScreen()),
      ),
      GoRoute(
        path: RouteNames.supportIncidentDetailPattern,
        name: 'supportIncidentDetail',
        builder: (context, state) => AuthenticatedGuard(
          child: SupportIncidentDetailScreen(
            incidentId: state.pathParameters['id'] ?? '',
          ),
        ),
      ),
      ShellRoute(
        builder: (context, state, child) =>
            CopilotDockHost(child: ParentShell(child: child)),
        routes: [
          GoRoute(
            path: RouteNames.parentDashboard,
            name: 'parentDashboard',
            pageBuilder: (context, state) => NoTransitionPage(
              child: parentDashboardRouteBuilder(context, state),
            ),
          ),
          GoRoute(
            path: RouteNames.parentAttendance,
            name: 'parentAttendance',
            pageBuilder: (context, state) => NoTransitionPage(
              child: parentAttendanceRouteBuilder(context, state),
            ),
          ),
          GoRoute(
            path: RouteNames.parentFees,
            name: 'parentFees',
            pageBuilder: (context, state) => NoTransitionPage(
              child: parentFeesRouteBuilder(context, state),
            ),
          ),
          GoRoute(
            path: RouteNames.parentTimetable,
            name: 'parentTimetable',
            pageBuilder: (context, state) => NoTransitionPage(
              child: parentTimetableRouteBuilder(context, state),
            ),
          ),
          GoRoute(
            path: RouteNames.parentHomework,
            name: 'parentHomework',
            pageBuilder: (context, state) => NoTransitionPage(
              child: parentHomeworkRouteBuilder(context, state),
            ),
          ),
          GoRoute(
            path: RouteNames.parentExams,
            name: 'parentExams',
            pageBuilder: (context, state) => NoTransitionPage(
              child: parentExamsRouteBuilder(context, state),
            ),
          ),
          GoRoute(
            path: RouteNames.parentNotices,
            name: 'parentNotices',
            pageBuilder: (context, state) => NoTransitionPage(
              child: parentNoticesRouteBuilder(context, state),
            ),
          ),
          GoRoute(
            path: RouteNames.parentEvents,
            name: 'parentEvents',
            pageBuilder: (context, state) => NoTransitionPage(
              child: parentEventsRouteBuilder(context, state),
            ),
          ),
          GoRoute(
            path: RouteNames.parentTransport,
            name: 'parentTransport',
            pageBuilder: (context, state) => NoTransitionPage(
              child: parentTransportRouteBuilder(context, state),
            ),
          ),
          GoRoute(
            path: RouteNames.parentPtm,
            name: 'parentPtm',
            pageBuilder: (context, state) => NoTransitionPage(
              child: parentPtmRouteBuilder(context, state),
            ),
          ),
          GoRoute(
            path: RouteNames.parentFamily,
            name: 'parentFamily',
            pageBuilder: (context, state) => NoTransitionPage(
              child: parentFamilyRouteBuilder(context, state),
            ),
          ),
          GoRoute(
            path: RouteNames.parentActionInbox,
            name: 'parentActionInbox',
            pageBuilder: (context, state) => NoTransitionPage(
              child: parentActionInboxRouteBuilder(context, state),
            ),
          ),
          GoRoute(
            path: RouteNames.parentProfile,
            name: 'parentProfile',
            pageBuilder: (context, state) => NoTransitionPage(
              child: parentProfileRouteBuilder(context, state),
            ),
          ),
          GoRoute(
            path: RouteNames.parentExperience,
            name: 'parentExperience',
            pageBuilder: (context, state) => NoTransitionPage(
              child: parentExperienceHubRouteBuilder(context, state),
            ),
          ),
          GoRoute(
            path: RouteNames.parentAcademicReport,
            name: 'parentAcademicReport',
            pageBuilder: (context, state) => NoTransitionPage(
              child: parentAcademicReportRouteBuilder(context, state),
            ),
          ),
          GoRoute(
            path: RouteNames.parentInsights,
            name: 'parentInsights',
            pageBuilder: (context, state) => NoTransitionPage(
              child: parentInsightsRouteBuilder(context, state),
            ),
          ),
          GoRoute(
            path: RouteNames.parentPayment,
            name: 'parentPayment',
            pageBuilder: (context, state) => NoTransitionPage(
              child: parentPaymentRouteBuilder(context, state),
            ),
          ),
          GoRoute(
            path: RouteNames.parentLeave,
            name: 'parentLeave',
            pageBuilder: (context, state) => NoTransitionPage(
              child: parentLeaveRouteBuilder(context, state),
            ),
          ),
          GoRoute(
            path: RouteNames.parentMessages,
            name: 'parentMessages',
            pageBuilder: (context, state) => NoTransitionPage(
              child: parentMessagesRouteBuilder(context, state),
            ),
            routes: [
              GoRoute(
                path: 'comm/:messageId',
                name: 'parentCommunicationMessage',
                pageBuilder: (context, state) => NoTransitionPage(
                  child: parentCommunicationDetailRouteBuilder(context, state),
                ),
              ),
              GoRoute(
                path: ':threadId',
                name: 'parentConversation',
                pageBuilder: (context, state) => NoTransitionPage(
                  child: parentConversationRouteBuilder(context, state),
                ),
              ),
            ],
          ),
          GoRoute(
            path: RouteNames.parentReceipts,
            name: 'parentReceipts',
            pageBuilder: (context, state) => NoTransitionPage(
              child: parentReceiptsRouteBuilder(context, state),
            ),
            routes: [
              GoRoute(
                path: ':receiptId',
                name: 'parentReceiptDetail',
                pageBuilder: (context, state) => NoTransitionPage(
                  child: parentReceiptDetailRouteBuilder(context, state),
                ),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: RouteNames.teacher,
        redirect: (context, state) => RouteNames.teacherDashboard,
      ),
      ShellRoute(
        builder: (context, state, child) =>
            CopilotDockHost(child: TeacherShell(child: child)),
        routes: [
          GoRoute(
            path: RouteNames.teacherDashboard,
            name: 'teacherDashboard',
            pageBuilder: (context, state) => NoTransitionPage(
              child: teacherDashboardRouteBuilder(context, state),
            ),
          ),
          GoRoute(
            path: RouteNames.teacherClassTeacherDashboard,
            name: 'teacherClassTeacherDashboard',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: TeacherClassTeacherDashboardScreen(),
            ),
          ),
          GoRoute(
            path: RouteNames.teacherAttendance,
            name: 'teacherAttendance',
            pageBuilder: (context, state) => NoTransitionPage(
              child: teacherAttendanceRouteBuilder(context, state),
            ),
          ),
          GoRoute(
            path: RouteNames.teacherMyAttendance,
            name: 'teacherMyAttendance',
            pageBuilder: (context, state) => NoTransitionPage(
              child: teacherMyAttendanceRouteBuilder(context, state),
            ),
          ),
          GoRoute(
            path: RouteNames.teacherTimetable,
            name: 'teacherTimetable',
            pageBuilder: (context, state) => NoTransitionPage(
              child: teacherTimetableRouteBuilder(context, state),
            ),
          ),
          GoRoute(
            path: RouteNames.teacherHomework,
            name: 'teacherHomework',
            pageBuilder: (context, state) => NoTransitionPage(
              child: teacherHomeworkRouteBuilder(context, state),
            ),
          ),
          GoRoute(
            path: RouteNames.teacherHomeworkCreate,
            name: 'teacherHomeworkCreate',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: TeacherHomeworkCreateScreen(),
            ),
          ),
          GoRoute(
            path: RouteNames.teacherHomeworkHistory,
            name: 'teacherHomeworkHistory',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: TeacherHomeworkHistoryScreen(),
            ),
          ),
          GoRoute(
            path: RouteNames.teacherExams,
            name: 'teacherExams',
            pageBuilder: (context, state) => NoTransitionPage(
              child: teacherExamsRouteBuilder(context, state),
            ),
          ),
          GoRoute(
            path: RouteNames.teacherParentCommunication,
            name: 'teacherParentCommunication',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: TeacherParentCommunicationScreen(),
            ),
          ),
          GoRoute(
            path: '${RouteNames.teacher}/student-risk/:sisStudentId',
            name: 'teacherStudentRisk',
            pageBuilder: (context, state) => NoTransitionPage(
              child: TeacherStudentRiskScreen(
                sisStudentId: state.pathParameters['sisStudentId'] ?? '',
              ),
            ),
          ),
          GoRoute(
            path: RouteNames.teacherLeave,
            name: 'teacherLeave',
            pageBuilder: (context, state) => NoTransitionPage(
              child: teacherLeaveRouteBuilder(context, state),
            ),
          ),
          GoRoute(
            path: RouteNames.teacherSettings,
            name: 'teacherSettings',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: TeacherSettingsScreen(),
            ),
          ),
          GoRoute(
            path: RouteNames.teacherProfile,
            name: 'teacherProfile',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: TeacherProfileScreen(),
            ),
          ),
          GoRoute(
            path: RouteNames.teacherMessages,
            name: 'teacherMessages',
            pageBuilder: (context, state) => NoTransitionPage(
              child: teacherMessagesRouteBuilder(context, state),
            ),
            routes: [
              GoRoute(
                path: ':threadId',
                name: 'teacherConversation',
                pageBuilder: (context, state) => NoTransitionPage(
                  child: teacherConversationRouteBuilder(context, state),
                ),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: RouteNames.student,
        redirect: (context, state) => RouteNames.studentDashboard,
      ),
      ShellRoute(
        builder: (context, state, child) =>
            CopilotDockHost(child: AdminShell(child: child)),
        routes: [
          GoRoute(
            path: RouteNames.admin,
            name: 'admin',
            pageBuilder: (context, state) => NoTransitionPage(
              child: adminHubRouteBuilder(context, state),
            ),
          ),
          GoRoute(
            path: RouteNames.unifiedOnboarding,
            name: 'unifiedOnboarding',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: UnifiedOnboardingFlowScreen(),
            ),
          ),
          GoRoute(
            path: RouteNames.studentOnboarding,
            name: 'studentOnboarding',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: StudentOnboardingScreen(),
            ),
          ),
          GoRoute(
            path: RouteNames.backupRestore,
            name: 'backupRestore',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: BackupRestoreScreen(),
            ),
          ),
          GoRoute(
            path: RouteNames.planEntitlements,
            name: 'planEntitlements',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: PlanEntitlementsScreen(),
            ),
          ),
          GoRoute(
            path: RouteNames.planAssignment,
            name: 'planAssignment',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: OrganizationPlanAssignmentScreen(),
            ),
          ),
          GoRoute(
            path: RouteNames.copilot,
            name: 'copilot',
            pageBuilder: (context, state) => NoTransitionPage(
              child: copilotRouteBuilder(context, state),
            ),
          ),
          GoRoute(
            path: RouteNames.education,
            name: 'education',
            pageBuilder: (context, state) => NoTransitionPage(
              child: educationRouteBuilder(context, state),
            ),
          ),
          GoRoute(
            path: RouteNames.intelligence,
            name: 'intelligence',
            pageBuilder: (context, state) => NoTransitionPage(
              child: intelligenceRouteBuilder(context, state),
            ),
          ),
          GoRoute(
            path: RouteNames.aiPredictions,
            name: 'aiPredictions',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: PredictionsScreen(),
            ),
          ),
          GoRoute(
            path: RouteNames.studentSuccessIntelligence,
            name: 'studentSuccessIntelligence',
            pageBuilder: (context, state) => NoTransitionPage(
              child: studentSuccessIntelligenceRouteBuilder(context, state),
            ),
          ),
          GoRoute(
            path: RouteNames.examIntelligence,
            name: 'examIntelligence',
            pageBuilder: (context, state) => NoTransitionPage(
              child: examIntelligenceRouteBuilder(context, state),
            ),
          ),
          GoRoute(
            path: RouteNames.teacherEffectiveness,
            name: 'teacherEffectiveness',
            pageBuilder: (context, state) => NoTransitionPage(
              child: teacherEffectivenessRouteBuilder(context, state),
            ),
          ),
          GoRoute(
            path: RouteNames.homeworkIntelligence,
            name: 'homeworkIntelligence',
            pageBuilder: (context, state) => NoTransitionPage(
              child: homeworkIntelligenceRouteBuilder(context, state),
            ),
          ),
          GoRoute(
            path: '${RouteNames.student360}/:studentId',
            name: 'student360',
            pageBuilder: (context, state) => NoTransitionPage(
              child: student360RouteBuilder(context, state),
            ),
          ),
          GoRoute(
            path: RouteNames.employees,
            name: 'employees',
            pageBuilder: (context, state) => NoTransitionPage(
              child: employeePlatformRouteBuilder(context, state),
            ),
          ),
          GoRoute(
            path: RouteNames.inventoryDistribution,
            name: 'inventoryDistribution',
            pageBuilder: (context, state) => NoTransitionPage(
              child: inventoryDistributionRouteBuilder(context, state),
            ),
          ),
          GoRoute(
            path: RouteNames.inventoryReplacements,
            name: 'inventoryReplacements',
            pageBuilder: (context, state) => NoTransitionPage(
              child: inventoryReplacementsRouteBuilder(context, state),
            ),
          ),
          GoRoute(
            path: '${RouteNames.employee360}/:employeeId',
            name: 'employee360',
            pageBuilder: (context, state) => NoTransitionPage(
              child: employee360RouteBuilder(context, state),
            ),
          ),
          GoRoute(
            path: RouteNames.operationsHub,
            name: 'operationsHub',
            pageBuilder: (context, state) => NoTransitionPage(
              child: operationsHubRouteBuilder(context, state),
            ),
          ),
          GoRoute(
            path: RouteNames.resourceOptimization,
            name: 'resourceOptimization',
            pageBuilder: (context, state) => NoTransitionPage(
              child: resourceOptimizationRouteBuilder(context, state),
            ),
          ),
          GoRoute(
            path: RouteNames.aiContent,
            name: 'aiContent',
            pageBuilder: (context, state) => NoTransitionPage(
              child: aiContentRouteBuilder(context, state),
            ),
          ),
          GoRoute(
            path: RouteNames.organizationIntelligence,
            name: 'organizationIntelligence',
            pageBuilder: (context, state) => NoTransitionPage(
              child: organizationIntelligenceRouteBuilder(context, state),
            ),
          ),
          GoRoute(
            path: RouteNames.branches,
            name: 'branches',
            pageBuilder: (context, state) => NoTransitionPage(
              child: branchRouteBuilder(context, state),
            ),
          ),
          GoRoute(
            path: RouteNames.franchise,
            name: 'franchise',
            pageBuilder: (context, state) => NoTransitionPage(
              child: franchiseRouteBuilder(context, state),
            ),
          ),
          GoRoute(
            path: RouteNames.schoolMemories,
            name: 'schoolMemories',
            pageBuilder: (context, state) => NoTransitionPage(
              child: schoolMemoriesRouteBuilder(context, state),
            ),
          ),
          GoRoute(
            path: RouteNames.achievementPromotion,
            name: 'achievementPromotion',
            pageBuilder: (context, state) => NoTransitionPage(
              child: achievementPromotionRouteBuilder(context, state),
            ),
          ),
          GoRoute(
            path: RouteNames.setupWizard,
            name: 'setupWizard',
            pageBuilder: (context, state) => NoTransitionPage(
              child: setupWizardRouteBuilder(context, state),
            ),
          ),
          GoRoute(
            path: RouteNames.dynamicDashboard,
            name: 'dynamicDashboard',
            pageBuilder: (context, state) => NoTransitionPage(
              child: dynamicDashboardRouteBuilder(context, state),
            ),
          ),
          GoRoute(
            path: RouteNames.teacherAssistant,
            name: 'teacherAssistant',
            pageBuilder: (context, state) => NoTransitionPage(
              child: teacherAssistantRouteBuilder(context, state),
            ),
          ),
          GoRoute(
            path: RouteNames.principalCommand,
            name: 'principalCommand',
            pageBuilder: (context, state) => NoTransitionPage(
              child: principalCommandRouteBuilder(context, state),
            ),
          ),
          GoRoute(
            path: RouteNames.growthPlatform,
            name: 'growthPlatform',
            pageBuilder: (context, state) => NoTransitionPage(
              child: growthPlatformRouteBuilder(context, state),
            ),
          ),
          GoRoute(
            path: RouteNames.schoolCompletionHub,
            name: 'schoolCompletionHub',
            pageBuilder: (context, state) => NoTransitionPage(
              child: schoolCompletionHubRouteBuilder(context, state),
            ),
          ),
          GoRoute(
            path: RouteNames.subjectsManagement,
            name: 'subjectsManagement',
            pageBuilder: (context, state) => NoTransitionPage(
              child: subjectsManagementRouteBuilder(context, state),
            ),
          ),
          GoRoute(
            path: RouteNames.examAdministration,
            name: 'examAdministration',
            pageBuilder: (context, state) => NoTransitionPage(
              child: examAdministrationRouteBuilder(context, state),
            ),
            routes: [
              GoRoute(
                path: 'reports',
                name: 'examReports',
                pageBuilder: (context, state) => NoTransitionPage(
                  child: examReportsRouteBuilder(context, state),
                ),
              ),
              GoRoute(
                path: ':examId/marks',
                name: 'examAdministrationMarks',
                pageBuilder: (context, state) => NoTransitionPage(
                  child: examMarksEntryRouteBuilder(context, state),
                ),
              ),
            ],
          ),
          GoRoute(
            path: RouteNames.lessonLogs,
            name: 'lessonLogs',
            pageBuilder: (context, state) => NoTransitionPage(
              child: lessonLogsRouteBuilder(context, state),
            ),
          ),
          GoRoute(
            path: RouteNames.timetableAutomation,
            name: 'timetableAutomation',
            pageBuilder: (context, state) => NoTransitionPage(
              child: timetableAutomationRouteBuilder(context, state),
            ),
          ),
          GoRoute(
            path: RouteNames.schoolBranding,
            name: 'schoolBranding',
            pageBuilder: (context, state) => NoTransitionPage(
              child: schoolBrandingRouteBuilder(context, state),
            ),
          ),
          GoRoute(
            path: RouteNames.whatsAppProvider,
            name: 'whatsAppProvider',
            pageBuilder: (context, state) => NoTransitionPage(
              child: whatsAppProviderRouteBuilder(context, state),
            ),
          ),
          GoRoute(
            path: RouteNames.subjectAssignments,
            name: 'subjectAssignments',
            pageBuilder: (context, state) => NoTransitionPage(
              child: subjectAssignmentsRouteBuilder(context, state),
            ),
          ),
          GoRoute(
            path: RouteNames.lessonAnalytics,
            name: 'lessonAnalytics',
            pageBuilder: (context, state) => NoTransitionPage(
              child: lessonAnalyticsRouteBuilder(context, state),
            ),
          ),
          GoRoute(
            path: RouteNames.timetableOptimization,
            name: 'timetableOptimization',
            pageBuilder: (context, state) => NoTransitionPage(
              child: timetableOptimizationRouteBuilder(context, state),
            ),
          ),
          GoRoute(
            path: RouteNames.substituteManager,
            name: 'substituteManager',
            pageBuilder: (context, state) => NoTransitionPage(
              child: substituteManagerRouteBuilder(context, state),
            ),
          ),
          GoRoute(
            path: RouteNames.teacherReassignment,
            name: 'teacherReassignment',
            pageBuilder: (context, state) => NoTransitionPage(
              child: teacherReassignmentRouteBuilder(context, state),
            ),
          ),
          GoRoute(
            path: RouteNames.classTeacherAssignments,
            name: 'classTeacherAssignments',
            pageBuilder: (context, state) => NoTransitionPage(
              child: classTeacherAssignmentsRouteBuilder(context, state),
            ),
          ),
          GoRoute(
            path: RouteNames.communicationDelivery,
            name: 'communicationDelivery',
            pageBuilder: (context, state) => NoTransitionPage(
              child: communicationDeliveryRouteBuilder(context, state),
            ),
          ),
          GoRoute(
            path: RouteNames.communicationBroadcastAdmin,
            name: 'communicationBroadcastAdmin',
            pageBuilder: (context, state) => NoTransitionPage(
              child: communicationBroadcastAdminRouteBuilder(context, state),
            ),
          ),
          GoRoute(
            path: RouteNames.communicationAnalytics,
            name: 'communicationAnalytics',
            pageBuilder: (context, state) => NoTransitionPage(
              child: communicationAnalyticsRouteBuilder(context, state),
            ),
          ),
          GoRoute(
            path: RouteNames.pilotDashboard,
            name: 'pilotDashboard',
            pageBuilder: (context, state) => NoTransitionPage(
              child: pilotDashboardRouteBuilder(context, state),
            ),
          ),
          GoRoute(
            path: RouteNames.parentActivationDashboard,
            name: 'parentActivationDashboard',
            pageBuilder: (context, state) => NoTransitionPage(
              child: parentActivationDashboardRouteBuilder(context, state),
            ),
          ),
          GoRoute(
            path: RouteNames.roomAllocation,
            name: 'roomAllocation',
            pageBuilder: (context, state) => NoTransitionPage(
              child: roomAllocationRouteBuilder(context, state),
            ),
          ),
          GoRoute(
            path: RouteNames.syllabusAutomation,
            name: 'syllabusAutomation',
            pageBuilder: (context, state) => NoTransitionPage(
              child: syllabusAutomationRouteBuilder(context, state),
            ),
          ),
          GoRoute(
            path: RouteNames.academicProgress,
            name: 'academicProgress',
            pageBuilder: (context, state) => NoTransitionPage(
              child: academicProgressRouteBuilder(context, state),
            ),
          ),
          GoRoute(
            path: RouteNames.timetableIntelligence,
            name: 'timetableIntelligence',
            pageBuilder: (context, state) => NoTransitionPage(
              child: timetableIntelligenceRouteBuilder(context, state),
            ),
          ),
          GoRoute(
            path: RouteNames.parentMeetings,
            name: 'parentMeetings',
            pageBuilder: (context, state) => NoTransitionPage(
              child: parentMeetingsRouteBuilder(context, state),
            ),
          ),
          GoRoute(
            path: RouteNames.multiSchoolPortfolio,
            name: 'multiSchoolPortfolio',
            pageBuilder: (context, state) => NoTransitionPage(
              child: multiSchoolPortfolioRouteBuilder(context, state),
            ),
          ),
          GoRoute(
            path: RouteNames.multiSchoolOnboarding,
            name: 'multiSchoolOnboarding',
            pageBuilder: (context, state) => NoTransitionPage(
              child: multiSchoolOnboardingRouteBuilder(context, state),
            ),
          ),
          GoRoute(
            path: RouteNames.organizationBuilder,
            name: 'organizationBuilder',
            pageBuilder: (context, state) => NoTransitionPage(
              child: organizationBuilderHubRouteBuilder(context, state),
            ),
          ),
          GoRoute(
            path: RouteNames.organizationBuilderInterview,
            name: 'organizationBuilderInterview',
            pageBuilder: (context, state) => NoTransitionPage(
              child: organizationBuilderInterviewRouteBuilder(context, state),
            ),
          ),
          GoRoute(
            path: RouteNames.organizationBuilderPreview,
            name: 'organizationBuilderPreview',
            pageBuilder: (context, state) => NoTransitionPage(
              child: organizationBuilderPreviewRouteBuilder(context, state),
            ),
          ),
          GoRoute(
            path: RouteNames.organizationBuilderProvisioning,
            name: 'organizationBuilderProvisioning',
            pageBuilder: (context, state) => NoTransitionPage(
              child: organizationBuilderProvisioningRouteBuilder(context, state),
            ),
          ),
          GoRoute(
            path: RouteNames.schoolDiscovery,
            name: 'schoolDiscovery',
            pageBuilder: (context, state) => NoTransitionPage(
              child: schoolDiscoveryRouteBuilder(context, state),
            ),
          ),
          GoRoute(
            path: RouteNames.platformOperations,
            name: 'platformOperations',
            pageBuilder: (context, state) => NoTransitionPage(
              child: platformOperationsHubRouteBuilder(context, state),
            ),
          ),
          GoRoute(
            path: RouteNames.platformOperationsAlerts,
            name: 'platformOperationsAlerts',
            pageBuilder: (context, state) => NoTransitionPage(
              child: platformOperationsHubRouteBuilder(context, state),
            ),
          ),
          GoRoute(
            path: RouteNames.platformOperationsSecurity,
            name: 'platformOperationsSecurity',
            pageBuilder: (context, state) => NoTransitionPage(
              child: platformOperationsHubRouteBuilder(context, state),
            ),
          ),
          GoRoute(
            path: RouteNames.platformOperationsTenantIsolation,
            name: 'platformOperationsTenantIsolation',
            pageBuilder: (context, state) => NoTransitionPage(
              child: platformOperationsHubRouteBuilder(context, state),
            ),
          ),
          GoRoute(
            path: RouteNames.platformOperationsReadiness,
            name: 'platformOperationsReadiness',
            pageBuilder: (context, state) => NoTransitionPage(
              child: platformOperationsHubRouteBuilder(context, state),
            ),
          ),
          GoRoute(
            path: RouteNames.industry,
            name: 'industry',
            pageBuilder: (context, state) => NoTransitionPage(
              child: industryHubRouteBuilder(context, state),
            ),
          ),
          GoRoute(
            path: RouteNames.industryFramework,
            name: 'industryFramework',
            pageBuilder: (context, state) => NoTransitionPage(
              child: industryFrameworkRouteBuilder(context, state),
            ),
          ),
          GoRoute(
            path: RouteNames.healthcare,
            name: 'healthcare',
            pageBuilder: (context, state) => NoTransitionPage(
              child: healthcareDashboardRouteBuilder(context, state),
            ),
          ),
          GoRoute(
            path: RouteNames.healthcarePatients,
            name: 'healthcarePatients',
            pageBuilder: (context, state) => NoTransitionPage(
              child: healthcarePatientRouteBuilder(context, state),
            ),
          ),
          GoRoute(
            path: RouteNames.healthcareAppointments,
            name: 'healthcareAppointments',
            pageBuilder: (context, state) => NoTransitionPage(
              child: healthcareAppointmentRouteBuilder(context, state),
            ),
          ),
          GoRoute(
            path: RouteNames.healthcarePractitioners,
            name: 'healthcarePractitioners',
            pageBuilder: (context, state) => NoTransitionPage(
              child: healthcarePractitionerRouteBuilder(context, state),
            ),
          ),
          GoRoute(
            path: RouteNames.healthcareIntelligence,
            name: 'healthcareIntelligence',
            pageBuilder: (context, state) => NoTransitionPage(
              child: healthcareIntelligenceRouteBuilder(context, state),
            ),
          ),
          GoRoute(
            path: RouteNames.salon,
            name: 'salon',
            pageBuilder: (context, state) => NoTransitionPage(
              child: salonDashboardRouteBuilder(context, state),
            ),
          ),
          GoRoute(
            path: RouteNames.salonCustomers,
            name: 'salonCustomers',
            pageBuilder: (context, state) => NoTransitionPage(
              child: salonSalonCustomerRouteBuilder(context, state),
            ),
          ),
          GoRoute(
            path: RouteNames.salonAppointments,
            name: 'salonAppointments',
            pageBuilder: (context, state) => NoTransitionPage(
              child: salonSalonAppointmentRouteBuilder(context, state),
            ),
          ),
          GoRoute(
            path: RouteNames.salonServices,
            name: 'salonServices',
            pageBuilder: (context, state) => NoTransitionPage(
              child: salonSalonServiceRouteBuilder(context, state),
            ),
          ),
          GoRoute(
            path: RouteNames.salonIntelligence,
            name: 'salonIntelligence',
            pageBuilder: (context, state) => NoTransitionPage(
              child: salonIntelligenceRouteBuilder(context, state),
            ),
          ),
          GoRoute(
            path: RouteNames.restaurant,
            name: 'restaurant',
            pageBuilder: (context, state) => NoTransitionPage(
              child: restaurantDashboardRouteBuilder(context, state),
            ),
          ),
          GoRoute(
            path: RouteNames.restaurantTables,
            name: 'restaurantTables',
            pageBuilder: (context, state) => NoTransitionPage(
              child: restaurantRestaurantTableRouteBuilder(context, state),
            ),
          ),
          GoRoute(
            path: RouteNames.restaurantOrders,
            name: 'restaurantOrders',
            pageBuilder: (context, state) => NoTransitionPage(
              child: restaurantRestaurantOrderRouteBuilder(context, state),
            ),
          ),
          GoRoute(
            path: RouteNames.restaurantKitchen,
            name: 'restaurantKitchen',
            pageBuilder: (context, state) => NoTransitionPage(
              child: restaurantKitchenTicketRouteBuilder(context, state),
            ),
          ),
          GoRoute(
            path: RouteNames.restaurantIntelligence,
            name: 'restaurantIntelligence',
            pageBuilder: (context, state) => NoTransitionPage(
              child: restaurantIntelligenceRouteBuilder(context, state),
            ),
          ),
          GoRoute(
            path: RouteNames.accommodation,
            name: 'accommodation',
            pageBuilder: (context, state) => NoTransitionPage(
              child: accommodationDashboardRouteBuilder(context, state),
            ),
          ),
          GoRoute(
            path: RouteNames.accommodationResidents,
            name: 'accommodationResidents',
            pageBuilder: (context, state) => NoTransitionPage(
              child: accommodationResidentRouteBuilder(context, state),
            ),
          ),
          GoRoute(
            path: RouteNames.accommodationOccupancy,
            name: 'accommodationOccupancy',
            pageBuilder: (context, state) => NoTransitionPage(
              child: accommodationRoomOccupancyRouteBuilder(context, state),
            ),
          ),
          GoRoute(
            path: RouteNames.accommodationAllocations,
            name: 'accommodationAllocations',
            pageBuilder: (context, state) => NoTransitionPage(
              child: accommodationAccommodationAllocationRouteBuilder(context, state),
            ),
          ),
          GoRoute(
            path: RouteNames.accommodationIntelligence,
            name: 'accommodationIntelligence',
            pageBuilder: (context, state) => NoTransitionPage(
              child: accommodationIntelligenceRouteBuilder(context, state),
            ),
          ),
          GoRoute(
            path: RouteNames.whiteLabel,
            name: 'whiteLabel',
            pageBuilder: (context, state) => NoTransitionPage(
              child: whiteLabelHubRouteBuilder(context, state),
            ),
          ),
          GoRoute(
            path: RouteNames.whiteLabelBranding,
            name: 'whiteLabelBranding',
            pageBuilder: (context, state) => NoTransitionPage(
              child: whiteLabelBrandingRouteBuilder(context, state),
            ),
          ),
          GoRoute(
            path: RouteNames.whiteLabelTheme,
            name: 'whiteLabelTheme',
            pageBuilder: (context, state) => NoTransitionPage(
              child: whiteLabelThemeRouteBuilder(context, state),
            ),
          ),
          GoRoute(
            path: RouteNames.whiteLabelLogo,
            name: 'whiteLabelLogo',
            pageBuilder: (context, state) => NoTransitionPage(
              child: whiteLabelLogoRouteBuilder(context, state),
            ),
          ),
          GoRoute(
            path: RouteNames.whiteLabelDeployment,
            name: 'whiteLabelDeployment',
            pageBuilder: (context, state) => NoTransitionPage(
              child: whiteLabelDeploymentRouteBuilder(context, state),
            ),
          ),
          GoRoute(
            path: RouteNames.dynamicWidgets,
            name: 'dynamicWidgets',
            pageBuilder: (context, state) => NoTransitionPage(
              child: dynamicWidgetRegistryRouteBuilder(context, state),
            ),
          ),
          GoRoute(
            path: RouteNames.dynamicWidgetLayout,
            name: 'dynamicWidgetLayout',
            pageBuilder: (context, state) => NoTransitionPage(
              child: dynamicWidgetLayoutRouteBuilder(context, state),
            ),
          ),
          GoRoute(
            path: RouteNames.dynamicWidgetRuntime,
            name: 'dynamicWidgetRuntime',
            pageBuilder: (context, state) => NoTransitionPage(
              child: dynamicWidgetRuntimeRouteBuilder(context, state),
            ),
          ),
          GoRoute(
            path: RouteNames.admissions,
            name: 'admissions',
            redirect: admissionsRootRedirect,
            routes: [
              GoRoute(
                path: 'dashboard',
                name: 'admissionsDashboard',
                pageBuilder: (context, state) => NoTransitionPage(
                  child: admissionsDashboardRouteBuilder(context, state),
                ),
              ),
              GoRoute(
                path: 'leads',
                name: 'admissionsLeads',
                pageBuilder: (context, state) => NoTransitionPage(
                  child: admissionsLeadsRouteBuilder(context, state),
                ),
                routes: [
                  GoRoute(
                    path: ':leadId',
                    name: 'admissionsLeadDetail',
                    pageBuilder: (context, state) => NoTransitionPage(
                      child: admissionsLeadDetailRouteBuilder(context, state),
                    ),
                  ),
                ],
              ),
              GoRoute(
                path: 'applications',
                name: 'admissionsApplications',
                pageBuilder: (context, state) => NoTransitionPage(
                  child: admissionsApplicationsRouteBuilder(context, state),
                ),
              ),
              GoRoute(
                path: 'enrollment',
                name: 'admissionsEnrollment',
                pageBuilder: (context, state) => NoTransitionPage(
                  child: admissionsEnrollmentRouteBuilder(context, state),
                ),
              ),
              GoRoute(
                path: 'documents',
                name: 'admissionsDocuments',
                pageBuilder: (context, state) => NoTransitionPage(
                  child: admissionsDocumentsRouteBuilder(context, state),
                ),
              ),
              GoRoute(
                path: 'approval',
                name: 'admissionsApproval',
                pageBuilder: (context, state) => NoTransitionPage(
                  child: admissionsApprovalRouteBuilder(context, state),
                ),
              ),
              GoRoute(
                path: 'fee-handoff',
                name: 'admissionsFeeHandoff',
                pageBuilder: (context, state) => NoTransitionPage(
                  child: admissionsFeeHandoffRouteBuilder(context, state),
                ),
              ),
              GoRoute(
                path: 'reports',
                name: 'admissionsReports',
                pageBuilder: (context, state) => NoTransitionPage(
                  child: admissionsReportsRouteBuilder(context, state),
                ),
              ),
              GoRoute(
                path: 'settings',
                name: 'admissionsSettings',
                pageBuilder: (context, state) => NoTransitionPage(
                  child: admissionsSettingsRouteBuilder(context, state),
                ),
              ),
            ],
          ),
          GoRoute(
            path: RouteNames.finance,
            name: 'finance',
            redirect: financeRootRedirect,
            routes: [
              GoRoute(
                path: 'dashboard',
                name: 'financeDashboard',
                pageBuilder: (context, state) => NoTransitionPage(
                  child: financeDashboardRouteBuilder(context, state),
                ),
              ),
              GoRoute(
                path: 'fee-structures',
                name: 'financeFeeStructures',
                pageBuilder: (context, state) => NoTransitionPage(
                  child: financeFeeStructuresRouteBuilder(context, state),
                ),
              ),
              GoRoute(
                path: 'student-accounts',
                name: 'financeStudentAccounts',
                pageBuilder: (context, state) => NoTransitionPage(
                  child: financeStudentAccountsRouteBuilder(context, state),
                ),
              ),
              GoRoute(
                path: 'fee-assignment',
                name: 'financeFeeAssignment',
                pageBuilder: (context, state) => NoTransitionPage(
                  child: financeFeeAssignmentRouteBuilder(context, state),
                ),
              ),
              GoRoute(
                path: 'collections',
                name: 'financeCollections',
                pageBuilder: (context, state) => NoTransitionPage(
                  child: financeCollectionsRouteBuilder(context, state),
                ),
                routes: [
                  GoRoute(
                    path: ':collectionId',
                    name: 'financeCollectionDetail',
                    pageBuilder: (context, state) => NoTransitionPage(
                      child:
                          financeCollectionDetailRouteBuilder(context, state),
                    ),
                  ),
                ],
              ),
              GoRoute(
                path: 'payments/qr',
                name: 'financeQrPayment',
                pageBuilder: (context, state) => NoTransitionPage(
                  child: financeQrPaymentRouteBuilder(context, state),
                ),
              ),
              GoRoute(
                path: 'payments/offline',
                name: 'financeOfflinePayments',
                pageBuilder: (context, state) => NoTransitionPage(
                  child: financeOfflinePaymentsRouteBuilder(context, state),
                ),
              ),
              GoRoute(
                path: 'defaulters',
                name: 'financeDefaulters',
                pageBuilder: (context, state) => NoTransitionPage(
                  child: financeDefaultersRouteBuilder(context, state),
                ),
              ),
              GoRoute(
                path: 'refunds',
                name: 'financeRefunds',
                pageBuilder: (context, state) => NoTransitionPage(
                  child: financeRefundsRouteBuilder(context, state),
                ),
              ),
              GoRoute(
                path: 'discounts',
                name: 'financeDiscounts',
                pageBuilder: (context, state) => NoTransitionPage(
                  child: financeDiscountsRouteBuilder(context, state),
                ),
              ),
              GoRoute(
                path: 'reports',
                name: 'financeReports',
                pageBuilder: (context, state) => NoTransitionPage(
                  child: financeReportsRouteBuilder(context, state),
                ),
              ),
              GoRoute(
                path: 'reconciliation',
                name: 'financeReconciliation',
                pageBuilder: (context, state) => NoTransitionPage(
                  child: financeReconciliationRouteBuilder(context, state),
                ),
              ),
              GoRoute(
                path: 'settings',
                name: 'financeSettings',
                pageBuilder: (context, state) => NoTransitionPage(
                  child: financeSettingsRouteBuilder(context, state),
                ),
              ),
              GoRoute(
                path: 'intelligence',
                name: 'financeIntelligence',
                pageBuilder: (context, state) => NoTransitionPage(
                  child: financeIntelligenceRouteBuilder(context, state),
                ),
              ),
              GoRoute(
                path: 'executive',
                name: 'financeExecutiveDashboard',
                pageBuilder: (context, state) => NoTransitionPage(
                  child: financeExecutiveDashboardRouteBuilder(context, state),
                ),
              ),
            ],
          ),
          GoRoute(
            path: RouteNames.sis,
            name: 'sis',
            redirect: sisRootRedirect,
            routes: [
              GoRoute(
                path: 'dashboard',
                name: 'sisDashboard',
                pageBuilder: (context, state) => NoTransitionPage(
                  child: sisDashboardRouteBuilder(context, state),
                ),
              ),
              GoRoute(
                path: 'students',
                name: 'sisStudents',
                pageBuilder: (context, state) => NoTransitionPage(
                  child: sisStudentsRouteBuilder(context, state),
                ),
                routes: [
                  GoRoute(
                    path: ':studentId',
                    name: 'sisStudentDetail',
                    pageBuilder: (context, state) => NoTransitionPage(
                      child: sisStudentDetailRouteBuilder(context, state),
                    ),
                  ),
                ],
              ),
              GoRoute(
                path: 'academic-assignment',
                name: 'sisAcademicAssignment',
                pageBuilder: (context, state) => NoTransitionPage(
                  child: sisAcademicAssignmentRouteBuilder(context, state),
                ),
              ),
              GoRoute(
                path: 'admissions-conversion',
                name: 'sisAdmissionsConversion',
                pageBuilder: (context, state) => NoTransitionPage(
                  child: sisAdmissionsConversionRouteBuilder(context, state),
                ),
              ),
              GoRoute(
                path: 'promotion',
                name: 'sisPromotion',
                pageBuilder: (context, state) => NoTransitionPage(
                  child: sisPromotionRouteBuilder(context, state),
                ),
              ),
              GoRoute(
                path: 'reshuffle',
                name: 'sisReshuffle',
                pageBuilder: (context, state) => NoTransitionPage(
                  child: sisReshuffleRouteBuilder(context, state),
                ),
              ),
              GoRoute(
                path: 'section-balance',
                name: 'sisSectionBalance',
                pageBuilder: (context, state) => NoTransitionPage(
                  child: sisSectionBalanceRouteBuilder(context, state),
                ),
              ),
              GoRoute(
                path: 'continuity',
                name: 'sisContinuity',
                pageBuilder: (context, state) => NoTransitionPage(
                  child: sisContinuityRouteBuilder(context, state),
                ),
              ),
              GoRoute(
                path: 'transfers',
                name: 'sisTransfers',
                pageBuilder: (context, state) => NoTransitionPage(
                  child: sisTransfersRouteBuilder(context, state),
                ),
              ),
              GoRoute(
                path: 'onboarding',
                name: 'sisOnboarding',
                pageBuilder: (context, state) => NoTransitionPage(
                  child: sisOnboardingRouteBuilder(context, state),
                ),
              ),
            ],
          ),
          GoRoute(
            path: RouteNames.hr,
            name: 'hr',
            redirect: hrRootRedirect,
            routes: [
              GoRoute(
                path: 'dashboard',
                name: 'hrDashboard',
                pageBuilder: (context, state) => NoTransitionPage(
                  child: hrDashboardRouteBuilder(context, state),
                ),
              ),
              GoRoute(
                path: 'employees',
                name: 'hrEmployees',
                pageBuilder: (context, state) => NoTransitionPage(
                  child: hrEmployeesRouteBuilder(context, state),
                ),
                routes: [
                  GoRoute(
                    path: ':employeeId',
                    name: 'hrEmployeeDetail',
                    pageBuilder: (context, state) => NoTransitionPage(
                      child: hrEmployeeDetailRouteBuilder(context, state),
                    ),
                  ),
                ],
              ),
              GoRoute(
                path: 'attendance',
                name: 'hrAttendance',
                pageBuilder: (context, state) => NoTransitionPage(
                  child: hrAttendanceRouteBuilder(context, state),
                ),
                routes: [
                  // PRA-P0-15 — audited manual-attendance fallback.
                  GoRoute(
                    path: 'manual-request',
                    name: 'hrStaffManualRequest',
                    pageBuilder: (context, state) => NoTransitionPage(
                      child: hrStaffManualRequestRouteBuilder(context, state),
                    ),
                  ),
                  GoRoute(
                    path: 'requests',
                    name: 'hrStaffManualRequestQueue',
                    pageBuilder: (context, state) => NoTransitionPage(
                      child:
                          hrStaffManualRequestQueueRouteBuilder(context, state),
                    ),
                  ),
                ],
              ),
              GoRoute(
                path: 'leave',
                name: 'hrLeave',
                pageBuilder: (context, state) => NoTransitionPage(
                  child: hrLeaveRouteBuilder(context, state),
                ),
              ),
              GoRoute(
                path: 'payroll',
                name: 'hrPayroll',
                pageBuilder: (context, state) => NoTransitionPage(
                  child: hrPayrollRouteBuilder(context, state),
                ),
              ),
              GoRoute(
                path: 'recruitment',
                name: 'hrRecruitment',
                pageBuilder: (context, state) => NoTransitionPage(
                  child: hrRecruitmentRouteBuilder(context, state),
                ),
              ),
              GoRoute(
                path: 'performance',
                name: 'hrPerformance',
                pageBuilder: (context, state) => NoTransitionPage(
                  child: hrPerformanceRouteBuilder(context, state),
                ),
              ),
              GoRoute(
                path: 'reports',
                name: 'hrReports',
                pageBuilder: (context, state) => NoTransitionPage(
                  child: hrReportsRouteBuilder(context, state),
                ),
              ),
              GoRoute(
                path: 'settings',
                name: 'hrSettings',
                pageBuilder: (context, state) => NoTransitionPage(
                  child: hrSettingsRouteBuilder(context, state),
                ),
              ),
            ],
          ),
          GoRoute(
            path: RouteNames.management,
            name: 'management',
            redirect: managementRootRedirect,
            routes: [
              GoRoute(
                path: 'dashboard',
                name: 'managementDashboard',
                pageBuilder: (context, state) => NoTransitionPage(
                  child: managementDashboardRouteBuilder(context, state),
                ),
              ),
              GoRoute(
                path: 'analytics',
                name: 'managementAnalytics',
                pageBuilder: (context, state) => NoTransitionPage(
                  child: managementAnalyticsRouteBuilder(context, state),
                ),
              ),
              GoRoute(
                path: 'admissions',
                name: 'managementAdmissions',
                pageBuilder: (context, state) => NoTransitionPage(
                  child: managementAdmissionsRouteBuilder(context, state),
                ),
              ),
              GoRoute(
                path: 'finance',
                name: 'managementFinance',
                pageBuilder: (context, state) => NoTransitionPage(
                  child: managementFinanceRouteBuilder(context, state),
                ),
              ),
              GoRoute(
                path: 'academics',
                name: 'managementAcademics',
                pageBuilder: (context, state) => NoTransitionPage(
                  child: managementAcademicsRouteBuilder(context, state),
                ),
              ),
              GoRoute(
                path: 'timetable',
                name: 'managementTimetable',
                pageBuilder: (context, state) => NoTransitionPage(
                  child: managementTimetableRouteBuilder(context, state),
                ),
              ),
              GoRoute(
                path: 'intelligence',
                name: 'managementIntelligence',
                pageBuilder: (context, state) => NoTransitionPage(
                  child: managementIntelligenceRouteBuilder(context, state),
                ),
              ),
              GoRoute(
                path: 'performance',
                name: 'managementPerformance',
                pageBuilder: (context, state) => NoTransitionPage(
                  child: managementPerformanceRouteBuilder(context, state),
                ),
              ),
              GoRoute(
                path: 'tasks',
                name: 'managementTasks',
                pageBuilder: (context, state) => NoTransitionPage(
                  child: managementTasksRouteBuilder(context, state),
                ),
              ),
              GoRoute(
                path: 'approvals',
                name: 'managementApprovals',
                pageBuilder: (context, state) => NoTransitionPage(
                  child: managementApprovalsRouteBuilder(context, state),
                ),
              ),
              GoRoute(
                path: 'attendance-corrections',
                name: 'managementAttendanceCorrections',
                pageBuilder: (context, state) => NoTransitionPage(
                  child: managementAttendanceCorrectionsRouteBuilder(
                    context,
                    state,
                  ),
                ),
              ),
              GoRoute(
                path: 'office-attendance',
                name: 'managementOfficeAttendance',
                pageBuilder: (context, state) => NoTransitionPage(
                  child: managementOfficeAttendanceRouteBuilder(
                    context,
                    state,
                  ),
                ),
              ),
              GoRoute(
                path: 'workflow-automation',
                name: 'managementWorkflowAutomation',
                pageBuilder: (context, state) => NoTransitionPage(
                  child:
                      managementWorkflowAutomationRouteBuilder(context, state),
                ),
              ),
              GoRoute(
                path: 'settings',
                name: 'managementSettings',
                pageBuilder: (context, state) => NoTransitionPage(
                  child: managementSettingsRouteBuilder(context, state),
                ),
              ),
              GoRoute(
                path: 'school-calendar',
                name: 'managementSchoolCalendar',
                pageBuilder: (context, state) => NoTransitionPage(
                  child: managementSchoolCalendarRouteBuilder(context, state),
                ),
              ),
            ],
          ),
          GoRoute(
            path: RouteNames.transport,
            name: 'transport',
            redirect: transportRootRedirect,
            routes: [
              GoRoute(
                path: 'dashboard',
                name: 'transportDashboard',
                pageBuilder: (context, state) => NoTransitionPage(
                  child: transportDashboardRouteBuilder(context, state),
                ),
              ),
              GoRoute(
                path: 'routes',
                name: 'transportRoutes',
                pageBuilder: (context, state) => NoTransitionPage(
                  child: transportRoutesRouteBuilder(context, state),
                ),
              ),
              GoRoute(
                path: 'vehicles',
                name: 'transportVehicles',
                pageBuilder: (context, state) => NoTransitionPage(
                  child: transportVehiclesRouteBuilder(context, state),
                ),
              ),
              GoRoute(
                path: 'drivers',
                name: 'transportDrivers',
                pageBuilder: (context, state) => NoTransitionPage(
                  child: transportDriversRouteBuilder(context, state),
                ),
              ),
              GoRoute(
                path: 'allocation',
                name: 'transportAllocation',
                pageBuilder: (context, state) => NoTransitionPage(
                  child: transportAllocationRouteBuilder(context, state),
                ),
              ),
              GoRoute(
                path: 'attendance',
                name: 'transportAttendance',
                pageBuilder: (context, state) => NoTransitionPage(
                  child: transportAttendanceRouteBuilder(context, state),
                ),
              ),
              GoRoute(
                path: 'tracking',
                name: 'transportTracking',
                pageBuilder: (context, state) => NoTransitionPage(
                  child: transportTrackingRouteBuilder(context, state),
                ),
              ),
              GoRoute(
                path: 'reports',
                name: 'transportReports',
                pageBuilder: (context, state) => NoTransitionPage(
                  child: transportReportsRouteBuilder(context, state),
                ),
              ),
              GoRoute(
                path: 'settings',
                name: 'transportSettings',
                pageBuilder: (context, state) => NoTransitionPage(
                  child: transportSettingsRouteBuilder(context, state),
                ),
              ),
            ],
          ),
          GoRoute(
            path: RouteNames.hostel,
            name: 'hostel',
            redirect: hostelRootRedirect,
            routes: [
              GoRoute(
                path: 'dashboard',
                name: 'hostelDashboard',
                pageBuilder: (context, state) => NoTransitionPage(
                  child: hostelDashboardRouteBuilder(context, state),
                ),
              ),
              GoRoute(
                path: 'students',
                name: 'hostelStudents',
                pageBuilder: (context, state) => NoTransitionPage(
                  child: hostelStudentsRouteBuilder(context, state),
                ),
              ),
              GoRoute(
                path: 'rooms',
                name: 'hostelRooms',
                pageBuilder: (context, state) => NoTransitionPage(
                  child: hostelRoomsRouteBuilder(context, state),
                ),
              ),
              GoRoute(
                path: 'attendance',
                name: 'hostelAttendance',
                pageBuilder: (context, state) => NoTransitionPage(
                  child: hostelAttendanceRouteBuilder(context, state),
                ),
              ),
              GoRoute(
                path: 'leave',
                name: 'hostelLeave',
                pageBuilder: (context, state) => NoTransitionPage(
                  child: hostelLeaveRouteBuilder(context, state),
                ),
              ),
              GoRoute(
                path: 'mess',
                name: 'hostelMess',
                pageBuilder: (context, state) => NoTransitionPage(
                  child: hostelMessRouteBuilder(context, state),
                ),
              ),
              GoRoute(
                path: 'visitors',
                name: 'hostelVisitors',
                pageBuilder: (context, state) => NoTransitionPage(
                  child: hostelVisitorsRouteBuilder(context, state),
                ),
              ),
              GoRoute(
                path: 'reports',
                name: 'hostelReports',
                pageBuilder: (context, state) => NoTransitionPage(
                  child: hostelReportsRouteBuilder(context, state),
                ),
              ),
            ],
          ),
          GoRoute(
            path: RouteNames.library,
            name: 'library',
            redirect: libraryRootRedirect,
            routes: [
              GoRoute(
                path: 'dashboard',
                name: 'libraryDashboard',
                pageBuilder: (context, state) => NoTransitionPage(
                  child: libraryDashboardRouteBuilder(context, state),
                ),
              ),
              GoRoute(
                path: 'catalog',
                name: 'libraryCatalog',
                pageBuilder: (context, state) => NoTransitionPage(
                  child: libraryCatalogRouteBuilder(context, state),
                ),
              ),
              GoRoute(
                path: 'issues',
                name: 'libraryIssues',
                pageBuilder: (context, state) => NoTransitionPage(
                  child: libraryIssuesRouteBuilder(context, state),
                ),
              ),
              GoRoute(
                path: 'returns',
                name: 'libraryReturns',
                pageBuilder: (context, state) => NoTransitionPage(
                  child: libraryReturnsRouteBuilder(context, state),
                ),
              ),
              GoRoute(
                path: 'members',
                name: 'libraryMembers',
                pageBuilder: (context, state) => NoTransitionPage(
                  child: libraryMembersRouteBuilder(context, state),
                ),
              ),
              GoRoute(
                path: 'fines',
                name: 'libraryFines',
                pageBuilder: (context, state) => NoTransitionPage(
                  child: libraryFinesRouteBuilder(context, state),
                ),
              ),
              GoRoute(
                path: 'resources',
                name: 'libraryResources',
                pageBuilder: (context, state) => NoTransitionPage(
                  child: libraryResourcesRouteBuilder(context, state),
                ),
              ),
              GoRoute(
                path: 'reports',
                name: 'libraryReports',
                pageBuilder: (context, state) => NoTransitionPage(
                  child: libraryReportsRouteBuilder(context, state),
                ),
              ),
              GoRoute(
                path: 'overdue',
                name: 'libraryOverdue',
                pageBuilder: (context, state) => NoTransitionPage(
                  child: libraryOverdueRouteBuilder(context, state),
                ),
              ),
            ],
          ),
          GoRoute(
            path: RouteNames.inventory,
            name: 'inventory',
            redirect: inventoryRootRedirect,
            routes: [
              GoRoute(
                path: 'dashboard',
                name: 'inventoryDashboard',
                pageBuilder: (context, state) => NoTransitionPage(
                  child: inventoryDashboardRouteBuilder(context, state),
                ),
              ),
              GoRoute(
                path: 'assets',
                name: 'inventoryAssets',
                pageBuilder: (context, state) => NoTransitionPage(
                  child: inventoryAssetsRouteBuilder(context, state),
                ),
              ),
              GoRoute(
                path: 'categories',
                name: 'inventoryCategories',
                pageBuilder: (context, state) => NoTransitionPage(
                  child: inventoryCategoriesRouteBuilder(context, state),
                ),
              ),
              GoRoute(
                path: 'allocation',
                name: 'inventoryAllocation',
                pageBuilder: (context, state) => NoTransitionPage(
                  child: inventoryAllocationRouteBuilder(context, state),
                ),
              ),
              GoRoute(
                path: 'maintenance',
                name: 'inventoryMaintenance',
                pageBuilder: (context, state) => NoTransitionPage(
                  child: inventoryMaintenanceRouteBuilder(context, state),
                ),
              ),
              GoRoute(
                path: 'procurement',
                name: 'inventoryProcurement',
                pageBuilder: (context, state) => NoTransitionPage(
                  child: inventoryProcurementRouteBuilder(context, state),
                ),
              ),
              GoRoute(
                path: 'vendors',
                name: 'inventoryVendors',
                pageBuilder: (context, state) => NoTransitionPage(
                  child: inventoryVendorsRouteBuilder(context, state),
                ),
              ),
              GoRoute(
                path: 'stock',
                name: 'inventoryStock',
                pageBuilder: (context, state) => NoTransitionPage(
                  child: inventoryStockRouteBuilder(context, state),
                ),
              ),
              GoRoute(
                path: 'stock-approvals',
                name: 'inventoryStockApprovals',
                pageBuilder: (context, state) => NoTransitionPage(
                  child: inventoryStockApprovalsRouteBuilder(context, state),
                ),
              ),
              GoRoute(
                path: 'reports',
                name: 'inventoryReports',
                pageBuilder: (context, state) => NoTransitionPage(
                  child: inventoryReportsRouteBuilder(context, state),
                ),
              ),
              GoRoute(
                path: 'copilot',
                name: 'inventoryCopilot',
                pageBuilder: (context, state) => NoTransitionPage(
                  child: inventoryCopilotRouteBuilder(context, state),
                ),
              ),
              GoRoute(
                path: 'lifecycle',
                name: 'inventoryLifecycle',
                pageBuilder: (context, state) => NoTransitionPage(
                  child: inventoryLifecycleRouteBuilder(context, state),
                ),
              ),
            ],
          ),
          GoRoute(
            path: RouteNames.alumni,
            name: 'alumni',
            redirect: alumniRootRedirect,
            routes: [
              GoRoute(
                path: 'dashboard',
                name: 'alumniDashboard',
                pageBuilder: (context, state) => NoTransitionPage(
                  child: alumniDashboardRouteBuilder(context, state),
                ),
              ),
              GoRoute(
                path: 'registry',
                name: 'alumniRegistry',
                pageBuilder: (context, state) => NoTransitionPage(
                  child: alumniRegistryRouteBuilder(context, state),
                ),
              ),
              GoRoute(
                path: 'profile/:alumniId',
                name: 'alumniProfile',
                pageBuilder: (context, state) => NoTransitionPage(
                  child: alumniProfileRouteBuilder(context, state),
                ),
              ),
              GoRoute(
                path: 'events',
                name: 'alumniEvents',
                pageBuilder: (context, state) => NoTransitionPage(
                  child: alumniEventsRouteBuilder(context, state),
                ),
              ),
              GoRoute(
                path: 'donations',
                name: 'alumniDonations',
                pageBuilder: (context, state) => NoTransitionPage(
                  child: alumniDonationsRouteBuilder(context, state),
                ),
              ),
              GoRoute(
                path: 'campaigns',
                name: 'alumniCampaigns',
                pageBuilder: (context, state) => NoTransitionPage(
                  child: alumniCampaignsRouteBuilder(context, state),
                ),
              ),
              GoRoute(
                path: 'mentorship',
                name: 'alumniMentorship',
                pageBuilder: (context, state) => NoTransitionPage(
                  child: alumniMentorshipRouteBuilder(context, state),
                ),
              ),
              GoRoute(
                path: 'reports',
                name: 'alumniReports',
                pageBuilder: (context, state) => NoTransitionPage(
                  child: alumniReportsRouteBuilder(context, state),
                ),
              ),
              GoRoute(
                path: 'settings',
                name: 'alumniSettings',
                pageBuilder: (context, state) => NoTransitionPage(
                  child: alumniSettingsRouteBuilder(context, state),
                ),
              ),
            ],
          ),
          GoRoute(
            path: RouteNames.controlCenter,
            name: 'controlCenter',
            redirect: controlCenterRootRedirect,
            routes: [
              GoRoute(
                path: 'dashboard',
                name: 'controlCenterDashboard',
                pageBuilder: (context, state) => NoTransitionPage(
                  child: controlCenterDashboardRouteBuilder(context, state),
                ),
              ),
              GoRoute(
                path: 'intelligence',
                name: 'controlCenterIntelligence',
                pageBuilder: (context, state) => NoTransitionPage(
                  child: controlCenterIntelligenceRouteBuilder(context, state),
                ),
              ),
              GoRoute(
                path: 'schools',
                name: 'controlCenterSchools',
                pageBuilder: (context, state) => NoTransitionPage(
                  child: controlCenterSchoolsRouteBuilder(context, state),
                ),
              ),
              GoRoute(
                path: 'subscriptions',
                name: 'controlCenterSubscriptions',
                pageBuilder: (context, state) => NoTransitionPage(
                  child: controlCenterSubscriptionsRouteBuilder(context, state),
                ),
              ),
              GoRoute(
                path: 'billing',
                name: 'controlCenterBilling',
                pageBuilder: (context, state) => NoTransitionPage(
                  child: controlCenterBillingRouteBuilder(context, state),
                ),
              ),
              GoRoute(
                path: 'crm',
                name: 'controlCenterCrm',
                pageBuilder: (context, state) => NoTransitionPage(
                  child: controlCenterCrmRouteBuilder(context, state),
                ),
              ),
              GoRoute(
                path: 'support',
                name: 'controlCenterSupport',
                pageBuilder: (context, state) => NoTransitionPage(
                  child: controlCenterSupportRouteBuilder(context, state),
                ),
              ),
              GoRoute(
                path: 'success',
                name: 'controlCenterSuccess',
                pageBuilder: (context, state) => NoTransitionPage(
                  child: controlCenterSuccessRouteBuilder(context, state),
                ),
              ),
              GoRoute(
                path: 'white-label',
                name: 'controlCenterWhiteLabel',
                pageBuilder: (context, state) => NoTransitionPage(
                  child: controlCenterWhiteLabelRouteBuilder(context, state),
                ),
              ),
              GoRoute(
                path: 'analytics',
                name: 'controlCenterAnalytics',
                pageBuilder: (context, state) => NoTransitionPage(
                  child: controlCenterAnalyticsRouteBuilder(context, state),
                ),
              ),
              GoRoute(
                path: 'monitoring',
                name: 'controlCenterMonitoring',
                pageBuilder: (context, state) => NoTransitionPage(
                  child: controlCenterMonitoringRouteBuilder(context, state),
                ),
              ),
              GoRoute(
                path: 'roles',
                name: 'controlCenterRoles',
                pageBuilder: (context, state) => NoTransitionPage(
                  child: controlCenterRolesRouteBuilder(context, state),
                ),
              ),
              GoRoute(
                path: 'settings',
                name: 'controlCenterSettings',
                pageBuilder: (context, state) => NoTransitionPage(
                  child: controlCenterSettingsRouteBuilder(context, state),
                ),
              ),
              GoRoute(
                path: 'providers',
                name: 'controlCenterProviders',
                pageBuilder: (context, state) => NoTransitionPage(
                  child: controlCenterProvidersRouteBuilder(context, state),
                ),
              ),
              GoRoute(
                path: 'features',
                name: 'controlCenterFeatures',
                pageBuilder: (context, state) => NoTransitionPage(
                  child: controlCenterFeaturesRouteBuilder(context, state),
                ),
              ),
            ],
          ),
          GoRoute(
            path: RouteNames.director,
            name: 'director',
            redirect: directorRootRedirect,
            routes: [
              GoRoute(
                path: 'dashboard',
                name: 'directorDashboard',
                pageBuilder: (context, state) => NoTransitionPage(
                  child: directorDashboardRouteBuilder(context, state),
                ),
              ),
              GoRoute(
                path: 'schools',
                name: 'directorSchools',
                pageBuilder: (context, state) => NoTransitionPage(
                  child: directorSchoolsRouteBuilder(context, state),
                ),
              ),
              // DIR-D1 — audited, read-only per-school drill-down.
              GoRoute(
                path: 'schools/:id',
                name: 'directorSchoolSnapshot',
                pageBuilder: (context, state) => NoTransitionPage(
                  child: directorSchoolSnapshotRouteBuilder(context, state),
                ),
              ),
              GoRoute(
                path: 'portfolio',
                name: 'directorPortfolio',
                pageBuilder: (context, state) => NoTransitionPage(
                  child: directorPortfolioRouteBuilder(context, state),
                ),
              ),
              GoRoute(
                path: 'revenue',
                name: 'directorRevenue',
                pageBuilder: (context, state) => NoTransitionPage(
                  child: directorRevenueRouteBuilder(context, state),
                ),
              ),
              GoRoute(
                path: 'growth',
                name: 'directorGrowth',
                pageBuilder: (context, state) => NoTransitionPage(
                  child: directorGrowthRouteBuilder(context, state),
                ),
              ),
              GoRoute(
                path: 'marketing',
                name: 'directorMarketing',
                pageBuilder: (context, state) => NoTransitionPage(
                  child: directorMarketingRouteBuilder(context, state),
                ),
              ),
              GoRoute(
                path: 'admissions',
                name: 'directorAdmissions',
                pageBuilder: (context, state) => NoTransitionPage(
                  child: directorAdmissionsRouteBuilder(context, state),
                ),
              ),
              GoRoute(
                path: 'compliance',
                name: 'directorCompliance',
                pageBuilder: (context, state) => NoTransitionPage(
                  child: directorComplianceRouteBuilder(context, state),
                ),
              ),
              GoRoute(
                path: 'reports',
                name: 'directorReports',
                pageBuilder: (context, state) => NoTransitionPage(
                  child: directorReportsRouteBuilder(context, state),
                ),
              ),
            ],
          ),
        ],
      ),
      ShellRoute(
        builder: (context, state, child) =>
            CopilotDockHost(child: StudentShell(child: child)),
        routes: [
          GoRoute(
            path: RouteNames.studentDashboard,
            name: 'studentDashboard',
            pageBuilder: (context, state) => NoTransitionPage(
              child: studentDashboardRouteBuilder(context, state),
            ),
          ),
          GoRoute(
            path: RouteNames.studentAttendance,
            name: 'studentAttendance',
            pageBuilder: (context, state) => NoTransitionPage(
              child: studentAttendanceRouteBuilder(context, state),
            ),
          ),
          GoRoute(
            path: RouteNames.studentTimetable,
            name: 'studentTimetable',
            pageBuilder: (context, state) => NoTransitionPage(
              child: studentTimetableRouteBuilder(context, state),
            ),
          ),
          GoRoute(
            path: RouteNames.studentHomework,
            name: 'studentHomework',
            pageBuilder: (context, state) => NoTransitionPage(
              child: studentHomeworkRouteBuilder(context, state),
            ),
          ),
          GoRoute(
            path: RouteNames.studentExams,
            name: 'studentExams',
            pageBuilder: (context, state) => NoTransitionPage(
              child: studentExamsRouteBuilder(context, state),
            ),
          ),
          GoRoute(
            path: RouteNames.studentReportCard,
            name: 'studentReportCard',
            pageBuilder: (context, state) => NoTransitionPage(
              child: studentReportCardRouteBuilder(context, state),
            ),
          ),
          GoRoute(
            path: RouteNames.studentProgress,
            name: 'studentProgress',
            pageBuilder: (context, state) => NoTransitionPage(
              child: studentProgressRouteBuilder(context, state),
            ),
          ),
          GoRoute(
            path: RouteNames.studentNotices,
            name: 'studentNotices',
            pageBuilder: (context, state) => NoTransitionPage(
              child: studentNoticesRouteBuilder(context, state),
            ),
          ),
          GoRoute(
            path: RouteNames.studentProfile,
            name: 'studentProfile',
            pageBuilder: (context, state) => NoTransitionPage(
              child: studentProfileRouteBuilder(context, state),
            ),
          ),
        ],
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      appBar: AppBar(title: const Text('Page not found')),
      body: Center(
        child: Text('No route for: ${state.uri}'),
      ),
    ),
  );
}

String? _authRedirect(AuthState auth, String location, String entryRoute) {
  final isSplash = location == RouteNames.splash;
  final isLogin = location == RouteNames.login;
  final isQaLogin = location == RouteNames.qaLogin;
  final isOtp = location == RouteNames.otpVerification;
  final isStaffLogin = location == RouteNames.staffLogin;
  final isStaffOtp = location == RouteNames.staffOtp;
  final isAuthEntryRoute =
      isSplash || isLogin || isQaLogin || isOtp || isStaffLogin || isStaffOtp;

  if (auth.status == AuthStatus.unknown) {
    return isSplash ? null : RouteNames.splash;
  }

  if (auth.status == AuthStatus.otpPending) {
    if (isOtp) {
      return null;
    }
    final phone = auth.phoneNumber ?? '';
    final role = auth.role?.name ?? '';
    return '${RouteNames.otpVerification}?phone=$phone&role=$role';
  }

  final isAuthenticated = auth.isAuthenticated;
  final isProtectedRoute = _isProtectedRoute(location);

  if (!isAuthenticated && isProtectedRoute) {
    return entryRoute;
  }

  if (isAuthenticated &&
      (isLogin || isQaLogin || isOtp || isStaffLogin || isStaffOtp)) {
    return homeRouteForAuth(auth);
  }

  if (isSplash) {
    return null;
  }

  if (!isAuthenticated && !isAuthEntryRoute && location == RouteNames.root) {
    return RouteNames.splash;
  }

  if (isAuthenticated && isProtectedRoute && !_canAccessRoute(auth, location)) {
    return homeRouteForRole(auth.role);
  }

  return null;
}

/// Enforces the mandatory legal-acceptance gate AFTER [_authRedirect] has allowed
/// the location. When [blocked] (the backend positively reported outstanding
/// mandatory policies), an authenticated user is redirected to the acceptance
/// screen and cannot navigate elsewhere until they accept. When not blocked, a
/// user who somehow lands on the gate is sent home. Anything other than a
/// definitive "blocked" is fail-open, so a legal-endpoint outage never traps
/// users out of the app.
String? legalGateRedirect(AuthState auth, bool blocked, String location) {
  if (!auth.isAuthenticated) return null;
  final isGateRoute = location == RouteNames.legalAcceptance;
  if (blocked) {
    return isGateRoute ? null : RouteNames.legalAcceptance;
  }
  if (isGateRoute) {
    return homeRouteForAuth(auth);
  }
  return null;
}

bool _isAiAssistantRoute(String location) {
  return location == RouteNames.aiAssistant ||
      location == RouteNames.aiAssistantSettings ||
      location.startsWith('${RouteNames.aiAssistant}/');
}

/// Shared, persona-agnostic settings reachable by any authenticated user
/// (e.g. Appearance / theme). Not an admin ERP route — authorized on
/// authentication alone, like AI Assistant settings.
bool _isSharedSettingsRoute(String location) {
  return location == RouteNames.appearanceSettings ||
      // ASIP: "Report an issue" is a shared, persona-agnostic surface — every
      // authenticated school user may reach it (auth-gated, no RBAC permission).
      location == RouteNames.support ||
      location.startsWith('${RouteNames.support}/');
}

bool _isProtectedRoute(String location) {
  return location.startsWith('/parent') ||
      location.startsWith('/teacher') ||
      location.startsWith('/student') ||
      _isAiAssistantRoute(location) ||
      _isSharedSettingsRoute(location) ||
      isAdminErpRoute(location);
}

bool _canAccessRoute(AuthState auth, String location) {
  if (_isAiAssistantRoute(location) || _isSharedSettingsRoute(location)) {
    return auth.isAuthenticated;
  }

  if (isAdminErpRoute(location)) {
    return canAccessAdminErpShell(auth);
  }

  return switch (auth.role) {
    UserRole.parent => location.startsWith('/parent'),
    UserRole.teacher => location.startsWith('/teacher'),
    UserRole.student => location.startsWith('/student'),
    // Cross-shell fix (UX Batch 1, Step 5): admin ERP routes are already handled
    // above. Here (non-admin routes) a staff user may enter /teacher ONLY if they
    // actually hold the teacher role (a multi-hat user such as Teacher +
    // Inventory Manager). A non-teaching staff member (e.g. a librarian) — and
    // staff in general — can no longer reach teacher/parent/student shells.
    UserRole.staff => location.startsWith('/teacher') &&
        (auth.claims?.hasRole(ErpRole.teacher) ?? false),
    null => false,
  };
}

/// Role-based home route after login, OTP, or splash bootstrap.
String homeRouteForRole(UserRole? role) {
  return switch (role) {
    UserRole.parent => RouteNames.parentDashboard,
    UserRole.teacher => RouteNames.teacherDashboard,
    UserRole.student => RouteNames.studentDashboard,
    UserRole.staff => RouteNames.admin,
    null => RouteNames.login,
  };
}

/// Home route using staff ERP claims when present (QA / staff sessions).
String homeRouteForAuth(AuthState auth) {
  if (auth.role == UserRole.staff && auth.claims?.erpRole != null) {
    return homeRouteForStaffErp(auth.claims!.erpRole);
  }
  return homeRouteForRole(auth.role);
}

/// Parent academic report (v13.2 — structured summary, no AI chat).
Widget parentAcademicReportRouteBuilder(
    BuildContext context, GoRouterState state) {
  return const ParentAcademicReportScreen();
}

/// Dashboard screen wired with router navigation.
Widget parentDashboardRouteBuilder(BuildContext context, GoRouterState state) {
  return Consumer(
    builder: (context, ref, _) {
      return ParentDashboardScreen(
        onNavigate: (actionId) =>
            handleParentDashboardNavigation(context, actionId, ref: ref),
      );
    },
  );
}

/// Attendance screen with notification bell routing.
Widget parentAttendanceRouteBuilder(BuildContext context, GoRouterState state) {
  return ParentAttendanceScreen(
    onNotificationsTap: () => context.push(RouteNames.parentNotifications),
    onAcademicsNavigate: (destination) =>
        handleParentAcademicsNavigation(context, destination),
  );
}

/// Fees screen with notification bell routing.
Widget parentFeesRouteBuilder(BuildContext context, GoRouterState state) {
  return ParentFeesScreen(
    onNotificationsTap: () => context.push(RouteNames.parentNotifications),
    onPayNow: ({String? installmentId}) => handleParentFeesNavigation(
      context,
      installmentId: installmentId,
      openPayment: true,
    ),
    onViewReceipt: (installmentId) => handleParentFeesNavigation(
      context,
      receiptId: _receiptIdForInstallment(installmentId),
    ),
    onPaymentHistoryItemTap: (item) => handleParentFeesNavigation(
      context,
      receiptId: switch (item.id) {
        'ph_1' => 'rcpt_term_1',
        'ph_2' => 'rcpt_ph_2',
        'ph_3' => 'rcpt_ph_3',
        'ph_4' => 'rcpt_ph_4',
        _ => 'rcpt_${item.id}',
      },
    ),
    onOpenReceipts: () => handleParentFeesNavigation(
      context,
      openReceipts: true,
    ),
  );
}

String _receiptIdForInstallment(String installmentId) {
  return switch (installmentId) {
    'term_1' => 'rcpt_term_1',
    'term_2' => 'rcpt_term_2',
    _ => 'rcpt_$installmentId',
  };
}

/// Timetable screen (PA-04).
Widget parentTimetableRouteBuilder(BuildContext context, GoRouterState state) {
  return ParentTimetableScreen(
    onNotificationsTap: () => context.push(RouteNames.parentNotifications),
  );
}

/// Homework list screen (PA-05).
Widget parentHomeworkRouteBuilder(BuildContext context, GoRouterState state) {
  return ParentHomeworkScreen(
    onNotificationsTap: () => context.push(RouteNames.parentNotifications),
  );
}

/// Exams screen (PA-06).
Widget parentExamsRouteBuilder(BuildContext context, GoRouterState state) {
  return ParentExamsScreen(
    onNotificationsTap: () => context.push(RouteNames.parentNotifications),
  );
}

/// School notices screen (PA-07).
Widget parentNoticesRouteBuilder(BuildContext context, GoRouterState state) {
  return ParentNoticesScreen(
    onNotificationsTap: () => context.push(RouteNames.parentNotifications),
  );
}

/// School events screen (PA-08).
Widget parentEventsRouteBuilder(BuildContext context, GoRouterState state) {
  return ParentEventsScreen(
    onNotificationsTap: () => context.push(RouteNames.parentNotifications),
  );
}

/// Parent transport allocation and ETA (PA-12).
Widget parentTransportRouteBuilder(BuildContext context, GoRouterState state) {
  return ParentTransportScreen(
    onNotificationsTap: () => context.push(RouteNames.parentNotifications),
  );
}

/// Parent-teacher meetings for active child (PA-13).
Widget parentPtmRouteBuilder(BuildContext context, GoRouterState state) {
  // Gated OFF until the PTM backend ships (CORE-1/PAR-4): mock-only, lost data
  // on restart. Hidden via SchoolBuildScope.
  if (SchoolBuildScope.isRouteHidden(state.uri.path)) {
    return const AccessDeniedScreen();
  }
  return ParentPtmScreen(
    onNotificationsTap: () => context.push(RouteNames.parentNotifications),
  );
}

/// PAR-D2 — consolidated "all my children" family view.
Widget parentFamilyRouteBuilder(BuildContext context, GoRouterState state) {
  return ParentFamilyViewScreen(
    onChildSelected: () => context.go(RouteNames.parentDashboard),
  );
}

/// PAR-D4 — consolidated "what needs my action" inbox for the active child.
Widget parentActionInboxRouteBuilder(BuildContext context, GoRouterState state) {
  return Consumer(
    builder: (context, ref, _) {
      return ParentActionInboxScreen(
        onActionTap: (actionId) =>
            handleParentDashboardNavigation(context, actionId, ref: ref),
        onNotificationsTap: () => context.push(RouteNames.parentNotifications),
      );
    },
  );
}

/// Parent profile screen (PA-09).
Widget parentProfileRouteBuilder(BuildContext context, GoRouterState state) {
  return ParentProfileScreen(
    onNotificationsTap: () => context.push(RouteNames.parentNotifications),
    onLeaveTap: () => context.go(RouteNames.parentLeave),
    onReceiptsTap: () => context.go(RouteNames.parentReceipts),
  );
}

/// Fee payment flow (PA-10).
Widget parentPaymentRouteBuilder(BuildContext context, GoRouterState state) {
  final installmentId = state.uri.queryParameters['installmentId'] ?? 'term_2';

  return ParentPaymentScreen(
    key: ValueKey('payment-$installmentId'),
    installmentId: installmentId,
    onNotificationsTap: () => context.push(RouteNames.parentNotifications),
    onViewReceipt: (receiptId) =>
        handleParentFeesNavigation(context, receiptId: receiptId),
    onBackToFees: () => context.go(RouteNames.parentFees),
  );
}

/// Receipts list (PA-11).
Widget parentReceiptsRouteBuilder(BuildContext context, GoRouterState state) {
  return ParentReceiptsScreen(
    onNotificationsTap: () => context.push(RouteNames.parentNotifications),
    onReceiptTap: (receipt) => context.push(
      RouteNames.parentReceiptDetail(receipt.id),
    ),
  );
}

/// Receipt detail (PA-11).
Widget parentReceiptDetailRouteBuilder(
  BuildContext context,
  GoRouterState state,
) {
  final receiptId = state.pathParameters['receiptId'] ?? '';
  return Consumer(
    builder: (context, ref, _) {
      final pdfService = ParentReceiptPdfService();
      Future<void> exportReceiptPdf({
        required bool share,
        required dynamic receipt,
      }) async {
        FinanceReceiptDetail? financeReceipt;
        try {
          financeReceipt =
              await ref.read(financeRepositoryProvider).getReceipt(
                    query: ref.read(repositoryQueryProvider),
                    receiptId: receipt.id,
                  );
        } catch (_) {
          financeReceipt = null;
        }
        final bytes = await pdfService.buildReceiptPdf(
          receipt,
          financeReceipt: financeReceipt,
        );
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            key: QaTestKeys.parentReceiptPdfSuccessSnackbar,
            content: Text(
              share ? 'Receipt PDF ready to share.' : 'Receipt PDF generated.',
            ),
          ),
        );
        try {
          if (share) {
            await pdfService.shareReceipt(
              bytes: bytes,
              receiptNumber: receipt.receiptNumber,
            );
          } else {
            await pdfService.printReceipt(bytes);
          }
        } catch (_) {
          // Native print/share UI is unavailable in Patrol instrumentation.
        }
      }

      return ParentReceiptDetailScreen(
        receiptId: receiptId,
        onNotificationsTap: () => context.push(RouteNames.parentNotifications),
        onDownload: (receipt) {
          unawaited(exportReceiptPdf(share: false, receipt: receipt));
        },
        onShare: (receipt) {
          unawaited(exportReceiptPdf(share: true, receipt: receipt));
        },
      );
    },
  );
}

/// Leave requests (PA-12).
Widget parentLeaveRouteBuilder(BuildContext context, GoRouterState state) {
  return ParentLeaveScreen(
    onNotificationsTap: () => context.push(RouteNames.parentNotifications),
  );
}

Widget parentMessagesRouteBuilder(BuildContext context, GoRouterState state) {
  return ParentMessagesScreen(
    onNotificationsTap: () => context.push(RouteNames.parentNotifications),
    onThreadTap: (thread) =>
        context.push(RouteNames.parentConversation(thread.id)),
    onCommunicationTap: (messageId) =>
        context.push(RouteNames.parentCommunicationMessage(messageId)),
  );
}

Widget parentCommunicationDetailRouteBuilder(
  BuildContext context,
  GoRouterState state,
) {
  final messageId = state.pathParameters['messageId'] ?? '';
  return ParentCommunicationDetailScreen(
    messageId: messageId,
    onNotificationsTap: () => context.push(RouteNames.parentNotifications),
  );
}

Widget parentConversationRouteBuilder(
  BuildContext context,
  GoRouterState state,
) {
  final threadId = state.pathParameters['threadId'] ?? '';
  return ParentConversationScreen(
    threadId: threadId,
    onNotificationsTap: () => context.push(RouteNames.parentNotifications),
  );
}

/// Teacher dashboard wired with router navigation.
Widget teacherDashboardRouteBuilder(BuildContext context, GoRouterState state) {
  return Consumer(
    builder: (context, ref, _) => TeacherDashboardScreen(
      onNavigate: (actionId) =>
          handleTeacherNavigation(context, actionId, ref: ref),
    ),
  );
}

VoidCallback _teacherNotificationsTap(BuildContext context) =>
    () => context.push(RouteNames.parentNotifications);

Widget teacherAttendanceRouteBuilder(
    BuildContext context, GoRouterState state) {
  // TCH-1 — honour the ?class=<label> deep-link from a today-period tap by
  // pre-selecting that class in the roster.
  final preselect = state.uri.queryParameters['class'];
  return TeacherAttendanceScreen(
    onNotificationsTap: _teacherNotificationsTap(context),
    preselectClassLabel:
        (preselect != null && preselect.isNotEmpty) ? preselect : null,
  );
}

/// TCH-9 — the teacher's OWN staff attendance history (read-only).
Widget teacherMyAttendanceRouteBuilder(
    BuildContext context, GoRouterState state) {
  return TeacherMyAttendanceScreen(
    onNotificationsTap: _teacherNotificationsTap(context),
  );
}

Widget teacherTimetableRouteBuilder(BuildContext context, GoRouterState state) {
  return TeacherTimetableScreen(
    onNotificationsTap: _teacherNotificationsTap(context),
  );
}

Widget teacherHomeworkRouteBuilder(BuildContext context, GoRouterState state) {
  // TCH-6 — honour the ?filter=pending deep-link from the "HW to review" task.
  final pendingOnly = state.uri.queryParameters['filter'] == 'pending';
  return TeacherHomeworkScreen(
    onNotificationsTap: _teacherNotificationsTap(context),
    initialPendingOnly: pendingOnly,
  );
}

Widget teacherExamsRouteBuilder(BuildContext context, GoRouterState state) {
  return TeacherExamsScreen(
    onNotificationsTap: _teacherNotificationsTap(context),
  );
}

Widget teacherMessagesRouteBuilder(BuildContext context, GoRouterState state) {
  return TeacherMessagesScreen(
    onNotificationsTap: _teacherNotificationsTap(context),
    onThreadTap: (thread) =>
        context.push(RouteNames.teacherConversation(thread.id)),
  );
}

Widget teacherConversationRouteBuilder(
  BuildContext context,
  GoRouterState state,
) {
  final threadId = state.pathParameters['threadId'] ?? '';
  return TeacherConversationScreen(
    threadId: threadId,
    onNotificationsTap: _teacherNotificationsTap(context),
  );
}

Widget teacherLeaveRouteBuilder(BuildContext context, GoRouterState state) {
  return TeacherLeaveScreen(
    onNotificationsTap: _teacherNotificationsTap(context),
  );
}

/// Student dashboard wired with router navigation.
Widget studentDashboardRouteBuilder(BuildContext context, GoRouterState state) {
  return Consumer(
    builder: (context, ref, _) => StudentDashboardScreen(
      onNavigate: (actionId) =>
          handleStudentNavigation(context, actionId, ref: ref),
    ),
  );
}

VoidCallback _studentNotificationsTap(BuildContext context) =>
    () => context.push(RouteNames.parentNotifications);

Widget studentAttendanceRouteBuilder(
    BuildContext context, GoRouterState state) {
  return StudentAttendanceScreen(
    onNotificationsTap: _studentNotificationsTap(context),
  );
}

Widget studentTimetableRouteBuilder(BuildContext context, GoRouterState state) {
  return StudentTimetableScreen(
    onNotificationsTap: _studentNotificationsTap(context),
  );
}

Widget studentHomeworkRouteBuilder(BuildContext context, GoRouterState state) {
  return StudentHomeworkScreen(
    onNotificationsTap: _studentNotificationsTap(context),
  );
}

Widget studentExamsRouteBuilder(BuildContext context, GoRouterState state) {
  return StudentExamsScreen(
    onNotificationsTap: _studentNotificationsTap(context),
  );
}

Widget studentReportCardRouteBuilder(
    BuildContext context, GoRouterState state) {
  return StudentReportCardScreen(
    onNotificationsTap: _studentNotificationsTap(context),
  );
}

Widget studentProgressRouteBuilder(BuildContext context, GoRouterState state) {
  return Consumer(
    builder: (context, ref, _) => StudentProgressScreen(
      onNotificationsTap: _studentNotificationsTap(context),
      onAiTap: () => handleStudentNavigation(context, 'ai_assistant', ref: ref),
    ),
  );
}

Widget studentNoticesRouteBuilder(BuildContext context, GoRouterState state) {
  return StudentNoticesScreen(
    onNotificationsTap: _studentNotificationsTap(context),
  );
}

Widget studentProfileRouteBuilder(BuildContext context, GoRouterState state) {
  return StudentProfileScreen(
    onNotificationsTap: _studentNotificationsTap(context),
  );
}
