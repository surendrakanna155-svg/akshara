import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/auth/auth_models.dart';
import '../features/auth/qa_login_persona.dart';
import '../features/auth/login_screen.dart';
import '../features/auth/otp_verification_screen.dart';
import '../features/auth/qa_login_screen.dart';
import '../features/auth/splash_screen.dart';
import '../features/auth/staff/staff_login_screen.dart';
import '../features/auth/staff/staff_otp_screen.dart';
import '../features/auth/staff/staff_login_provider.dart';
import '../features/notifications/notifications_screen.dart';
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
import '../features/parent/messages/parent_messages_screen.dart';
import '../features/parent/shell/parent_shell.dart';
import '../features/parent/timetable/parent_timetable_screen.dart';
import '../features/student/attendance/student_attendance_screen.dart';
import '../features/student/dashboard/student_dashboard_screen.dart';
import '../features/student/exams/student_exams_screen.dart';
import '../features/student/homework/student_homework_screen.dart';
import '../features/student/notices/student_notices_screen.dart';
import '../features/student/profile/student_profile_screen.dart';
import '../features/student/shell/student_shell.dart';
import '../features/student/timetable/student_timetable_screen.dart';
import '../features/teacher/attendance/teacher_attendance_screen.dart';
import '../features/teacher/dashboard/teacher_dashboard_screen.dart';
import '../features/teacher/exams/teacher_exams_screen.dart';
import '../features/teacher/homework/teacher_homework_screen.dart';
import '../features/teacher/leave/teacher_leave_screen.dart';
import '../features/teacher/messages/teacher_conversation_screen.dart';
import '../features/teacher/messages/teacher_messages_screen.dart';
import '../features/teacher/shell/teacher_shell.dart';
import '../features/teacher/timetable/teacher_timetable_screen.dart';
import '../features/copilot/dock/copilot_dock_host.dart';
import '../features/admin/admin_shell.dart';
import '../core/repositories/repository_providers.dart';
import '../core/tenant/tenant_provider.dart';
import '../core/testing/qa_test_keys.dart';
import 'admin_navigation.dart';
import 'route_guards.dart';
import 'admissions_navigation.dart';
import 'finance_navigation.dart';
import 'copilot_navigation.dart';
import 'education_navigation.dart';
import 'intelligence_navigation.dart';
import 'phase4_navigation.dart';
import 'phase5_navigation.dart';
import 'evolution_navigation.dart';
import 'school_completion_navigation.dart';
import 'management_navigation.dart';
import 'hostel_navigation.dart';
import 'hr_navigation.dart';
import 'alumni_navigation.dart';
import 'inventory_navigation.dart';
import 'library_navigation.dart';
import 'transport_navigation.dart';
import 'control_center_navigation.dart';
import 'sis_navigation.dart';
import 'parent_navigation.dart';
import 'route_names.dart';
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
}) {
  final rootNavigatorKey = GlobalKey<NavigatorState>();
  String authEntryRoute() => (readQaLoginEnabled?.call() ?? false)
      ? RouteNames.qaLogin
      : RouteNames.login;

  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: RouteNames.splash,
    refreshListenable: refreshListenable,
    debugLogDiagnostics: true,
    redirect: (context, state) =>
        _authRedirect(readAuth(), state.uri.path, authEntryRoute()),
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
        path: RouteNames.aiAssistant,
        name: 'aiAssistant',
        builder: (context, state) => aiAssistantRouteBuilder(context, state),
      ),
      GoRoute(
        path: RouteNames.parentNotifications,
        name: 'parentNotifications',
        builder: (context, state) => const NotificationsScreen(),
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
            path: RouteNames.teacherAttendance,
            name: 'teacherAttendance',
            pageBuilder: (context, state) => NoTransitionPage(
              child: teacherAttendanceRouteBuilder(context, state),
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
            path: RouteNames.teacherExams,
            name: 'teacherExams',
            pageBuilder: (context, state) => NoTransitionPage(
              child: teacherExamsRouteBuilder(context, state),
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

bool _isProtectedRoute(String location) {
  return location.startsWith('/parent') ||
      location.startsWith('/teacher') ||
      location.startsWith('/student') ||
      isAdminErpRoute(location);
}

bool _canAccessRoute(AuthState auth, String location) {
  if (isAdminErpRoute(location)) {
    return canAccessAdminErpShell(auth);
  }

  return switch (auth.role) {
    UserRole.parent => location.startsWith('/parent'),
    UserRole.teacher => location.startsWith('/teacher'),
    UserRole.student => location.startsWith('/student'),
    UserRole.staff =>
      location.startsWith('/teacher') || canAccessAdminErpShell(auth),
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
        final financeReceipt =
            await ref.read(financeRepositoryProvider).getReceipt(
                  query: ref.read(repositoryQueryProvider),
                  receiptId: receipt.id,
                );
        final bytes = await pdfService.buildReceiptPdf(
          receipt,
          financeReceipt: financeReceipt,
        );
        if (share) {
          await pdfService.shareReceipt(
            bytes: bytes,
            receiptNumber: receipt.receiptNumber,
          );
        } else {
          await pdfService.printReceipt(bytes);
        }
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            key: QaTestKeys.parentReceiptPdfSuccessSnackbar,
            content: Text(
              share ? 'Receipt PDF ready to share.' : 'Receipt PDF generated.',
            ),
          ),
        );
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
  return TeacherAttendanceScreen(
    onNotificationsTap: _teacherNotificationsTap(context),
  );
}

Widget teacherTimetableRouteBuilder(BuildContext context, GoRouterState state) {
  return TeacherTimetableScreen(
    onNotificationsTap: _teacherNotificationsTap(context),
  );
}

Widget teacherHomeworkRouteBuilder(BuildContext context, GoRouterState state) {
  return TeacherHomeworkScreen(
    onNotificationsTap: _teacherNotificationsTap(context),
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

Widget studentNoticesRouteBuilder(BuildContext context, GoRouterState state) {
  return StudentNoticesScreen(
    onNotificationsTap: _studentNotificationsTap(context),
  );
}

Widget studentProfileRouteBuilder(BuildContext context, GoRouterState state) {
  return StudentProfileScreen(
    onNotificationsTap: _studentNotificationsTap(context),
    onSettingsTap: () {},
  );
}
