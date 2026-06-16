import '../admin/models/admin_nav_models.dart';
import '../../router/route_names.dart';
import 'hr_models.dart';

/// Primary HR sub-navigation tabs (HR-01 → HR-09, excluding HR-03 child route).
const List<HrScreen> kHrNavScreens = [
  HrScreen.dashboard,
  HrScreen.employees,
  HrScreen.attendance,
  HrScreen.leave,
  HrScreen.payroll,
  HrScreen.recruitment,
  HrScreen.performance,
  HrScreen.reports,
  HrScreen.settings,
];

extension HrScreenRoutes on HrScreen {
  String get route => switch (this) {
        HrScreen.dashboard => RouteNames.hrDashboard,
        HrScreen.employees => RouteNames.hrEmployees,
        HrScreen.attendance => RouteNames.hrAttendance,
        HrScreen.leave => RouteNames.hrLeave,
        HrScreen.payroll => RouteNames.hrPayroll,
        HrScreen.recruitment => RouteNames.hrRecruitment,
        HrScreen.performance => RouteNames.hrPerformance,
        HrScreen.reports => RouteNames.hrReports,
        HrScreen.settings => RouteNames.hrSettings,
      };
}

List<AdminBreadcrumb> hrBreadcrumbs(HrScreen screen) {
  return [
    const AdminBreadcrumb(
      label: 'Admin Hub',
      route: RouteNames.admin,
    ),
    const AdminBreadcrumb(
      label: 'HR',
      route: RouteNames.hrDashboard,
    ),
    AdminBreadcrumb(label: screen.label),
  ];
}

List<AdminBreadcrumb> hrEmployeeProfileBreadcrumbs({
  required String employeeName,
}) {
  return [
    const AdminBreadcrumb(
      label: 'Admin Hub',
      route: RouteNames.admin,
    ),
    const AdminBreadcrumb(
      label: 'HR',
      route: RouteNames.hrDashboard,
    ),
    const AdminBreadcrumb(
      label: 'Employees',
      route: RouteNames.hrEmployees,
    ),
    AdminBreadcrumb(label: employeeName),
  ];
}

HrScreen? hrScreenForLocation(String location) {
  for (final screen in kHrNavScreens) {
    if (location == screen.route) {
      return screen;
    }
  }
  if (location == RouteNames.hr || location == RouteNames.hrDashboard) {
    return HrScreen.dashboard;
  }
  if (location == RouteNames.hrReports) {
    return HrScreen.reports;
  }
  if (location.startsWith('${RouteNames.hrEmployees}/')) {
    return HrScreen.employees;
  }
  return null;
}
