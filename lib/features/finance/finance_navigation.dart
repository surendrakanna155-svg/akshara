import '../admin/models/admin_nav_models.dart';
import '../../router/route_names.dart';
import 'finance_models.dart';

/// Primary finance sub-navigation tabs (FN-01 → FN-11).
const List<FinanceScreen> kFinanceNavScreens = [
  FinanceScreen.dashboard,
  FinanceScreen.feeStructures,
  FinanceScreen.studentAccounts,
  FinanceScreen.feeAssignment,
  FinanceScreen.collections,
  FinanceScreen.defaulters,
  FinanceScreen.refunds,
  FinanceScreen.discounts,
  FinanceScreen.reports,
  FinanceScreen.reconciliation,
  FinanceScreen.settings,
];

extension FinanceScreenRoutes on FinanceScreen {
  String get route => switch (this) {
        FinanceScreen.dashboard => RouteNames.financeDashboard,
        FinanceScreen.feeStructures => RouteNames.financeFeeStructures,
        FinanceScreen.studentAccounts => RouteNames.financeStudentAccounts,
        FinanceScreen.feeAssignment => RouteNames.financeFeeAssignment,
        FinanceScreen.collections => RouteNames.financeCollections,
        FinanceScreen.collectionDetail => RouteNames.financeCollections,
        FinanceScreen.defaulters => RouteNames.financeDefaulters,
        FinanceScreen.refunds => RouteNames.financeRefunds,
        FinanceScreen.discounts => RouteNames.financeDiscounts,
        FinanceScreen.reports => RouteNames.financeReports,
        FinanceScreen.reconciliation => RouteNames.financeReconciliation,
        FinanceScreen.settings => RouteNames.financeSettings,
      };
}

/// Breadcrumbs for a finance screen inside the admin shell.
List<AdminBreadcrumb> financeBreadcrumbs(FinanceScreen screen) {
  return [
    const AdminBreadcrumb(
      label: 'Admin Hub',
      route: RouteNames.admin,
    ),
    const AdminBreadcrumb(
      label: 'Finance',
      route: RouteNames.financeDashboard,
    ),
    AdminBreadcrumb(label: screen.label),
  ];
}

/// Resolves [FinanceScreen] from a router location path.
FinanceScreen? financeScreenForLocation(String location) {
  if (location.startsWith('${RouteNames.financeCollections}/')) {
    return FinanceScreen.collections;
  }
  for (final screen in kFinanceNavScreens) {
    if (location == screen.route) {
      return screen;
    }
  }
  if (location == RouteNames.finance) {
    return FinanceScreen.dashboard;
  }
  return null;
}
