import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../features/finance/collections/finance_collections_screen.dart';
import '../features/finance/dashboard/finance_dashboard_screen.dart';
import '../features/finance/fee_assignment/finance_fee_assignment_screen.dart';
import '../features/finance/fee_structures/finance_fee_structures_screen.dart';
import '../features/finance/student_accounts/finance_student_accounts_screen.dart';
import 'route_names.dart';

/// Redirects bare `/finance` to the dashboard entry point.
String? financeRootRedirect(BuildContext context, GoRouterState state) {
  if (state.uri.path == RouteNames.finance) {
    return RouteNames.financeDashboard;
  }
  return null;
}

Widget financeDashboardRouteBuilder(
  BuildContext context,
  GoRouterState state,
) {
  return const FinanceDashboardScreen();
}

Widget financeFeeStructuresRouteBuilder(
  BuildContext context,
  GoRouterState state,
) {
  return const FinanceFeeStructuresScreen();
}

Widget financeStudentAccountsRouteBuilder(
  BuildContext context,
  GoRouterState state,
) {
  return const FinanceStudentAccountsScreen();
}

Widget financeFeeAssignmentRouteBuilder(
  BuildContext context,
  GoRouterState state,
) {
  return const FinanceFeeAssignmentScreen();
}

Widget financeCollectionsRouteBuilder(
  BuildContext context,
  GoRouterState state,
) {
  return const FinanceCollectionsScreen();
}
