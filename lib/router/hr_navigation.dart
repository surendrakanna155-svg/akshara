import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/security/permissions.dart';
import '../features/hr/attendance/hr_attendance_screen.dart';
import '../features/hr/dashboard/hr_dashboard_screen.dart';
import '../features/hr/employees/hr_employee_profile_screen.dart';
import '../features/hr/employees/hr_employees_screen.dart';
import '../features/hr/leave/hr_leave_screen.dart';
import '../features/hr/payroll/hr_payroll_screen.dart';
import '../features/hr/performance/hr_performance_screen.dart';
import '../features/hr/recruitment/hr_recruitment_screen.dart';
import '../features/hr/reports/hr_reports_screen.dart';
import '../features/hr/settings/hr_settings_screen.dart';
import '../features/staff_attendance/manual_attendance_approver_screen.dart';
import '../features/staff_attendance/manual_attendance_request_screen.dart';
import 'route_guards.dart';
import 'route_names.dart';

String? hrRootRedirect(BuildContext context, GoRouterState state) {
  if (state.uri.path == RouteNames.hr) {
    return RouteNames.hrDashboard;
  }
  return null;
}

Widget hrDashboardRouteBuilder(BuildContext context, GoRouterState state) {
  return const HrDashboardScreen();
}

Widget hrEmployeesRouteBuilder(BuildContext context, GoRouterState state) {
  return const HrEmployeesScreen();
}

Widget hrEmployeeDetailRouteBuilder(BuildContext context, GoRouterState state) {
  final employeeId = state.pathParameters['employeeId'] ?? '';
  return HrEmployeeProfileScreen(employeeId: employeeId);
}

Widget hrAttendanceRouteBuilder(BuildContext context, GoRouterState state) {
  return const HrAttendanceScreen();
}

/// PRA-P0-15 — staff-facing manual-attendance request (audited fallback).
Widget hrStaffManualRequestRouteBuilder(
  BuildContext context,
  GoRouterState state,
) {
  return const ManualAttendanceRequestScreen();
}

/// PRA-P0-15 — approver queue for manual-attendance requests. Client gate is a
/// manage-level guard (closest representable proxy for `approveStaffAttendance`,
/// which the server re-enforces on the decide endpoint).
Widget hrStaffManualRequestQueueRouteBuilder(
  BuildContext context,
  GoRouterState state,
) {
  return const ManagePermissionGuard(
    permission: Permission.manageHr,
    child: ManualAttendanceApproverScreen(),
  );
}

Widget hrLeaveRouteBuilder(BuildContext context, GoRouterState state) {
  return const HrLeaveScreen();
}

Widget hrPayrollRouteBuilder(BuildContext context, GoRouterState state) {
  return const HrPayrollScreen();
}

Widget hrRecruitmentRouteBuilder(BuildContext context, GoRouterState state) {
  return const HrRecruitmentScreen();
}

Widget hrPerformanceRouteBuilder(BuildContext context, GoRouterState state) {
  return const HrPerformanceScreen();
}

Widget hrReportsRouteBuilder(BuildContext context, GoRouterState state) {
  return const HrReportsScreen();
}

Widget hrSettingsRouteBuilder(BuildContext context, GoRouterState state) {
  return const HrSettingsScreen();
}
