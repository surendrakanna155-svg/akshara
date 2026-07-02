import '../admin/models/admin_nav_models.dart';
import '../../router/route_names.dart';
import 'library_models.dart';

/// Primary library sub-navigation tabs (LB-01 → LB-08).
const List<LibraryScreen> kLibraryNavScreens = [
  LibraryScreen.dashboard,
  LibraryScreen.catalog,
  LibraryScreen.issues,
  LibraryScreen.returns,
  LibraryScreen.members,
  LibraryScreen.fines,
  LibraryScreen.resources,
  LibraryScreen.reports,
];

extension LibraryScreenRoutes on LibraryScreen {
  String get route => switch (this) {
        LibraryScreen.dashboard => RouteNames.libraryDashboard,
        LibraryScreen.catalog => RouteNames.libraryCatalog,
        LibraryScreen.issues => RouteNames.libraryIssues,
        LibraryScreen.returns => RouteNames.libraryReturns,
        LibraryScreen.members => RouteNames.libraryMembers,
        LibraryScreen.fines => RouteNames.libraryFines,
        LibraryScreen.resources => RouteNames.libraryResources,
        LibraryScreen.reports => RouteNames.libraryReports,
      };
}

List<AdminBreadcrumb> libraryBreadcrumbs(LibraryScreen screen) {
  return [
    const AdminBreadcrumb(
      label: 'Admin Hub',
      route: RouteNames.admin,
    ),
    const AdminBreadcrumb(
      label: 'Library',
      route: RouteNames.libraryDashboard,
    ),
    AdminBreadcrumb(label: screen.label),
  ];
}

/// LIB-1 — breadcrumbs for a secondary library screen that is not a sub-nav tab
/// (e.g. the Overdue loans report).
List<AdminBreadcrumb> librarySecondaryBreadcrumbs(String label) {
  return [
    const AdminBreadcrumb(
      label: 'Admin Hub',
      route: RouteNames.admin,
    ),
    const AdminBreadcrumb(
      label: 'Library',
      route: RouteNames.libraryDashboard,
    ),
    AdminBreadcrumb(label: label),
  ];
}

LibraryScreen? libraryScreenForLocation(String location) {
  for (final screen in kLibraryNavScreens) {
    if (location == screen.route) {
      return screen;
    }
  }
  if (location == RouteNames.library) {
    return LibraryScreen.dashboard;
  }
  return null;
}
