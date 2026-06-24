import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../features/director/director_admissions_screen.dart';
import '../features/director/director_compliance_screen.dart';
import '../features/director/director_dashboard_screen.dart';
import '../features/director/director_growth_screen.dart';
import '../features/director/director_marketing_screen.dart';
import '../features/director/director_portfolio_screen.dart';
import '../features/director/director_reports_screen.dart';
import '../features/director/director_revenue_screen.dart';
import '../features/director/director_schools_screen.dart';
import '../features/admin/models/admin_nav_models.dart';
import '../features/entitlements/entitlement_module_gate.dart';
import 'route_names.dart';

String? directorRootRedirect(BuildContext context, GoRouterState state) {
  if (state.uri.path == RouteNames.director) {
    return RouteNames.directorDashboard;
  }
  return null;
}

Widget directorDashboardRouteBuilder(
    BuildContext context, GoRouterState state) {
  return const EntitlementModuleGate(
    module: AdminModule.director,
    child: DirectorDashboardScreen(),
  );
}

Widget directorSchoolsRouteBuilder(BuildContext context, GoRouterState state) {
  return const DirectorSchoolsScreen();
}

Widget directorPortfolioRouteBuilder(
    BuildContext context, GoRouterState state) {
  return const DirectorPortfolioScreen();
}

Widget directorRevenueRouteBuilder(BuildContext context, GoRouterState state) {
  return const DirectorRevenueScreen();
}

Widget directorGrowthRouteBuilder(BuildContext context, GoRouterState state) {
  return const DirectorGrowthScreen();
}

Widget directorMarketingRouteBuilder(
    BuildContext context, GoRouterState state) {
  return const DirectorMarketingScreen();
}

Widget directorAdmissionsRouteBuilder(
    BuildContext context, GoRouterState state) {
  return const DirectorAdmissionsScreen();
}

Widget directorComplianceRouteBuilder(
    BuildContext context, GoRouterState state) {
  return const DirectorComplianceScreen();
}

Widget directorReportsRouteBuilder(BuildContext context, GoRouterState state) {
  return const DirectorReportsScreen();
}
