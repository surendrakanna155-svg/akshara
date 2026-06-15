import 'package:akshara_erp/core/testing/qa_test_keys.dart';
import 'package:akshara_erp/features/auth/qa_login_persona.dart';
import 'package:akshara_erp/router/route_names.dart';
import 'package:patrol/patrol.dart';

import '../helpers/patrol_helpers.dart';

void main() {
  patrolTest(
    'workflow: director portal dashboard and reports',
    config: aksharaPatrolConfig(),
    ($) async {
      await navigateErpModuleRoute(
        $,
        QaLoginPersona.superAdmin,
        RouteNames.directorDashboard,
        screenKey: QaTestKeys.directorDashboardScreen,
        workflowAnchor: 'School portfolio health',
      );

      await goToErpRoute($, RouteNames.directorReports);
      await $(QaTestKeys.directorReportsGenerateSummaryButton).scrollTo().tap();
      await $.pumpAndSettle(timeout: const Duration(seconds: 12));
      await assertVisibleKey($, QaTestKeys.directorExecutiveSummaryCard);

      await $(QaTestKeys.directorReportExportButton('rpt-1')).scrollTo().tap();
      await $.pumpAndSettle(timeout: const Duration(seconds: 8));
      await assertVisibleKey($, QaTestKeys.directorReportExportedSnackbar);
    },
  );
}
