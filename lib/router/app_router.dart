import 'dart:async';

// PRC-A Batch 2 — request desk / gate pass / complaints / student health.
import '../features/certificate_desk/certificate_requests_screen.dart';
import '../features/complaints/complaints_screen.dart';
import '../features/gate_pass/gate_passes_screen.dart';
import '../features/student_health/infirmary/student_health_infirmary_screen.dart';

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
import '../features/staff_attendance/device/face_embedder.dart';
import '../features/staff_attendance/device/mlkit_face_capture.dart';
import '../features/staff_attendance/face_enrollment_screen.dart';
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
      // Attendance auth device layer (Slice 3). Pushed both from non-widget
      // code (MlkitFaceCaptureSource, via goRouterProvider.push — see
      // lib/app/app.dart's SyncBanner for the same pattern) and directly from
      // FaceEnrollmentScreen's own onPressed via context.push.
      GoRoute(
        path: RouteNames.staffFaceCapture,
        name: 'staffFaceCapture',
        builder: (context, state) {
          final extra = state.extra;
          return FaceCaptureScreen(
            embedder: extra is FaceEmbedder ? extra : null,
          );
        },
      ),
      GoRoute(
        path: RouteNames.staffFaceEnrollment,
        name: 'staffFaceEnrollment',
        builder: (context, state) => const FaceEnrollmentScreen(),
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
      // F-128 — teacher-scoped notifications inbox. Same role-neutral
      // NotificationsScreen, under a teacher-owned path so the teacher bell no
      // longer routes into the parent persona's route.
      GoRoute(
        path: RouteNames.teacherNotifications,
        name: 'teacherNotifications',
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
            builder: (context, state) => parentTimetableRouteBuilder(context, state),
          ),
          GoRoute(
            path: RouteNames.parentHomework,
            name: 'parentHomework',
            builder: (context, state) => parentHomeworkRouteBuilder(context, state),
          ),
          GoRoute(
            path: RouteNames.parentExams,
            name: 'parentExams',
            builder: (context, state) => parentExamsRouteBuilder(context, state),
          ),
          GoRoute(
            path: RouteNames.parentNotices,
            name: 'parentNotices',
            builder: (context, state) => parentNoticesRouteBuilder(context, state),
          ),
          GoRoute(
            path: RouteNames.parentEvents,
            name: 'parentEvents',
            builder: (context, state) => parentEventsRouteBuilder(context, state),
          ),
          GoRoute(
            path: RouteNames.parentTransport,
            name: 'parentTransport',
            builder: (context, state) => parentTransportRouteBuilder(context, state),
          ),
          GoRoute(
            path: RouteNames.parentPtm,
            name: 'parentPtm',
            builder: (context, state) => parentPtmRouteBuilder(context, state),
          ),
          GoRoute(
            path: RouteNames.parentFamily,
            name: 'parentFamily',
            builder: (context, state) => parentFamilyRouteBuilder(context, state),
          ),
          GoRoute(
            path: RouteNames.parentActionInbox,
            name: 'parentActionInbox',
            builder: (context, state) => parentActionInboxRouteBuilder(context, state),
          ),
          GoRoute(
            path: RouteNames.parentProfile,
            name: 'parentProfile',
            builder: (context, state) => parentProfileRouteBuilder(context, state),
          ),
          GoRoute(
            path: RouteNames.parentExperience,
            name: 'parentExperience',
            builder: (context, state) => parentExperienceHubRouteBuilder(context, state),
          ),
          GoRoute(
            path: RouteNames.parentAcademicReport,
            name: 'parentAcademicReport',
            builder: (context, state) => parentAcademicReportRouteBuilder(context, state),
          ),
          GoRoute(
            path: RouteNames.parentInsights,
            name: 'parentInsights',
            builder: (context, state) => parentInsightsRouteBuilder(context, state),
          ),
          GoRoute(
            path: RouteNames.parentPayment,
            name: 'parentPayment',
            builder: (context, state) => parentPaymentRouteBuilder(context, state),
          ),
          GoRoute(
            path: RouteNames.parentLeave,
            name: 'parentLeave',
            builder: (context, state) => parentLeaveRouteBuilder(context, state),
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
                builder: (context, state) => parentCommunicationDetailRouteBuilder(context, state),
              ),
              GoRoute(
                path: ':threadId',
                name: 'parentConversation',
                builder: (context, state) => parentConversationRouteBuilder(context, state),
              ),
            ],
          ),
          GoRoute(
            path: RouteNames.parentReceipts,
            name: 'parentReceipts',
            builder: (context, state) => parentReceiptsRouteBuilder(context, state),
            routes: [
              GoRoute(
                path: ':receiptId',
                name: 'parentReceiptDetail',
                builder: (context, state) => parentReceiptDetailRouteBuilder(context, state),
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
            builder: (context, state) => const TeacherClassTeacherDashboardScreen(),
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
            builder: (context, state) => teacherMyAttendanceRouteBuilder(context, state),
          ),
          GoRoute(
            path: RouteNames.teacherTimetable,
            name: 'teacherTimetable',
            builder: (context, state) => teacherTimetableRouteBuilder(context, state),
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
            builder: (context, state) => const TeacherHomeworkCreateScreen(),
          ),
          GoRoute(
            path: RouteNames.teacherHomeworkHistory,
            name: 'teacherHomeworkHistory',
            builder: (context, state) => const TeacherHomeworkHistoryScreen(),
          ),
          GoRoute(
            path: RouteNames.teacherExams,
            name: 'teacherExams',
            builder: (context, state) => teacherExamsRouteBuilder(context, state),
          ),
          GoRoute(
            path: RouteNames.teacherParentCommunication,
            name: 'teacherParentCommunication',
            builder: (context, state) => const TeacherParentCommunicationScreen(),
          ),
          GoRoute(
            path: '${RouteNames.teacher}/student-risk/:sisStudentId',
            name: 'teacherStudentRisk',
            builder: (context, state) => TeacherStudentRiskScreen(
              sisStudentId: state.pathParameters['sisStudentId'] ?? '',
            ),
          ),
          GoRoute(
            path: RouteNames.teacherLeave,
            name: 'teacherLeave',
            builder: (context, state) => teacherLeaveRouteBuilder(context, state),
          ),
          GoRoute(
            path: RouteNames.teacherSettings,
            name: 'teacherSettings',
            builder: (context, state) => const TeacherSettingsScreen(),
          ),
          GoRoute(
            path: RouteNames.teacherProfile,
            name: 'teacherProfile',
            builder: (context, state) => const TeacherProfileScreen(),
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
                builder: (context, state) => teacherConversationRouteBuilder(context, state),
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
            builder: (context, state) => const UnifiedOnboardingFlowScreen(),
          ),
          GoRoute(
            path: RouteNames.studentOnboarding,
            name: 'studentOnboarding',
            builder: (context, state) => const StudentOnboardingScreen(),
          ),
          GoRoute(
            path: RouteNames.backupRestore,
            name: 'backupRestore',
            builder: (context, state) => const BackupRestoreScreen(),
          ),
          GoRoute(
            path: RouteNames.planEntitlements,
            name: 'planEntitlements',
            builder: (context, state) => const PlanEntitlementsScreen(),
          ),
          GoRoute(
            path: RouteNames.planAssignment,
            name: 'planAssignment',
            builder: (context, state) => const OrganizationPlanAssignmentScreen(),
          ),
          GoRoute(
            path: RouteNames.copilot,
            name: 'copilot',
            builder: (context, state) => copilotRouteBuilder(context, state),
          ),
          GoRoute(
            path: RouteNames.education,
            name: 'education',
            builder: (context, state) => educationRouteBuilder(context, state),
          ),
          GoRoute(
            path: RouteNames.intelligence,
            name: 'intelligence',
            builder: (context, state) => intelligenceRouteBuilder(context, state),
          ),
          GoRoute(
            path: RouteNames.aiPredictions,
            name: 'aiPredictions',
            builder: (context, state) => const PredictionsScreen(),
          ),
          GoRoute(
            path: RouteNames.studentSuccessIntelligence,
            name: 'studentSuccessIntelligence',
            builder: (context, state) => studentSuccessIntelligenceRouteBuilder(context, state),
          ),
          GoRoute(
            path: RouteNames.examIntelligence,
            name: 'examIntelligence',
            builder: (context, state) => examIntelligenceRouteBuilder(context, state),
          ),
          GoRoute(
            path: RouteNames.teacherEffectiveness,
            name: 'teacherEffectiveness',
            builder: (context, state) => teacherEffectivenessRouteBuilder(context, state),
          ),
          GoRoute(
            path: RouteNames.homeworkIntelligence,
            name: 'homeworkIntelligence',
            builder: (context, state) => homeworkIntelligenceRouteBuilder(context, state),
          ),
          GoRoute(
            path: '${RouteNames.student360}/:studentId',
            name: 'student360',
            builder: (context, state) => student360RouteBuilder(context, state),
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
            builder: (context, state) => inventoryDistributionRouteBuilder(context, state),
          ),
          GoRoute(
            path: RouteNames.inventoryReplacements,
            name: 'inventoryReplacements',
            builder: (context, state) => inventoryReplacementsRouteBuilder(context, state),
          ),
          GoRoute(
            path: '${RouteNames.employee360}/:employeeId',
            name: 'employee360',
            builder: (context, state) => employee360RouteBuilder(context, state),
          ),
          GoRoute(
            path: RouteNames.operationsHub,
            name: 'operationsHub',
            builder: (context, state) => operationsHubRouteBuilder(context, state),
          ),
          GoRoute(
            path: RouteNames.resourceOptimization,
            name: 'resourceOptimization',
            builder: (context, state) => resourceOptimizationRouteBuilder(context, state),
          ),
          GoRoute(
            path: RouteNames.aiContent,
            name: 'aiContent',
            builder: (context, state) => aiContentRouteBuilder(context, state),
          ),
          GoRoute(
            path: RouteNames.organizationIntelligence,
            name: 'organizationIntelligence',
            builder: (context, state) => organizationIntelligenceRouteBuilder(context, state),
          ),
          GoRoute(
            path: RouteNames.branches,
            name: 'branches',
            builder: (context, state) => branchRouteBuilder(context, state),
          ),
          GoRoute(
            path: RouteNames.franchise,
            name: 'franchise',
            builder: (context, state) => franchiseRouteBuilder(context, state),
          ),
          GoRoute(
            path: RouteNames.schoolMemories,
            name: 'schoolMemories',
            builder: (context, state) => schoolMemoriesRouteBuilder(context, state),
          ),
          GoRoute(
            path: RouteNames.achievementPromotion,
            name: 'achievementPromotion',
            builder: (context, state) => achievementPromotionRouteBuilder(context, state),
          ),
          GoRoute(
            path: RouteNames.setupWizard,
            name: 'setupWizard',
            builder: (context, state) => setupWizardRouteBuilder(context, state),
          ),
          GoRoute(
            path: RouteNames.dynamicDashboard,
            name: 'dynamicDashboard',
            builder: (context, state) => dynamicDashboardRouteBuilder(context, state),
          ),
          GoRoute(
            path: RouteNames.teacherAssistant,
            name: 'teacherAssistant',
            builder: (context, state) => teacherAssistantRouteBuilder(context, state),
          ),
          GoRoute(
            path: RouteNames.principalCommand,
            name: 'principalCommand',
            builder: (context, state) => principalCommandRouteBuilder(context, state),
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
            builder: (context, state) => subjectsManagementRouteBuilder(context, state),
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
                builder: (context, state) => examReportsRouteBuilder(context, state),
              ),
              GoRoute(
                path: ':examId/marks',
                name: 'examAdministrationMarks',
                builder: (context, state) => examMarksEntryRouteBuilder(context, state),
              ),
            ],
          ),
          GoRoute(
            path: RouteNames.lessonLogs,
            name: 'lessonLogs',
            builder: (context, state) => lessonLogsRouteBuilder(context, state),
          ),
          GoRoute(
            path: RouteNames.timetableAutomation,
            name: 'timetableAutomation',
            builder: (context, state) => timetableAutomationRouteBuilder(context, state),
          ),
          GoRoute(
            path: RouteNames.schoolBranding,
            name: 'schoolBranding',
            builder: (context, state) => schoolBrandingRouteBuilder(context, state),
          ),
          GoRoute(
            path: RouteNames.whatsAppProvider,
            name: 'whatsAppProvider',
            builder: (context, state) => whatsAppProviderRouteBuilder(context, state),
          ),
          GoRoute(
            path: RouteNames.subjectAssignments,
            name: 'subjectAssignments',
            builder: (context, state) => subjectAssignmentsRouteBuilder(context, state),
          ),
          GoRoute(
            path: RouteNames.lessonAnalytics,
            name: 'lessonAnalytics',
            builder: (context, state) => lessonAnalyticsRouteBuilder(context, state),
          ),
          GoRoute(
            path: RouteNames.timetableOptimization,
            name: 'timetableOptimization',
            builder: (context, state) => timetableOptimizationRouteBuilder(context, state),
          ),
          GoRoute(
            path: RouteNames.substituteManager,
            name: 'substituteManager',
            builder: (context, state) => substituteManagerRouteBuilder(context, state),
          ),
          GoRoute(
            path: RouteNames.teacherReassignment,
            name: 'teacherReassignment',
            builder: (context, state) => teacherReassignmentRouteBuilder(context, state),
          ),
          GoRoute(
            path: RouteNames.classTeacherAssignments,
            name: 'classTeacherAssignments',
            builder: (context, state) => classTeacherAssignmentsRouteBuilder(context, state),
          ),
          GoRoute(
            path: RouteNames.communicationDelivery,
            name: 'communicationDelivery',
            builder: (context, state) => communicationDeliveryRouteBuilder(context, state),
          ),
          GoRoute(
            path: RouteNames.communicationBroadcastAdmin,
            name: 'communicationBroadcastAdmin',
            builder: (context, state) => communicationBroadcastAdminRouteBuilder(context, state),
          ),
          GoRoute(
            path: RouteNames.communicationAnalytics,
            name: 'communicationAnalytics',
            builder: (context, state) => communicationAnalyticsRouteBuilder(context, state),
          ),
          GoRoute(
            path: RouteNames.pilotDashboard,
            name: 'pilotDashboard',
            builder: (context, state) => pilotDashboardRouteBuilder(context, state),
          ),
          GoRoute(
            path: RouteNames.parentActivationDashboard,
            name: 'parentActivationDashboard',
            builder: (context, state) => parentActivationDashboardRouteBuilder(context, state),
          ),
          GoRoute(
            path: RouteNames.roomAllocation,
            name: 'roomAllocation',
            builder: (context, state) => roomAllocationRouteBuilder(context, state),
          ),
          GoRoute(
            path: RouteNames.syllabusAutomation,
            name: 'syllabusAutomation',
            builder: (context, state) => syllabusAutomationRouteBuilder(context, state),
          ),
          GoRoute(
            path: RouteNames.academicProgress,
            name: 'academicProgress',
            builder: (context, state) => academicProgressRouteBuilder(context, state),
          ),
          GoRoute(
            path: RouteNames.timetableIntelligence,
            name: 'timetableIntelligence',
            builder: (context, state) => timetableIntelligenceRouteBuilder(context, state),
          ),
          GoRoute(
            path: RouteNames.parentMeetings,
            name: 'parentMeetings',
            builder: (context, state) => parentMeetingsRouteBuilder(context, state),
          ),
          GoRoute(
            path: RouteNames.multiSchoolPortfolio,
            name: 'multiSchoolPortfolio',
            builder: (context, state) => multiSchoolPortfolioRouteBuilder(context, state),
          ),
          GoRoute(
            path: RouteNames.multiSchoolOnboarding,
            name: 'multiSchoolOnboarding',
            builder: (context, state) => multiSchoolOnboardingRouteBuilder(context, state),
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
            builder: (context, state) => organizationBuilderInterviewRouteBuilder(context, state),
          ),
          GoRoute(
            path: RouteNames.organizationBuilderPreview,
            name: 'organizationBuilderPreview',
            builder: (context, state) => organizationBuilderPreviewRouteBuilder(context, state),
          ),
          GoRoute(
            path: RouteNames.organizationBuilderProvisioning,
            name: 'organizationBuilderProvisioning',
            builder: (context, state) => organizationBuilderProvisioningRouteBuilder(context, state),
          ),
          GoRoute(
            path: RouteNames.schoolDiscovery,
            name: 'schoolDiscovery',
            builder: (context, state) => schoolDiscoveryRouteBuilder(context, state),
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
            builder: (context, state) => platformOperationsHubRouteBuilder(context, state),
          ),
          GoRoute(
            path: RouteNames.platformOperationsSecurity,
            name: 'platformOperationsSecurity',
            builder: (context, state) => platformOperationsHubRouteBuilder(context, state),
          ),
          GoRoute(
            path: RouteNames.platformOperationsTenantIsolation,
            name: 'platformOperationsTenantIsolation',
            builder: (context, state) => platformOperationsHubRouteBuilder(context, state),
          ),
          GoRoute(
            path: RouteNames.platformOperationsReadiness,
            name: 'platformOperationsReadiness',
            builder: (context, state) => platformOperationsHubRouteBuilder(context, state),
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
            builder: (context, state) => industryFrameworkRouteBuilder(context, state),
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
            builder: (context, state) => healthcarePatientRouteBuilder(context, state),
          ),
          GoRoute(
            path: RouteNames.healthcareAppointments,
            name: 'healthcareAppointments',
            builder: (context, state) => healthcareAppointmentRouteBuilder(context, state),
          ),
          GoRoute(
            path: RouteNames.healthcarePractitioners,
            name: 'healthcarePractitioners',
            builder: (context, state) => healthcarePractitionerRouteBuilder(context, state),
          ),
          GoRoute(
            path: RouteNames.healthcareIntelligence,
            name: 'healthcareIntelligence',
            builder: (context, state) => healthcareIntelligenceRouteBuilder(context, state),
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
            builder: (context, state) => salonSalonCustomerRouteBuilder(context, state),
          ),
          GoRoute(
            path: RouteNames.salonAppointments,
            name: 'salonAppointments',
            builder: (context, state) => salonSalonAppointmentRouteBuilder(context, state),
          ),
          GoRoute(
            path: RouteNames.salonServices,
            name: 'salonServices',
            builder: (context, state) => salonSalonServiceRouteBuilder(context, state),
          ),
          GoRoute(
            path: RouteNames.salonIntelligence,
            name: 'salonIntelligence',
            builder: (context, state) => salonIntelligenceRouteBuilder(context, state),
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
            builder: (context, state) => restaurantRestaurantTableRouteBuilder(context, state),
          ),
          GoRoute(
            path: RouteNames.restaurantOrders,
            name: 'restaurantOrders',
            builder: (context, state) => restaurantRestaurantOrderRouteBuilder(context, state),
          ),
          GoRoute(
            path: RouteNames.restaurantKitchen,
            name: 'restaurantKitchen',
            builder: (context, state) => restaurantKitchenTicketRouteBuilder(context, state),
          ),
          GoRoute(
            path: RouteNames.restaurantIntelligence,
            name: 'restaurantIntelligence',
            builder: (context, state) => restaurantIntelligenceRouteBuilder(context, state),
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
            builder: (context, state) => accommodationResidentRouteBuilder(context, state),
          ),
          GoRoute(
            path: RouteNames.accommodationOccupancy,
            name: 'accommodationOccupancy',
            builder: (context, state) => accommodationRoomOccupancyRouteBuilder(context, state),
          ),
          GoRoute(
            path: RouteNames.accommodationAllocations,
            name: 'accommodationAllocations',
            builder: (context, state) => accommodationAccommodationAllocationRouteBuilder(context, state),
          ),
          GoRoute(
            path: RouteNames.accommodationIntelligence,
            name: 'accommodationIntelligence',
            builder: (context, state) => accommodationIntelligenceRouteBuilder(context, state),
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
            builder: (context, state) => whiteLabelBrandingRouteBuilder(context, state),
          ),
          GoRoute(
            path: RouteNames.whiteLabelTheme,
            name: 'whiteLabelTheme',
            builder: (context, state) => whiteLabelThemeRouteBuilder(context, state),
          ),
          GoRoute(
            path: RouteNames.whiteLabelLogo,
            name: 'whiteLabelLogo',
            builder: (context, state) => whiteLabelLogoRouteBuilder(context, state),
          ),
          GoRoute(
            path: RouteNames.whiteLabelDeployment,
            name: 'whiteLabelDeployment',
            builder: (context, state) => whiteLabelDeploymentRouteBuilder(context, state),
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
            builder: (context, state) => dynamicWidgetLayoutRouteBuilder(context, state),
          ),
          GoRoute(
            path: RouteNames.dynamicWidgetRuntime,
            name: 'dynamicWidgetRuntime',
            builder: (context, state) => dynamicWidgetRuntimeRouteBuilder(context, state),
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
                builder: (context, state) => admissionsLeadsRouteBuilder(context, state),
                routes: [
                  GoRoute(
                    path: ':leadId',
                    name: 'admissionsLeadDetail',
                    builder: (context, state) => admissionsLeadDetailRouteBuilder(context, state),
                  ),
                ],
              ),
              GoRoute(
                path: 'applications',
                name: 'admissionsApplications',
                builder: (context, state) => admissionsApplicationsRouteBuilder(context, state),
              ),
              GoRoute(
                path: 'enrollment',
                name: 'admissionsEnrollment',
                builder: (context, state) => admissionsEnrollmentRouteBuilder(context, state),
              ),
              GoRoute(
                path: 'documents',
                name: 'admissionsDocuments',
                builder: (context, state) => admissionsDocumentsRouteBuilder(context, state),
              ),
              GoRoute(
                path: 'approval',
                name: 'admissionsApproval',
                builder: (context, state) => admissionsApprovalRouteBuilder(context, state),
              ),
              GoRoute(
                path: 'fee-handoff',
                name: 'admissionsFeeHandoff',
                builder: (context, state) => admissionsFeeHandoffRouteBuilder(context, state),
              ),
              GoRoute(
                path: 'reports',
                name: 'admissionsReports',
                builder: (context, state) => admissionsReportsRouteBuilder(context, state),
              ),
              GoRoute(
                path: 'settings',
                name: 'admissionsSettings',
                builder: (context, state) => admissionsSettingsRouteBuilder(context, state),
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
                builder: (context, state) => financeFeeStructuresRouteBuilder(context, state),
              ),
              GoRoute(
                path: 'student-accounts',
                name: 'financeStudentAccounts',
                builder: (context, state) => financeStudentAccountsRouteBuilder(context, state),
              ),
              GoRoute(
                path: 'fee-assignment',
                name: 'financeFeeAssignment',
                builder: (context, state) => financeFeeAssignmentRouteBuilder(context, state),
              ),
              GoRoute(
                path: 'collections',
                name: 'financeCollections',
                builder: (context, state) => financeCollectionsRouteBuilder(context, state),
                routes: [
                  GoRoute(
                    path: ':collectionId',
                    name: 'financeCollectionDetail',
                    builder: (context, state) => financeCollectionDetailRouteBuilder(context, state),
                  ),
                ],
              ),
              GoRoute(
                path: 'payments/qr',
                name: 'financeQrPayment',
                builder: (context, state) => financeQrPaymentRouteBuilder(context, state),
              ),
              GoRoute(
                path: 'payments/offline',
                name: 'financeOfflinePayments',
                builder: (context, state) => financeOfflinePaymentsRouteBuilder(context, state),
              ),
              GoRoute(
                path: 'defaulters',
                name: 'financeDefaulters',
                builder: (context, state) => financeDefaultersRouteBuilder(context, state),
              ),
              GoRoute(
                path: 'refunds',
                name: 'financeRefunds',
                builder: (context, state) => financeRefundsRouteBuilder(context, state),
              ),
              GoRoute(
                path: 'discounts',
                name: 'financeDiscounts',
                builder: (context, state) => financeDiscountsRouteBuilder(context, state),
              ),
              GoRoute(
                path: 'reports',
                name: 'financeReports',
                builder: (context, state) => financeReportsRouteBuilder(context, state),
              ),
              GoRoute(
                path: 'reconciliation',
                name: 'financeReconciliation',
                builder: (context, state) => financeReconciliationRouteBuilder(context, state),
              ),
              GoRoute(
                path: 'settings',
                name: 'financeSettings',
                builder: (context, state) => financeSettingsRouteBuilder(context, state),
              ),
              GoRoute(
                path: 'intelligence',
                name: 'financeIntelligence',
                builder: (context, state) => financeIntelligenceRouteBuilder(context, state),
              ),
              GoRoute(
                path: 'executive',
                name: 'financeExecutiveDashboard',
                builder: (context, state) => financeExecutiveDashboardRouteBuilder(context, state),
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
                builder: (context, state) => sisStudentsRouteBuilder(context, state),
                routes: [
                  GoRoute(
                    path: ':studentId',
                    name: 'sisStudentDetail',
                    builder: (context, state) => sisStudentDetailRouteBuilder(context, state),
                  ),
                ],
              ),
              GoRoute(
                path: 'academic-assignment',
                name: 'sisAcademicAssignment',
                builder: (context, state) => sisAcademicAssignmentRouteBuilder(context, state),
              ),
              GoRoute(
                path: 'admissions-conversion',
                name: 'sisAdmissionsConversion',
                builder: (context, state) => sisAdmissionsConversionRouteBuilder(context, state),
              ),
              GoRoute(
                path: 'promotion',
                name: 'sisPromotion',
                builder: (context, state) => sisPromotionRouteBuilder(context, state),
              ),
              GoRoute(
                path: 'reshuffle',
                name: 'sisReshuffle',
                builder: (context, state) => sisReshuffleRouteBuilder(context, state),
              ),
              GoRoute(
                path: 'section-balance',
                name: 'sisSectionBalance',
                builder: (context, state) => sisSectionBalanceRouteBuilder(context, state),
              ),
              GoRoute(
                path: 'continuity',
                name: 'sisContinuity',
                builder: (context, state) => sisContinuityRouteBuilder(context, state),
              ),
              GoRoute(
                path: 'transfers',
                name: 'sisTransfers',
                builder: (context, state) => sisTransfersRouteBuilder(context, state),
              ),
              GoRoute(
                path: 'onboarding',
                name: 'sisOnboarding',
                builder: (context, state) => sisOnboardingRouteBuilder(context, state),
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
                builder: (context, state) => hrEmployeesRouteBuilder(context, state),
                routes: [
                  GoRoute(
                    path: ':employeeId',
                    name: 'hrEmployeeDetail',
                    builder: (context, state) => hrEmployeeDetailRouteBuilder(context, state),
                  ),
                ],
              ),
              GoRoute(
                path: 'attendance',
                name: 'hrAttendance',
                builder: (context, state) => hrAttendanceRouteBuilder(context, state),
                routes: [
                  // PRA-P0-15 — audited manual-attendance fallback.
                  GoRoute(
                    path: 'manual-request',
                    name: 'hrStaffManualRequest',
                    builder: (context, state) => hrStaffManualRequestRouteBuilder(context, state),
                  ),
                  GoRoute(
                    path: 'requests',
                    name: 'hrStaffManualRequestQueue',
                    builder: (context, state) => hrStaffManualRequestQueueRouteBuilder(context, state),
                  ),
                ],
              ),
              GoRoute(
                path: 'leave',
                name: 'hrLeave',
                builder: (context, state) => hrLeaveRouteBuilder(context, state),
              ),
              GoRoute(
                path: 'payroll',
                name: 'hrPayroll',
                builder: (context, state) => hrPayrollRouteBuilder(context, state),
              ),
              GoRoute(
                path: 'recruitment',
                name: 'hrRecruitment',
                builder: (context, state) => hrRecruitmentRouteBuilder(context, state),
              ),
              GoRoute(
                path: 'performance',
                name: 'hrPerformance',
                builder: (context, state) => hrPerformanceRouteBuilder(context, state),
              ),
              GoRoute(
                path: 'reports',
                name: 'hrReports',
                builder: (context, state) => hrReportsRouteBuilder(context, state),
              ),
              GoRoute(
                path: 'settings',
                name: 'hrSettings',
                builder: (context, state) => hrSettingsRouteBuilder(context, state),
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
                builder: (context, state) => managementAnalyticsRouteBuilder(context, state),
              ),
              GoRoute(
                path: 'admissions',
                name: 'managementAdmissions',
                builder: (context, state) => managementAdmissionsRouteBuilder(context, state),
              ),
              GoRoute(
                path: 'finance',
                name: 'managementFinance',
                builder: (context, state) => managementFinanceRouteBuilder(context, state),
              ),
              GoRoute(
                path: 'academics',
                name: 'managementAcademics',
                builder: (context, state) => managementAcademicsRouteBuilder(context, state),
              ),
              GoRoute(
                path: 'timetable',
                name: 'managementTimetable',
                builder: (context, state) => managementTimetableRouteBuilder(context, state),
              ),
              GoRoute(
                path: 'intelligence',
                name: 'managementIntelligence',
                builder: (context, state) => managementIntelligenceRouteBuilder(context, state),
              ),
              GoRoute(
                path: 'performance',
                name: 'managementPerformance',
                builder: (context, state) => managementPerformanceRouteBuilder(context, state),
              ),
              GoRoute(
                path: 'tasks',
                name: 'managementTasks',
                builder: (context, state) => managementTasksRouteBuilder(context, state),
              ),
              GoRoute(
                path: 'approvals',
                name: 'managementApprovals',
                builder: (context, state) => managementApprovalsRouteBuilder(context, state),
              ),
              GoRoute(
                path: 'attendance-corrections',
                name: 'managementAttendanceCorrections',
                builder: (context, state) => managementAttendanceCorrectionsRouteBuilder(
                  context,
                  state,
                ),
              ),
              GoRoute(
                path: 'office-attendance',
                name: 'managementOfficeAttendance',
                builder: (context, state) => managementOfficeAttendanceRouteBuilder(
                  context,
                  state,
                ),
              ),
              GoRoute(
                path: 'workflow-automation',
                name: 'managementWorkflowAutomation',
                builder: (context, state) => managementWorkflowAutomationRouteBuilder(context, state),
              ),
              GoRoute(
                path: 'settings',
                name: 'managementSettings',
                builder: (context, state) => managementSettingsRouteBuilder(context, state),
              ),
              GoRoute(
                path: 'school-calendar',
                name: 'managementSchoolCalendar',
                builder: (context, state) => managementSchoolCalendarRouteBuilder(context, state),
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
                builder: (context, state) => transportRoutesRouteBuilder(context, state),
              ),
              GoRoute(
                path: 'vehicles',
                name: 'transportVehicles',
                builder: (context, state) => transportVehiclesRouteBuilder(context, state),
              ),
              GoRoute(
                path: 'drivers',
                name: 'transportDrivers',
                builder: (context, state) => transportDriversRouteBuilder(context, state),
              ),
              GoRoute(
                path: 'allocation',
                name: 'transportAllocation',
                builder: (context, state) => transportAllocationRouteBuilder(context, state),
              ),
              GoRoute(
                path: 'attendance',
                name: 'transportAttendance',
                builder: (context, state) => transportAttendanceRouteBuilder(context, state),
              ),
              GoRoute(
                path: 'tracking',
                name: 'transportTracking',
                builder: (context, state) => transportTrackingRouteBuilder(context, state),
              ),
              GoRoute(
                path: 'reports',
                name: 'transportReports',
                builder: (context, state) => transportReportsRouteBuilder(context, state),
              ),
              GoRoute(
                path: 'settings',
                name: 'transportSettings',
                builder: (context, state) => transportSettingsRouteBuilder(context, state),
              ),
            ],
          ),
          // ─── PRC-A Batch 2 ────────────────────────────────────────────────
          // Single-screen desks — no sub-routes: the complaint detail and the
          // student health record are pushed from inside their own screens.
          // Route-level RBAC is centralized in kErpRouteViewPermissions
          // (route_guards.dart), which the admin shell's ErpRouteGuard applies —
          // NOT per-GoRoute.
          GoRoute(
            path: RouteNames.certificateRequests,
            name: 'certificateRequests',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: CertificateRequestsScreen(),
            ),
          ),
          GoRoute(
            path: RouteNames.gatePasses,
            name: 'gatePasses',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: GatePassesScreen(),
            ),
          ),
          GoRoute(
            path: RouteNames.complaints,
            name: 'complaints',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: ComplaintsScreen(),
            ),
          ),
          GoRoute(
            path: RouteNames.studentHealth,
            name: 'studentHealth',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: StudentHealthInfirmaryScreen(),
            ),
          ),
          // ─── end PRC-A Batch 2 ────────────────────────────────────────────
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
                builder: (context, state) => hostelStudentsRouteBuilder(context, state),
              ),
              GoRoute(
                path: 'rooms',
                name: 'hostelRooms',
                builder: (context, state) => hostelRoomsRouteBuilder(context, state),
              ),
              GoRoute(
                path: 'attendance',
                name: 'hostelAttendance',
                builder: (context, state) => hostelAttendanceRouteBuilder(context, state),
              ),
              GoRoute(
                path: 'leave',
                name: 'hostelLeave',
                builder: (context, state) => hostelLeaveRouteBuilder(context, state),
              ),
              GoRoute(
                path: 'mess',
                name: 'hostelMess',
                builder: (context, state) => hostelMessRouteBuilder(context, state),
              ),
              GoRoute(
                path: 'visitors',
                name: 'hostelVisitors',
                builder: (context, state) => hostelVisitorsRouteBuilder(context, state),
              ),
              GoRoute(
                path: 'reports',
                name: 'hostelReports',
                builder: (context, state) => hostelReportsRouteBuilder(context, state),
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
                builder: (context, state) => libraryCatalogRouteBuilder(context, state),
              ),
              GoRoute(
                path: 'issues',
                name: 'libraryIssues',
                builder: (context, state) => libraryIssuesRouteBuilder(context, state),
              ),
              GoRoute(
                path: 'returns',
                name: 'libraryReturns',
                builder: (context, state) => libraryReturnsRouteBuilder(context, state),
              ),
              GoRoute(
                path: 'members',
                name: 'libraryMembers',
                builder: (context, state) => libraryMembersRouteBuilder(context, state),
              ),
              GoRoute(
                path: 'fines',
                name: 'libraryFines',
                builder: (context, state) => libraryFinesRouteBuilder(context, state),
              ),
              GoRoute(
                path: 'resources',
                name: 'libraryResources',
                builder: (context, state) => libraryResourcesRouteBuilder(context, state),
              ),
              GoRoute(
                path: 'reports',
                name: 'libraryReports',
                builder: (context, state) => libraryReportsRouteBuilder(context, state),
              ),
              GoRoute(
                path: 'overdue',
                name: 'libraryOverdue',
                builder: (context, state) => libraryOverdueRouteBuilder(context, state),
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
                builder: (context, state) => inventoryAssetsRouteBuilder(context, state),
              ),
              GoRoute(
                path: 'categories',
                name: 'inventoryCategories',
                builder: (context, state) => inventoryCategoriesRouteBuilder(context, state),
              ),
              GoRoute(
                path: 'allocation',
                name: 'inventoryAllocation',
                builder: (context, state) => inventoryAllocationRouteBuilder(context, state),
              ),
              GoRoute(
                path: 'maintenance',
                name: 'inventoryMaintenance',
                builder: (context, state) => inventoryMaintenanceRouteBuilder(context, state),
              ),
              GoRoute(
                path: 'procurement',
                name: 'inventoryProcurement',
                builder: (context, state) => inventoryProcurementRouteBuilder(context, state),
              ),
              GoRoute(
                path: 'vendors',
                name: 'inventoryVendors',
                builder: (context, state) => inventoryVendorsRouteBuilder(context, state),
              ),
              GoRoute(
                path: 'stock',
                name: 'inventoryStock',
                builder: (context, state) => inventoryStockRouteBuilder(context, state),
              ),
              GoRoute(
                path: 'stock-approvals',
                name: 'inventoryStockApprovals',
                builder: (context, state) => inventoryStockApprovalsRouteBuilder(context, state),
              ),
              GoRoute(
                path: 'reports',
                name: 'inventoryReports',
                builder: (context, state) => inventoryReportsRouteBuilder(context, state),
              ),
              GoRoute(
                path: 'copilot',
                name: 'inventoryCopilot',
                builder: (context, state) => inventoryCopilotRouteBuilder(context, state),
              ),
              GoRoute(
                path: 'lifecycle',
                name: 'inventoryLifecycle',
                builder: (context, state) => inventoryLifecycleRouteBuilder(context, state),
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
                builder: (context, state) => alumniRegistryRouteBuilder(context, state),
              ),
              GoRoute(
                path: 'profile/:alumniId',
                name: 'alumniProfile',
                builder: (context, state) => alumniProfileRouteBuilder(context, state),
              ),
              GoRoute(
                path: 'events',
                name: 'alumniEvents',
                builder: (context, state) => alumniEventsRouteBuilder(context, state),
              ),
              GoRoute(
                path: 'donations',
                name: 'alumniDonations',
                builder: (context, state) => alumniDonationsRouteBuilder(context, state),
              ),
              GoRoute(
                path: 'campaigns',
                name: 'alumniCampaigns',
                builder: (context, state) => alumniCampaignsRouteBuilder(context, state),
              ),
              GoRoute(
                path: 'mentorship',
                name: 'alumniMentorship',
                builder: (context, state) => alumniMentorshipRouteBuilder(context, state),
              ),
              GoRoute(
                path: 'reports',
                name: 'alumniReports',
                builder: (context, state) => alumniReportsRouteBuilder(context, state),
              ),
              GoRoute(
                path: 'settings',
                name: 'alumniSettings',
                builder: (context, state) => alumniSettingsRouteBuilder(context, state),
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
                builder: (context, state) => controlCenterIntelligenceRouteBuilder(context, state),
              ),
              GoRoute(
                path: 'schools',
                name: 'controlCenterSchools',
                builder: (context, state) => controlCenterSchoolsRouteBuilder(context, state),
              ),
              GoRoute(
                path: 'subscriptions',
                name: 'controlCenterSubscriptions',
                builder: (context, state) => controlCenterSubscriptionsRouteBuilder(context, state),
              ),
              GoRoute(
                path: 'billing',
                name: 'controlCenterBilling',
                builder: (context, state) => controlCenterBillingRouteBuilder(context, state),
              ),
              GoRoute(
                path: 'crm',
                name: 'controlCenterCrm',
                builder: (context, state) => controlCenterCrmRouteBuilder(context, state),
              ),
              GoRoute(
                path: 'support',
                name: 'controlCenterSupport',
                builder: (context, state) => controlCenterSupportRouteBuilder(context, state),
              ),
              GoRoute(
                path: 'success',
                name: 'controlCenterSuccess',
                builder: (context, state) => controlCenterSuccessRouteBuilder(context, state),
              ),
              GoRoute(
                path: 'white-label',
                name: 'controlCenterWhiteLabel',
                builder: (context, state) => controlCenterWhiteLabelRouteBuilder(context, state),
              ),
              GoRoute(
                path: 'analytics',
                name: 'controlCenterAnalytics',
                builder: (context, state) => controlCenterAnalyticsRouteBuilder(context, state),
              ),
              GoRoute(
                path: 'monitoring',
                name: 'controlCenterMonitoring',
                builder: (context, state) => controlCenterMonitoringRouteBuilder(context, state),
              ),
              GoRoute(
                path: 'roles',
                name: 'controlCenterRoles',
                builder: (context, state) => controlCenterRolesRouteBuilder(context, state),
              ),
              GoRoute(
                path: 'settings',
                name: 'controlCenterSettings',
                builder: (context, state) => controlCenterSettingsRouteBuilder(context, state),
              ),
              GoRoute(
                path: 'providers',
                name: 'controlCenterProviders',
                builder: (context, state) => controlCenterProvidersRouteBuilder(context, state),
              ),
              GoRoute(
                path: 'features',
                name: 'controlCenterFeatures',
                builder: (context, state) => controlCenterFeaturesRouteBuilder(context, state),
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
                builder: (context, state) => directorSchoolsRouteBuilder(context, state),
              ),
              // DIR-D1 — audited, read-only per-school drill-down.
              GoRoute(
                path: 'schools/:id',
                name: 'directorSchoolSnapshot',
                builder: (context, state) => directorSchoolSnapshotRouteBuilder(context, state),
              ),
              GoRoute(
                path: 'portfolio',
                name: 'directorPortfolio',
                builder: (context, state) => directorPortfolioRouteBuilder(context, state),
              ),
              GoRoute(
                path: 'revenue',
                name: 'directorRevenue',
                builder: (context, state) => directorRevenueRouteBuilder(context, state),
              ),
              GoRoute(
                path: 'growth',
                name: 'directorGrowth',
                builder: (context, state) => directorGrowthRouteBuilder(context, state),
              ),
              GoRoute(
                path: 'marketing',
                name: 'directorMarketing',
                builder: (context, state) => directorMarketingRouteBuilder(context, state),
              ),
              GoRoute(
                path: 'admissions',
                name: 'directorAdmissions',
                builder: (context, state) => directorAdmissionsRouteBuilder(context, state),
              ),
              GoRoute(
                path: 'compliance',
                name: 'directorCompliance',
                builder: (context, state) => directorComplianceRouteBuilder(context, state),
              ),
              GoRoute(
                path: 'reports',
                name: 'directorReports',
                builder: (context, state) => directorReportsRouteBuilder(context, state),
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
            builder: (context, state) => studentAttendanceRouteBuilder(context, state),
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
            builder: (context, state) => studentReportCardRouteBuilder(context, state),
          ),
          GoRoute(
            path: RouteNames.studentProgress,
            name: 'studentProgress',
            builder: (context, state) => studentProgressRouteBuilder(context, state),
          ),
          GoRoute(
            path: RouteNames.studentNotices,
            name: 'studentNotices',
            builder: (context, state) => studentNoticesRouteBuilder(context, state),
          ),
          GoRoute(
            path: RouteNames.studentProfile,
            name: 'studentProfile',
            builder: (context, state) => studentProfileRouteBuilder(context, state),
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

/// The standalone staff Face ID capture/enrolment routes (audit R3): they are
/// pushed from the HR attendance screen (admin ERP shell) but registered as
/// top-level routes, so they must carry the same wall themselves — otherwise a
/// parent/student could deep-link into staff-only camera UI by URL. Server
/// RBAC already denies the writes; this closes the client-side exposure.
bool _isStaffAttendanceDeviceRoute(String location) {
  return location == RouteNames.staffFaceCapture ||
      location == RouteNames.staffFaceEnrollment;
}

bool _isProtectedRoute(String location) {
  return location.startsWith('/parent') ||
      location.startsWith('/teacher') ||
      location.startsWith('/student') ||
      _isAiAssistantRoute(location) ||
      _isSharedSettingsRoute(location) ||
      _isStaffAttendanceDeviceRoute(location) ||
      isAdminErpRoute(location);
}

bool _canAccessRoute(AuthState auth, String location) {
  if (_isAiAssistantRoute(location) || _isSharedSettingsRoute(location)) {
    return auth.isAuthenticated;
  }
  // Same wall as the HR attendance screen these are pushed from.
  if (_isStaffAttendanceDeviceRoute(location)) {
    return canAccessAdminErpShell(auth);
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

// F-128 — the teacher bell opens the teacher-scoped notifications inbox.
VoidCallback _teacherNotificationsTap(BuildContext context) =>
    () => context.push(RouteNames.teacherNotifications);

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
