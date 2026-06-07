import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../features/admin/models/admin_nav_models.dart';
import '../features/admin/screens/admin_module_placeholder_screen.dart';
import 'alumni_navigation.dart';
import 'admissions_navigation.dart';
import 'finance_navigation.dart';
import 'hostel_navigation.dart';
import 'inventory_navigation.dart';
import 'hr_navigation.dart';
import 'library_navigation.dart';
import 'transport_navigation.dart';
import 'control_center_navigation.dart';
import 'route_names.dart';

/// Whether [location] belongs to the web ERP admin shell.
bool isAdminErpRoute(String location) {
  return RouteNames.adminErpRoutes.any(
    (route) => location == route || location.startsWith('$route/'),
  );
}

/// Route builders for ERP module placeholder screens.
Widget adminHubRouteBuilder(BuildContext context, GoRouterState state) {
  return const AdminModulePlaceholderScreen(module: AdminModule.admin);
}

Widget admissionsRouteBuilder(BuildContext context, GoRouterState state) {
  return admissionsDashboardRouteBuilder(context, state);
}

Widget financeRouteBuilder(BuildContext context, GoRouterState state) {
  return financeDashboardRouteBuilder(context, state);
}

Widget hrRouteBuilder(BuildContext context, GoRouterState state) {
  return hrDashboardRouteBuilder(context, state);
}

Widget managementRouteBuilder(BuildContext context, GoRouterState state) {
  return const AdminModulePlaceholderScreen(module: AdminModule.management);
}

Widget transportRouteBuilder(BuildContext context, GoRouterState state) {
  return transportDashboardRouteBuilder(context, state);
}

Widget hostelRouteBuilder(BuildContext context, GoRouterState state) {
  return hostelDashboardRouteBuilder(context, state);
}

Widget inventoryRouteBuilder(BuildContext context, GoRouterState state) {
  return inventoryDashboardRouteBuilder(context, state);
}

Widget libraryRouteBuilder(BuildContext context, GoRouterState state) {
  return libraryDashboardRouteBuilder(context, state);
}

Widget controlCenterRouteBuilder(BuildContext context, GoRouterState state) {
  return controlCenterDashboardRouteBuilder(context, state);
}

Widget alumniRouteBuilder(BuildContext context, GoRouterState state) {
  return alumniDashboardRouteBuilder(context, state);
}
