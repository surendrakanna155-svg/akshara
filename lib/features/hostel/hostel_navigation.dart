import '../admin/models/admin_nav_models.dart';
import '../../router/route_names.dart';
import 'hostel_models.dart';

/// Primary hostel sub-navigation tabs (HO-01 → HO-08).
const List<HostelScreen> kHostelNavScreens = [
  HostelScreen.dashboard,
  HostelScreen.students,
  HostelScreen.rooms,
  HostelScreen.attendance,
  HostelScreen.leave,
  HostelScreen.mess,
  HostelScreen.visitors,
  HostelScreen.reports,
];

extension HostelScreenRoutes on HostelScreen {
  String get route => switch (this) {
        HostelScreen.dashboard => RouteNames.hostelDashboard,
        HostelScreen.students => RouteNames.hostelStudents,
        HostelScreen.rooms => RouteNames.hostelRooms,
        HostelScreen.attendance => RouteNames.hostelAttendance,
        HostelScreen.leave => RouteNames.hostelLeave,
        HostelScreen.mess => RouteNames.hostelMess,
        HostelScreen.visitors => RouteNames.hostelVisitors,
        HostelScreen.reports => RouteNames.hostelReports,
      };
}

List<AdminBreadcrumb> hostelBreadcrumbs(HostelScreen screen) {
  return [
    const AdminBreadcrumb(
      label: 'Admin Hub',
      route: RouteNames.admin,
    ),
    const AdminBreadcrumb(
      label: 'Hostel',
      route: RouteNames.hostelDashboard,
    ),
    AdminBreadcrumb(label: screen.label),
  ];
}

HostelScreen? hostelScreenForLocation(String location) {
  for (final screen in kHostelNavScreens) {
    if (location == screen.route) {
      return screen;
    }
  }
  if (location == RouteNames.hostel) {
    return HostelScreen.dashboard;
  }
  return null;
}
