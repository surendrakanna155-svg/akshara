import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../features/transport/allocation/transport_allocation_screen.dart';
import '../features/transport/attendance/transport_attendance_screen.dart';
import '../features/transport/dashboard/transport_dashboard_screen.dart';
import '../features/transport/drivers/transport_drivers_screen.dart';
import '../features/transport/reports/transport_reports_screen.dart';
import '../features/transport/routes/transport_routes_screen.dart';
import '../features/transport/settings/transport_settings_screen.dart';
import '../features/transport/tracking/transport_tracking_screen.dart';
import '../features/transport/vehicles/transport_vehicles_screen.dart';
import 'route_names.dart';

String? transportRootRedirect(BuildContext context, GoRouterState state) {
  if (state.uri.path == RouteNames.transport) {
    return RouteNames.transportDashboard;
  }
  return null;
}

Widget transportDashboardRouteBuilder(
  BuildContext context,
  GoRouterState state,
) {
  return const TransportDashboardScreen();
}

Widget transportRoutesRouteBuilder(
  BuildContext context,
  GoRouterState state,
) {
  return const TransportRoutesScreen();
}

Widget transportVehiclesRouteBuilder(
  BuildContext context,
  GoRouterState state,
) {
  return const TransportVehiclesScreen();
}

Widget transportDriversRouteBuilder(
  BuildContext context,
  GoRouterState state,
) {
  return const TransportDriversScreen();
}

Widget transportAllocationRouteBuilder(
  BuildContext context,
  GoRouterState state,
) {
  return const TransportAllocationScreen();
}

Widget transportAttendanceRouteBuilder(
  BuildContext context,
  GoRouterState state,
) {
  return const TransportAttendanceScreen();
}

Widget transportTrackingRouteBuilder(
  BuildContext context,
  GoRouterState state,
) {
  return const TransportTrackingScreen();
}

Widget transportReportsRouteBuilder(
  BuildContext context,
  GoRouterState state,
) {
  return const TransportReportsScreen();
}

Widget transportSettingsRouteBuilder(
  BuildContext context,
  GoRouterState state,
) {
  return const TransportSettingsScreen();
}
