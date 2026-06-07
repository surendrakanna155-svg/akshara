import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../features/management/academics/management_academics_screen.dart';
import '../features/management/admissions/management_admissions_screen.dart';
import '../features/management/analytics/management_analytics_screen.dart';
import '../features/management/dashboard/management_dashboard_screen.dart';
import '../features/management/finance/management_finance_screen.dart';
import '../features/management/performance/management_performance_screen.dart';
import '../features/management/settings/management_settings_screen.dart';
import '../features/management/tasks/management_tasks_screen.dart';
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

Widget managementSettingsRouteBuilder(
  BuildContext context,
  GoRouterState state,
) {
  return const ManagementSettingsScreen();
}
