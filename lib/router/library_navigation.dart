import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../features/library/catalog/library_catalog_screen.dart';
import '../features/library/dashboard/library_dashboard_screen.dart';
import '../features/library/fines/library_fines_screen.dart';
import '../features/library/issues/library_issues_screen.dart';
import '../features/library/members/library_members_screen.dart';
import '../features/library/reports/library_reports_screen.dart';
import '../features/library/resources/library_resources_screen.dart';
import '../features/library/returns/library_returns_screen.dart';
import 'route_names.dart';

String? libraryRootRedirect(BuildContext context, GoRouterState state) {
  if (state.uri.path == RouteNames.library) {
    return RouteNames.libraryDashboard;
  }
  return null;
}

Widget libraryDashboardRouteBuilder(
  BuildContext context,
  GoRouterState state,
) {
  return const LibraryDashboardScreen();
}

Widget libraryCatalogRouteBuilder(
  BuildContext context,
  GoRouterState state,
) {
  return const LibraryCatalogScreen();
}

Widget libraryIssuesRouteBuilder(
  BuildContext context,
  GoRouterState state,
) {
  return const LibraryIssuesScreen();
}

Widget libraryReturnsRouteBuilder(
  BuildContext context,
  GoRouterState state,
) {
  return const LibraryReturnsScreen();
}

Widget libraryMembersRouteBuilder(
  BuildContext context,
  GoRouterState state,
) {
  return const LibraryMembersScreen();
}

Widget libraryFinesRouteBuilder(
  BuildContext context,
  GoRouterState state,
) {
  return const LibraryFinesScreen();
}

Widget libraryResourcesRouteBuilder(
  BuildContext context,
  GoRouterState state,
) {
  return const LibraryResourcesScreen();
}

Widget libraryReportsRouteBuilder(
  BuildContext context,
  GoRouterState state,
) {
  return const LibraryReportsScreen();
}
