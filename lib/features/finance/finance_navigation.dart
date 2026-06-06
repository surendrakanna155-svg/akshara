import '../admin/models/admin_nav_models.dart';
import '../../router/route_names.dart';
import 'finance_models.dart';

/// Primary finance sub-navigation tabs (FN-01 → FN-05).
const List<FinanceScreen> kFinanceNavScreens = [
  FinanceScreen.dashboard,
  FinanceScreen.feeStructures,
  FinanceScreen.studentAccounts,
  FinanceScreen.feeAssignment,
  FinanceScreen.collections,
];

extension FinanceScreenRoutes on FinanceScreen {
  String get route => switch (this) {
        FinanceScreen.dashboard => RouteNames.financeDashboard,
        FinanceScreen.feeStructures => RouteNames.financeFeeStructures,
        FinanceScreen.studentAccounts => RouteNames.financeStudentAccounts,
        FinanceScreen.feeAssignment => RouteNames.financeFeeAssignment,
        FinanceScreen.collections => RouteNames.financeCollections,
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
  for (final screen in FinanceScreen.values) {
    if (location == screen.route || location.startsWith('${screen.route}/')) {
      return screen;
    }
  }
  if (location == RouteNames.finance) {
    return FinanceScreen.dashboard;
  }
  return null;
}
