import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../features/finance/collection_detail/finance_collection_detail_screen.dart';
import '../features/finance/collections/finance_collections_screen.dart';
import '../features/finance/dashboard/finance_dashboard_screen.dart';
import '../features/finance/defaulters/finance_defaulters_screen.dart';
import '../features/finance/discounts/finance_discounts_screen.dart';
import '../features/finance/fee_assignment/finance_fee_assignment_screen.dart';
import '../features/finance/fee_structures/finance_fee_structures_screen.dart';
import '../features/finance/refunds/finance_refunds_screen.dart';
import '../features/finance/reports/finance_reports_screen.dart';
import '../features/finance/settings/finance_settings_screen.dart';
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

Widget financeCollectionDetailRouteBuilder(
  BuildContext context,
  GoRouterState state,
) {
  final collectionId = state.pathParameters['collectionId'] ?? '';
  return FinanceCollectionDetailScreen(collectionId: collectionId);
}

Widget financeDefaultersRouteBuilder(
  BuildContext context,
  GoRouterState state,
) {
  return const FinanceDefaultersScreen();
}

Widget financeRefundsRouteBuilder(
  BuildContext context,
  GoRouterState state,
) {
  return const FinanceRefundsScreen();
}

Widget financeDiscountsRouteBuilder(
  BuildContext context,
  GoRouterState state,
) {
  return const FinanceDiscountsScreen();
}

Widget financeReportsRouteBuilder(
  BuildContext context,
  GoRouterState state,
) {
  return const FinanceReportsScreen();
}

Widget financeSettingsRouteBuilder(
  BuildContext context,
  GoRouterState state,
) {
  return const FinanceSettingsScreen();
}
