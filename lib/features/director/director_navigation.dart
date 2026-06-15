import '../admin/models/admin_nav_models.dart';
import '../../router/route_names.dart';

enum DirectorScreen {
  dashboard,
  schools,
  portfolio,
  revenue,
  growth,
  marketing,
  admissions,
  compliance,
  reports;

  String get label => switch (this) {
        DirectorScreen.dashboard => 'Dashboard',
        DirectorScreen.schools => 'Schools',
        DirectorScreen.portfolio => 'Portfolio',
        DirectorScreen.revenue => 'Revenue',
        DirectorScreen.growth => 'Growth',
        DirectorScreen.marketing => 'Marketing',
        DirectorScreen.admissions => 'Admissions',
        DirectorScreen.compliance => 'Compliance',
        DirectorScreen.reports => 'Reports',
      };
}

const List<DirectorScreen> kDirectorNavScreens = [
  DirectorScreen.dashboard,
  DirectorScreen.schools,
  DirectorScreen.portfolio,
  DirectorScreen.revenue,
  DirectorScreen.growth,
  DirectorScreen.marketing,
  DirectorScreen.admissions,
  DirectorScreen.compliance,
  DirectorScreen.reports,
];

extension DirectorScreenRoutes on DirectorScreen {
  String get route => switch (this) {
        DirectorScreen.dashboard => RouteNames.directorDashboard,
        DirectorScreen.schools => RouteNames.directorSchools,
        DirectorScreen.portfolio => RouteNames.directorPortfolio,
        DirectorScreen.revenue => RouteNames.directorRevenue,
        DirectorScreen.growth => RouteNames.directorGrowth,
        DirectorScreen.marketing => RouteNames.directorMarketing,
        DirectorScreen.admissions => RouteNames.directorAdmissions,
        DirectorScreen.compliance => RouteNames.directorCompliance,
        DirectorScreen.reports => RouteNames.directorReports,
      };
}

List<AdminBreadcrumb> directorBreadcrumbs(DirectorScreen screen) {
  return [
    const AdminBreadcrumb(label: 'Admin Hub', route: RouteNames.admin),
    const AdminBreadcrumb(label: 'Director Portal', route: RouteNames.director),
    AdminBreadcrumb(label: screen.label),
  ];
}

DirectorScreen? directorScreenForLocation(String location) {
  for (final screen in kDirectorNavScreens) {
    if (location == screen.route) return screen;
  }
  if (location == RouteNames.director) return DirectorScreen.dashboard;
  return null;
}
