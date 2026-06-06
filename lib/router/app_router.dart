import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../features/auth/auth_models.dart';
import '../features/auth/login_screen.dart';
import '../features/auth/otp_verification_screen.dart';
import '../features/auth/splash_screen.dart';
import '../features/notifications/notifications_screen.dart';
import '../features/parent/attendance/parent_attendance_screen.dart';
import '../features/parent/dashboard/parent_dashboard_screen.dart';
import '../features/parent/events/parent_events_screen.dart';
import '../features/parent/exams/parent_exams_screen.dart';
import '../features/parent/fees/parent_fees_screen.dart';
import '../features/parent/homework/parent_homework_screen.dart';
import '../features/parent/leave/parent_leave_screen.dart';
import '../features/parent/payment/parent_payment_screen.dart';
import '../features/parent/receipts/parent_receipt_detail_screen.dart';
import '../features/parent/receipts/parent_receipts_screen.dart';
import '../features/parent/notices/parent_notices_screen.dart';
import '../features/parent/profile/parent_profile_screen.dart';
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
import '../features/admin/admin_shell.dart';
import 'admin_navigation.dart';
import 'admissions_navigation.dart';
import 'finance_navigation.dart';
import 'sis_navigation.dart';
import 'parent_navigation.dart';
import 'route_names.dart';
import 'student_navigation.dart';
import 'teacher_navigation.dart';

