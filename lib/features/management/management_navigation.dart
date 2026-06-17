import '../admin/models/admin_nav_models.dart';
import '../../router/route_names.dart';
import 'management_models.dart';

/// Primary management sub-navigation tabs (MG-01 → MG-08).
const List<ManagementScreen> kManagementNavScreens = [
  ManagementScreen.dashboard,
  ManagementScreen.analytics,
  ManagementScreen.admissions,
  ManagementScreen.finance,
  ManagementScreen.academics,
  ManagementScreen.performance,
  ManagementScreen.tasks,
  ManagementScreen.workflowAutomation,
  ManagementScreen.settings,
];

extension ManagementScreenRoutes on ManagementScreen {
  String get route => switch (this) {
        ManagementScreen.dashboard => RouteNames.managementDashboard,
        ManagementScreen.analytics => RouteNames.managementAnalytics,
        ManagementScreen.admissions => RouteNames.managementAdmissions,
        ManagementScreen.finance => RouteNames.managementFinance,
        ManagementScreen.academics => RouteNames.managementAcademics,
        ManagementScreen.performance => RouteNames.managementPerformance,
        ManagementScreen.tasks => RouteNames.managementTasks,
        ManagementScreen.workflowAutomation => RouteNames.managementWorkflowAutomation,
        ManagementScreen.settings => RouteNames.managementSettings,
      };
}

List<AdminBreadcrumb> managementBreadcrumbs(ManagementScreen screen) {
  return [
    const AdminBreadcrumb(
      label: 'Admin Hub',
      route: RouteNames.admin,
    ),
    const AdminBreadcrumb(
      label: 'Management',
      route: RouteNames.managementDashboard,
    ),
    AdminBreadcrumb(label: screen.label),
  ];
}

ManagementScreen? managementScreenForLocation(String location) {
  if (location == RouteNames.managementApprovals) {
    return ManagementScreen.tasks;
  }
  for (final screen in kManagementNavScreens) {
    if (location == screen.route) {
      return screen;
    }
  }
  if (location == RouteNames.management) {
    return ManagementScreen.dashboard;
  }
  return null;
}
