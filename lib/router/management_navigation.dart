import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../features/academics/timetable/timetable_hub_screen.dart';
import '../features/management/attendance/attendance_corrections_admin_screen.dart';
import '../features/management/attendance/office_attendance_screen.dart';
import '../features/intelligence/management/intelligence_hub_screen.dart';
import '../features/management/academics/management_academics_screen.dart';
import '../features/management/admissions/management_admissions_screen.dart';
import '../features/management/analytics/management_analytics_screen.dart';
import '../features/management/dashboard/management_dashboard_screen.dart';
import '../features/management/finance/management_finance_screen.dart';
import '../features/management/performance/management_performance_screen.dart';
import '../features/management/school_calendar/school_calendar_screen.dart';
import '../features/management/settings/management_settings_screen.dart';
import '../features/management/approval/principal_approval_center_screen.dart';
import '../features/management/tasks/management_tasks_screen.dart';
import '../features/workflow/workflow_automation_screen.dart';
import 'route_names.dart';

String? managementRootRedirect(BuildContext context, GoRouterState state) {
  if (state.uri.path == RouteNames.management) {
    return RouteNames.managementDashboard;
  }
  return null;
}

Widget managementDashboardRouteBuilder(
  BuildContext context,
  GoRouterState state,
) {
  return const ManagementDashboardScreen();
}

Widget managementAnalyticsRouteBuilder(
  BuildContext context,
  GoRouterState state,
) {
  return const ManagementAnalyticsScreen();
}

Widget managementAdmissionsRouteBuilder(
  BuildContext context,
  GoRouterState state,
) {
  return const ManagementAdmissionsScreen();
}

Widget managementFinanceRouteBuilder(
  BuildContext context,
  GoRouterState state,
) {
  return const ManagementFinanceScreen();
}

Widget managementAcademicsRouteBuilder(
  BuildContext context,
  GoRouterState state,
) {
  return const ManagementAcademicsScreen();
}

Widget managementTimetableRouteBuilder(
  BuildContext context,
  GoRouterState state,
) {
  return const TimetableHubScreen();
}

Widget managementIntelligenceRouteBuilder(
  BuildContext context,
  GoRouterState state,
) {
  return const IntelligenceHubScreen();
}

Widget managementPerformanceRouteBuilder(
  BuildContext context,
  GoRouterState state,
) {
  return const ManagementPerformanceScreen();
}

Widget managementTasksRouteBuilder(
  BuildContext context,
  GoRouterState state,
) {
  return const ManagementTasksScreen();
}

Widget managementApprovalsRouteBuilder(
  BuildContext context,
  GoRouterState state,
) {
  return const PrincipalApprovalCenterScreen();
}

Widget managementSettingsRouteBuilder(
  BuildContext context,
  GoRouterState state,
) {
  return const ManagementSettingsScreen();
}

/// PRA-P1-17 — holiday/event calendar (gated on `viewSchoolCalendar`).
Widget managementSchoolCalendarRouteBuilder(
  BuildContext context,
  GoRouterState state,
) {
  return const SchoolCalendarScreen();
}

Widget managementWorkflowAutomationRouteBuilder(
  BuildContext context,
  GoRouterState state,
) {
  return const WorkflowAutomationScreen();
}

Widget managementAttendanceCorrectionsRouteBuilder(
  BuildContext context,
  GoRouterState state,
) {
  return const AttendanceCorrectionsAdminScreen();
}

Widget managementOfficeAttendanceRouteBuilder(
  BuildContext context,
  GoRouterState state,
) {
  return const OfficeAttendanceScreen();
}