/// Creates the application [GoRouter] with auth flow and parent shell routes.
GoRouter createAppRouter({
  Listenable? refreshListenable,
  required AuthState auth,
}) {
  final rootNavigatorKey = GlobalKey<NavigatorState>();

  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: RouteNames.splash,
    refreshListenable: refreshListenable,
    debugLogDiagnostics: true,
    redirect: (context, state) => _authRedirect(auth, state.uri.path),
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
        path: RouteNames.parent,
        redirect: (context, state) => RouteNames.parentDashboard,
      ),
      GoRoute(
        path: RouteNames.parentNotifications,
        name: 'parentNotifications',
        builder: (context, state) => const NotificationsScreen(),
      ),
      ShellRoute(
        builder: (context, state, child) => ParentShell(child: child),
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
        builder: (context, state, child) => TeacherShell(child: child),
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
        builder: (context, state, child) => AdminShell(child: child),
        routes: [
          GoRoute(
            path: RouteNames.admin,
            name: 'admin',
            pageBuilder: (context, state) => NoTransitionPage(
              child: adminHubRouteBuilder(context, state),
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
                      child: financeCollectionDetailRouteBuilder(context, state),
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
                path: 'settings',
                name: 'financeSettings',
                pageBuilder: (context, state) => NoTransitionPage(
                  child: financeSettingsRouteBuilder(context, state),
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
            ],
          ),
          GoRoute(
            path: RouteNames.hr,
            name: 'hr',
            pageBuilder: (context, state) => NoTransitionPage(
              child: hrRouteBuilder(context, state),
            ),
          ),
          GoRoute(
            path: RouteNames.management,
            name: 'management',
            pageBuilder: (context, state) => NoTransitionPage(
              child: managementRouteBuilder(context, state),
            ),
          ),
          GoRoute(
            path: RouteNames.transport,
            name: 'transport',
            pageBuilder: (context, state) => NoTransitionPage(
              child: transportRouteBuilder(context, state),
            ),
          ),
          GoRoute(
            path: RouteNames.hostel,
            name: 'hostel',
            pageBuilder: (context, state) => NoTransitionPage(
              child: hostelRouteBuilder(context, state),
            ),
          ),
        ],
      ),
      ShellRoute(
        builder: (context, state, child) => StudentShell(child: child),
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

String? _authRedirect(AuthState auth, String location) {
  final isSplash = location == RouteNames.splash;
  final isLogin = location == RouteNames.login;
  final isOtp = location == RouteNames.otpVerification;
  final isAuthEntryRoute = isSplash || isLogin || isOtp;

  if (auth.status == AuthStatus.unknown) {
    return isSplash ? null : RouteNames.splash;
  }

  final isAuthenticated = auth.isAuthenticated;
  final isProtectedRoute = _isProtectedRoute(location);

  if (!isAuthenticated && isProtectedRoute) {
    return RouteNames.login;
  }

  if (isAuthenticated && (isLogin || isOtp)) {
    return homeRouteForRole(auth.role);
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
    return auth.role == UserRole.staff;
  }

  return switch (auth.role) {
    UserRole.parent => location.startsWith('/parent'),
    UserRole.teacher => location.startsWith('/teacher'),
    UserRole.student => location.startsWith('/student'),
    UserRole.staff =>
      location.startsWith('/teacher') || isAdminErpRoute(location),
    null => false,
  };
}

/// Role-based home route after login, OTP, or splash bootstrap.
String homeRouteForRole(UserRole? role) {
  return switch (role) {
    UserRole.parent => RouteNames.parentDashboard,
    UserRole.teacher => RouteNames.teacherDashboard,
    UserRole.student => RouteNames.studentDashboard,
    UserRole.staff => RouteNames.teacherDashboard,
    null => RouteNames.login,
  };
}

/// Dashboard screen wired with router navigation.
Widget parentDashboardRouteBuilder(BuildContext context, GoRouterState state) {
  return ParentDashboardScreen(
    onNavigate: (actionId) => handleParentDashboardNavigation(context, actionId),
  );
}

/// Attendance screen with notification bell routing.
Widget parentAttendanceRouteBuilder(BuildContext context, GoRouterState state) {
  return ParentAttendanceScreen(
    onNotificationsTap: () =>
        context.push(RouteNames.parentNotifications),
    onAcademicsNavigate: (destination) =>
        handleParentAcademicsNavigation(context, destination),
  );
}

/// Fees screen with notification bell routing.
Widget parentFeesRouteBuilder(BuildContext context, GoRouterState state) {
  return ParentFeesScreen(
    onNotificationsTap: () =>
        context.push(RouteNames.parentNotifications),
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
    onNotificationsTap: () =>
        context.push(RouteNames.parentNotifications),
  );
}

/// Homework list screen (PA-05).
Widget parentHomeworkRouteBuilder(BuildContext context, GoRouterState state) {
  return ParentHomeworkScreen(
    onNotificationsTap: () =>
        context.push(RouteNames.parentNotifications),
  );
}

/// Exams screen (PA-06).
Widget parentExamsRouteBuilder(BuildContext context, GoRouterState state) {
  return ParentExamsScreen(
    onNotificationsTap: () =>
        context.push(RouteNames.parentNotifications),
  );
}

/// School notices screen (PA-07).
Widget parentNoticesRouteBuilder(BuildContext context, GoRouterState state) {
  return ParentNoticesScreen(
    onNotificationsTap: () =>
        context.push(RouteNames.parentNotifications),
  );
}

/// School events screen (PA-08).
Widget parentEventsRouteBuilder(BuildContext context, GoRouterState state) {
  return ParentEventsScreen(
    onNotificationsTap: () =>
        context.push(RouteNames.parentNotifications),
  );
}

/// Parent profile screen (PA-09).
Widget parentProfileRouteBuilder(BuildContext context, GoRouterState state) {
  return ParentProfileScreen(
    onNotificationsTap: () =>
        context.push(RouteNames.parentNotifications),
    onLeaveTap: () => context.go(RouteNames.parentLeave),
    onReceiptsTap: () => context.go(RouteNames.parentReceipts),
  );
}

/// Fee payment flow (PA-10).
Widget parentPaymentRouteBuilder(BuildContext context, GoRouterState state) {
  final installmentId =
      state.uri.queryParameters['installmentId'] ?? 'term_2';

  return ParentPaymentScreen(
    key: ValueKey('payment-$installmentId'),
    installmentId: installmentId,
    onNotificationsTap: () =>
        context.push(RouteNames.parentNotifications),
    onViewReceipt: (receiptId) =>
        handleParentFeesNavigation(context, receiptId: receiptId),
    onBackToFees: () => context.go(RouteNames.parentFees),
  );
}

/// Receipts list (PA-11).
Widget parentReceiptsRouteBuilder(BuildContext context, GoRouterState state) {
  return ParentReceiptsScreen(
    onNotificationsTap: () =>
        context.push(RouteNames.parentNotifications),
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

  return ParentReceiptDetailScreen(
    receiptId: receiptId,
    onNotificationsTap: () =>
        context.push(RouteNames.parentNotifications),
    onDownload: (_) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Receipt download started (mock).')),
      );
    },
    onShare: (_) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Share sheet opened (mock).')),
      );
    },
  );
}

/// Leave requests (PA-12).
Widget parentLeaveRouteBuilder(BuildContext context, GoRouterState state) {
  return ParentLeaveScreen(
    onNotificationsTap: () =>
        context.push(RouteNames.parentNotifications),
  );
}

/// Teacher dashboard wired with router navigation.
Widget teacherDashboardRouteBuilder(BuildContext context, GoRouterState state) {
  return TeacherDashboardScreen(
    onNavigate: (actionId) => handleTeacherNavigation(context, actionId),
  );
}

VoidCallback _teacherNotificationsTap(BuildContext context) =>
    () => context.push(RouteNames.parentNotifications);

Widget teacherAttendanceRouteBuilder(BuildContext context, GoRouterState state) {
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
  return StudentDashboardScreen(
    onNavigate: (actionId) => handleStudentNavigation(context, actionId),
  );
}

VoidCallback _studentNotificationsTap(BuildContext context) =>
    () => context.push(RouteNames.parentNotifications);

Widget studentAttendanceRouteBuilder(BuildContext context, GoRouterState state) {
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
