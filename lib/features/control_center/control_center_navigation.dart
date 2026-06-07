import '../admin/models/admin_nav_models.dart';
import '../../router/route_names.dart';
import 'control_center_models.dart';

/// Primary control center sub-navigation tabs (ACC-01 → ACC-12).
const List<ControlCenterScreen> kControlCenterNavScreens = [
  ControlCenterScreen.dashboard,
  ControlCenterScreen.schools,
  ControlCenterScreen.subscriptions,
  ControlCenterScreen.billing,
  ControlCenterScreen.crm,
  ControlCenterScreen.support,
  ControlCenterScreen.success,
  ControlCenterScreen.whiteLabel,
  ControlCenterScreen.analytics,
  ControlCenterScreen.monitoring,
  ControlCenterScreen.roles,
  ControlCenterScreen.settings,
];

extension ControlCenterScreenRoutes on ControlCenterScreen {
  String get route => switch (this) {
        ControlCenterScreen.dashboard => RouteNames.controlCenterDashboard,
        ControlCenterScreen.schools => RouteNames.controlCenterSchools,
        ControlCenterScreen.subscriptions =>
          RouteNames.controlCenterSubscriptions,
        ControlCenterScreen.billing => RouteNames.controlCenterBilling,
        ControlCenterScreen.crm => RouteNames.controlCenterCrm,
        ControlCenterScreen.support => RouteNames.controlCenterSupport,
        ControlCenterScreen.success => RouteNames.controlCenterSuccess,
        ControlCenterScreen.whiteLabel => RouteNames.controlCenterWhiteLabel,
        ControlCenterScreen.analytics => RouteNames.controlCenterAnalytics,
        ControlCenterScreen.monitoring => RouteNames.controlCenterMonitoring,
        ControlCenterScreen.roles => RouteNames.controlCenterRoles,
        ControlCenterScreen.settings => RouteNames.controlCenterSettings,
      };
}

List<AdminBreadcrumb> controlCenterBreadcrumbs(ControlCenterScreen screen) {
  return [
    const AdminBreadcrumb(
      label: 'Admin Hub',
      route: RouteNames.admin,
    ),
    const AdminBreadcrumb(
      label: 'Control Center',
      route: RouteNames.controlCenterDashboard,
    ),
    AdminBreadcrumb(label: screen.label),
  ];
}

ControlCenterScreen? controlCenterScreenForLocation(String location) {
  for (final screen in kControlCenterNavScreens) {
    if (location == screen.route) {
      return screen;
    }
  }
  if (location == RouteNames.controlCenter) {
    return ControlCenterScreen.dashboard;
  }
  return null;
}
