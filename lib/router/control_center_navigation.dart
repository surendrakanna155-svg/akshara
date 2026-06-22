import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../features/platform/control_center/analytics/control_center_analytics_screen.dart';
import '../features/platform/control_center/billing/control_center_billing_screen.dart';
import '../features/platform/control_center/crm/control_center_crm_screen.dart';
import '../features/platform/control_center/dashboard/control_center_dashboard_screen.dart';
import '../features/platform/control_center/intelligence/platform_intelligence_screen.dart';
import '../features/platform/control_center/features/control_center_features_screen.dart';
import '../features/platform/control_center/monitoring/control_center_monitoring_screen.dart';
import '../features/platform/control_center/providers/control_center_providers_screen.dart';
import '../features/platform/control_center/roles/control_center_roles_screen.dart';
import '../features/platform/control_center/schools/control_center_schools_screen.dart';
import '../features/platform/control_center/settings/control_center_settings_screen.dart';
import '../features/platform/control_center/subscriptions/control_center_subscriptions_screen.dart';
import '../features/platform/control_center/success/control_center_success_screen.dart';
import '../features/platform/control_center/support/control_center_support_screen.dart';
import '../features/platform/control_center/white_label/control_center_white_label_screen.dart';
import 'route_guards.dart';
import 'route_names.dart';

String? controlCenterRootRedirect(BuildContext context, GoRouterState state) {
  if (state.uri.path == RouteNames.controlCenter) {
    return RouteNames.controlCenterDashboard;
  }
  return null;
}

Widget _controlCenterScreen(Widget child) => ControlCenterGuard(child: child);

Widget controlCenterDashboardRouteBuilder(
  BuildContext context,
  GoRouterState state,
) {
  return _controlCenterScreen(const ControlCenterDashboardScreen());
}

Widget controlCenterSchoolsRouteBuilder(
  BuildContext context,
  GoRouterState state,
) {
  return _controlCenterScreen(const ControlCenterSchoolsScreen());
}

Widget controlCenterIntelligenceRouteBuilder(
  BuildContext context,
  GoRouterState state,
) {
  return _controlCenterScreen(const PlatformIntelligenceScreen());
}

Widget controlCenterSubscriptionsRouteBuilder(
  BuildContext context,
  GoRouterState state,
) {
  return _controlCenterScreen(const ControlCenterSubscriptionsScreen());
}

Widget controlCenterBillingRouteBuilder(
  BuildContext context,
  GoRouterState state,
) {
  return _controlCenterScreen(const ControlCenterBillingScreen());
}

Widget controlCenterCrmRouteBuilder(
  BuildContext context,
  GoRouterState state,
) {
  return _controlCenterScreen(const ControlCenterCrmScreen());
}

Widget controlCenterSupportRouteBuilder(
  BuildContext context,
  GoRouterState state,
) {
  return _controlCenterScreen(const ControlCenterSupportScreen());
}

Widget controlCenterSuccessRouteBuilder(
  BuildContext context,
  GoRouterState state,
) {
  return _controlCenterScreen(const ControlCenterSuccessScreen());
}

Widget controlCenterWhiteLabelRouteBuilder(
  BuildContext context,
  GoRouterState state,
) {
  return _controlCenterScreen(const ControlCenterWhiteLabelScreen());
}

Widget controlCenterAnalyticsRouteBuilder(
  BuildContext context,
  GoRouterState state,
) {
  return _controlCenterScreen(const ControlCenterAnalyticsScreen());
}

Widget controlCenterMonitoringRouteBuilder(
  BuildContext context,
  GoRouterState state,
) {
  return _controlCenterScreen(const ControlCenterMonitoringScreen());
}

Widget controlCenterRolesRouteBuilder(
  BuildContext context,
  GoRouterState state,
) {
  return _controlCenterScreen(const ControlCenterRolesScreen());
}

Widget controlCenterSettingsRouteBuilder(
  BuildContext context,
  GoRouterState state,
) {
  return _controlCenterScreen(const ControlCenterSettingsScreen());
}

Widget controlCenterProvidersRouteBuilder(
  BuildContext context,
  GoRouterState state,
) {
  return _controlCenterScreen(const ControlCenterProvidersScreen());
}

Widget controlCenterFeaturesRouteBuilder(
  BuildContext context,
  GoRouterState state,
) {
  return _controlCenterScreen(const ControlCenterFeaturesScreen());
}
