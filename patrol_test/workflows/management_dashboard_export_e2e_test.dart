import 'package:patrol/patrol.dart';

import 'package:akshara_erp/core/testing/qa_test_keys.dart';
import 'package:akshara_erp/features/auth/qa_login_persona.dart';
import 'package:akshara_erp/router/route_names.dart';

import '../helpers/patrol_app.dart';
import '../helpers/patrol_helpers.dart';

void main() {
  patrolTest(
    'journey: management dashboard export routes to finance reports',
    config: aksharaPatrolConfig(),
    ($) async {
      await bootstrapAndLogin($, QaLoginPersona.superAdmin);
      await goToErpRoute($, RouteNames.managementDashboard);
      await assertVisibleText($, 'Principal overview');

      await $(QaTestKeys.managementDashboardExportButton).scrollTo().tap();
      await $.pumpAndSettle(timeout: const Duration(seconds: 10));
      await assertVisibleKey(
        $,
        QaTestKeys.managementDashboardExportSuccessSnackbar,
      );
      await assertVisibleText($, 'Management dashboard PDF generated');
    },
  );
}
