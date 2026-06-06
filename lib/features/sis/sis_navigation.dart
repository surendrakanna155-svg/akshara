import '../admin/models/admin_nav_models.dart';
import '../../router/route_names.dart';
import 'sis_models.dart';

/// Primary SIS sub-navigation tabs (SIS-01 → SIS-05).
const List<SisScreen> kSisNavScreens = [
  SisScreen.dashboard,
  SisScreen.registry,
  SisScreen.academicAssignment,
  SisScreen.admissionsConversion,
];

extension SisScreenRoutes on SisScreen {
  String get route => switch (this) {
        SisScreen.dashboard => RouteNames.sisDashboard,
        SisScreen.registry => RouteNames.sisStudents,
        SisScreen.academicAssignment => RouteNames.sisAcademicAssignment,
        SisScreen.admissionsConversion => RouteNames.sisAdmissionsConversion,
      };
}

/// Breadcrumbs for a SIS screen inside the admin shell.
List<AdminBreadcrumb> sisBreadcrumbs(SisScreen screen) {
  return [
    const AdminBreadcrumb(
      label: 'Admin Hub',
      route: RouteNames.admin,
    ),
    const AdminBreadcrumb(
      label: 'Student SIS',
      route: RouteNames.sisDashboard,
    ),
    AdminBreadcrumb(label: screen.label),
  ];
}

/// Breadcrumbs for SIS-03 student profile nested under registry.
List<AdminBreadcrumb> sisStudentProfileBreadcrumbs({
  required String studentName,
}) {
  return [
    const AdminBreadcrumb(
      label: 'Admin Hub',
      route: RouteNames.admin,
    ),
    const AdminBreadcrumb(
      label: 'Student SIS',
      route: RouteNames.sisDashboard,
    ),
    const AdminBreadcrumb(
      label: 'Student Registry',
      route: RouteNames.sisStudents,
    ),
    AdminBreadcrumb(label: studentName),
  ];
}

/// Resolves [SisScreen] from a router location path.
SisScreen? sisScreenForLocation(String location) {
  if (location.startsWith('${RouteNames.sisStudents}/')) {
    return SisScreen.registry;
  }
  for (final screen in SisScreen.values) {
    if (location == screen.route || location.startsWith('${screen.route}/')) {
      return screen;
    }
  }
  if (location == RouteNames.sis) {
    return SisScreen.dashboard;
  }
  return null;
}
