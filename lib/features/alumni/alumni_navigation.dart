import '../admin/models/admin_nav_models.dart';
import '../../router/route_names.dart';
import 'alumni_models.dart';

/// Primary alumni sub-navigation tabs (AL-01 → AL-09, excluding AL-03 child route).
const List<AlumniScreen> kAlumniNavScreens = [
  AlumniScreen.dashboard,
  AlumniScreen.registry,
  AlumniScreen.events,
  AlumniScreen.donations,
  AlumniScreen.campaigns,
  AlumniScreen.mentorship,
  AlumniScreen.reports,
  AlumniScreen.settings,
];

extension AlumniScreenRoutes on AlumniScreen {
  String get route => switch (this) {
        AlumniScreen.dashboard => RouteNames.alumniDashboard,
        AlumniScreen.registry => RouteNames.alumniRegistry,
        AlumniScreen.events => RouteNames.alumniEvents,
        AlumniScreen.donations => RouteNames.alumniDonations,
        AlumniScreen.campaigns => RouteNames.alumniCampaigns,
        AlumniScreen.mentorship => RouteNames.alumniMentorship,
        AlumniScreen.reports => RouteNames.alumniReports,
        AlumniScreen.settings => RouteNames.alumniSettings,
      };
}

List<AdminBreadcrumb> alumniBreadcrumbs(AlumniScreen screen) {
  return [
    const AdminBreadcrumb(
      label: 'Admin Hub',
      route: RouteNames.admin,
    ),
    const AdminBreadcrumb(
      label: 'Alumni',
      route: RouteNames.alumniDashboard,
    ),
    AdminBreadcrumb(label: screen.label),
  ];
}

List<AdminBreadcrumb> alumniProfileBreadcrumbs({
  required String alumniName,
}) {
  return [
    const AdminBreadcrumb(
      label: 'Admin Hub',
      route: RouteNames.admin,
    ),
    const AdminBreadcrumb(
      label: 'Alumni',
      route: RouteNames.alumniDashboard,
    ),
    const AdminBreadcrumb(
      label: 'Registry',
      route: RouteNames.alumniRegistry,
    ),
    AdminBreadcrumb(label: alumniName),
  ];
}

AlumniScreen? alumniScreenForLocation(String location) {
  for (final screen in kAlumniNavScreens) {
    if (location == screen.route) {
      return screen;
    }
  }
  if (location == RouteNames.alumni || location == RouteNames.alumniDashboard) {
    return AlumniScreen.dashboard;
  }
  if (location.startsWith('${RouteNames.alumniProfile}/')) {
    return AlumniScreen.registry;
  }
  return null;
}
