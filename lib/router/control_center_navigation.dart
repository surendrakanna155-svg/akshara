import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../features/control_center/analytics/control_center_analytics_screen.dart';
import '../features/control_center/billing/control_center_billing_screen.dart';
import '../features/control_center/crm/control_center_crm_screen.dart';
import '../features/control_center/dashboard/control_center_dashboard_screen.dart';
import '../features/control_center/monitoring/control_center_monitoring_screen.dart';
import '../features/control_center/roles/control_center_roles_screen.dart';
import '../features/control_center/schools/control_center_schools_screen.dart';
import '../features/control_center/settings/control_center_settings_screen.dart';
import '../features/control_center/subscriptions/control_center_subscriptions_screen.dart';
import '../features/control_center/success/control_center_success_screen.dart';
import '../features/control_center/support/control_center_support_screen.dart';
import '../features/control_center/white_label/control_center_white_label_screen.dart';
import 'route_names.dart';

String? controlCenterRootRedirect(BuildContext context, GoRouterState state) {
  if (state.uri.path == RouteNames.controlCenter) {
    return RouteNames.controlCenterDashboard;
  }
  return null;
}

Widget controlCenterDashboardRouteBuilder(
  BuildContext context,
  GoRouterState state,
) {
  return const ControlCenterDashboardScreen();
}

Widget controlCenterSchoolsRouteBuilder(
  BuildContext context,
  GoRouterState state,
) {
  return const ControlCenterSchoolsScreen();
}

Widget controlCenterSubscriptionsRouteBuilder(
  BuildContext context,
  GoRouterState state,
) {
  return const ControlCenterSubscriptionsScreen();
}

Widget controlCenterBillingRouteBuilder(
  BuildContext context,
  GoRouterState state,
) {
  return const ControlCenterBillingScreen();
}

Widget controlCenterCrmRouteBuilder(
  BuildContext context,
  GoRouterState state,
) {
  return const ControlCenterCrmScreen();
}

Widget controlCenterSupportRouteBuilder(
  BuildContext context,
  GoRouterState state,
) {
  return const ControlCenterSupportScreen();
}

Widget controlCenterSuccessRouteBuilder(
  BuildContext context,
  GoRouterState state,
) {
  return const ControlCenterSuccessScreen();
}

Widget controlCenterWhiteLabelRouteBuilder(
  BuildContext context,
  GoRouterState state,
) {
  return const ControlCenterWhiteLabelScreen();
}

Widget controlCenterAnalyticsRouteBuilder(
  BuildContext context,
  GoRouterState state,
) {
  return const ControlCenterAnalyticsScreen();
}

Widget controlCenterMonitoringRouteBuilder(
  BuildContext context,
  GoRouterState state,
) {
  return const ControlCenterMonitoringScreen();
}

Widget controlCenterRolesRouteBuilder(
  BuildContext context,
  GoRouterState state,
) {
  return const ControlCenterRolesScreen();
}

Widget controlCenterSettingsRouteBuilder(
  BuildContext context,
  GoRouterState state,
) {
  return const ControlCenterSettingsScreen();
}
