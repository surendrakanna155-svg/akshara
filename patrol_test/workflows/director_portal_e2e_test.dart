import 'package:akshara_erp/core/testing/qa_test_keys.dart';
import 'package:akshara_erp/features/auth/qa_login_persona.dart';
import 'package:akshara_erp/router/route_names.dart';
import 'package:patrol/patrol.dart';

import '../helpers/patrol_app.dart';
import '../helpers/patrol_helpers.dart';

void main() {
  patrolTest(
    'workflow: director portal dashboard and reports',
    config: aksharaPatrolConfig(),
    ($) async {
      await bootstrapAndLogin($, QaLoginPersona.superAdmin);
      await goToErpRoute($, RouteNames.directorReports);
      await waitForLoadingToClear($, timeout: const Duration(seconds: 45));
      await tapByKey($, QaTestKeys.directorReportsGenerateSummaryButton);
      await $.pumpAndSettle(timeout: const Duration(seconds: 12));
      await assertVisibleKey($, QaTestKeys.directorExecutiveSummaryCard);

      await tapByKey($, QaTestKeys.directorReportExportButton('rpt-1'));
      await $.pumpAndSettle(timeout: const Duration(seconds: 8));
      await assertVisibleKey($, QaTestKeys.directorReportExportedSnackbar);
    },
  );
}
