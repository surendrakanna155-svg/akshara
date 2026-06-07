import '../admin/models/admin_nav_models.dart';
import '../../router/route_names.dart';
import 'transport_models.dart';

/// Primary transport sub-navigation tabs (TR-01 → TR-09).
const List<TransportScreen> kTransportNavScreens = [
  TransportScreen.dashboard,
  TransportScreen.routes,
  TransportScreen.vehicles,
  TransportScreen.drivers,
  TransportScreen.allocation,
  TransportScreen.attendance,
  TransportScreen.tracking,
  TransportScreen.reports,
  TransportScreen.settings,
];

extension TransportScreenRoutes on TransportScreen {
  String get route => switch (this) {
        TransportScreen.dashboard => RouteNames.transportDashboard,
        TransportScreen.routes => RouteNames.transportRoutes,
        TransportScreen.vehicles => RouteNames.transportVehicles,
        TransportScreen.drivers => RouteNames.transportDrivers,
        TransportScreen.allocation => RouteNames.transportAllocation,
        TransportScreen.attendance => RouteNames.transportAttendance,
        TransportScreen.tracking => RouteNames.transportTracking,
        TransportScreen.reports => RouteNames.transportReports,
        TransportScreen.settings => RouteNames.transportSettings,
      };
}

List<AdminBreadcrumb> transportBreadcrumbs(TransportScreen screen) {
  return [
    const AdminBreadcrumb(
      label: 'Admin Hub',
      route: RouteNames.admin,
    ),
    const AdminBreadcrumb(
      label: 'Transport',
      route: RouteNames.transportDashboard,
    ),
    AdminBreadcrumb(label: screen.label),
  ];
}

TransportScreen? transportScreenForLocation(String location) {
  for (final screen in kTransportNavScreens) {
    if (location == screen.route) {
      return screen;
    }
  }
  if (location == RouteNames.transport) {
    return TransportScreen.dashboard;
  }
  return null;
}
