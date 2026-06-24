import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../features/admin/models/admin_nav_models.dart';
import '../features/admin/screens/admin_hub_screen.dart';
import '../features/admin/screens/admin_module_placeholder_screen.dart';
import '../features/entitlements/entitlement_module_gate.dart';
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
  return const AdminHubScreen();
}

Widget admissionsRouteBuilder(BuildContext context, GoRouterState state) {
  return admissionsDashboardRouteBuilder(context, state);
}

Widget financeRouteBuilder(BuildContext context, GoRouterState state) {
  return financeDashboardRouteBuilder(context, state);
}

Widget hrRouteBuilder(BuildContext context, GoRouterState state) {
  return EntitlementModuleGate(
    module: AdminModule.hr,
    child: hrDashboardRouteBuilder(context, state),
  );
}

Widget managementRouteBuilder(BuildContext context, GoRouterState state) {
  return const AdminModulePlaceholderScreen(module: AdminModule.management);
}

Widget transportRouteBuilder(BuildContext context, GoRouterState state) {
  return EntitlementModuleGate(
    module: AdminModule.transport,
    child: transportDashboardRouteBuilder(context, state),
  );
}

Widget hostelRouteBuilder(BuildContext context, GoRouterState state) {
  return EntitlementModuleGate(
    module: AdminModule.hostel,
    child: hostelDashboardRouteBuilder(context, state),
  );
}

Widget inventoryRouteBuilder(BuildContext context, GoRouterState state) {
  return EntitlementModuleGate(
    module: AdminModule.inventory,
    child: inventoryDashboardRouteBuilder(context, state),
  );
}

Widget libraryRouteBuilder(BuildContext context, GoRouterState state) {
  return EntitlementModuleGate(
    module: AdminModule.library,
    child: libraryDashboardRouteBuilder(context, state),
  );
}

// Control Center stays ungated (owner decision — overlaps core management).
Widget controlCenterRouteBuilder(BuildContext context, GoRouterState state) {
  return controlCenterDashboardRouteBuilder(context, state);
}

Widget alumniRouteBuilder(BuildContext context, GoRouterState state) {
  return EntitlementModuleGate(
    module: AdminModule.alumni,
    child: alumniDashboardRouteBuilder(context, state),
  );
}
