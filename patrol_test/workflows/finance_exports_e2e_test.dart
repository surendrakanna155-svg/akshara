import 'package:akshara_erp/core/testing/qa_test_keys.dart';
import 'package:akshara_erp/features/auth/qa_login_persona.dart';
import 'package:akshara_erp/router/route_names.dart';
import 'package:patrol/patrol.dart';

import '../helpers/patrol_app.dart';
import '../helpers/patrol_helpers.dart';

void main() {
  patrolTest(
    'journey: finance reports export PDF',
    config: aksharaPatrolConfig(),
    ($) async {
      await bootstrapAndLogin($, QaLoginPersona.superAdmin);
      await goToErpRoute($, RouteNames.financeReports);
      await waitForLoadingToClear($, timeout: const Duration(seconds: 30));
      await scrollModuleBody($, 'Export PDF');
      await tapByKey($, QaTestKeys.financeReportExportPdfButton);
      await $.pumpAndSettle(timeout: const Duration(seconds: 8));
      await assertVisibleKey($, QaTestKeys.financeReportExportSuccessSnackbar);
    },
  );
}
