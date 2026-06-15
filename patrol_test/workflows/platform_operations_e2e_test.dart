import 'package:akshara_erp/core/testing/qa_test_keys.dart';
import 'package:akshara_erp/features/auth/qa_login_persona.dart';
import 'package:akshara_erp/router/route_names.dart';
import 'package:patrol/patrol.dart';

import '../helpers/patrol_app.dart';
import '../helpers/patrol_helpers.dart';

void main() {
  patrolTest(
    'journey: platform operations hub tabs and acknowledge alert',
    config: aksharaPatrolConfig(),
    ($) async {
      await bootstrapAndLogin($, QaLoginPersona.superAdmin);
      await goToErpRoute($, RouteNames.platformOperations);

      await assertVisibleKey($, QaTestKeys.platformOperationsHubScreen);
      await assertVisibleKey($, QaTestKeys.platformOperationsOverviewTab);

      await tapAppBarTab($, tabKey: QaTestKeys.platformOperationsAlertsTab);
      await assertVisibleKey(
        $,
        QaTestKeys.platformOperationsAcknowledgeAlertButton('plat_alert_1'),
      );
      await tapByKey(
        $,
        QaTestKeys.platformOperationsAcknowledgeAlertButton('plat_alert_1'),
        scrollFirst: false,
      );
      await $.pumpAndSettle(timeout: const Duration(seconds: 10));
      await assertVisibleKey(
        $,
        QaTestKeys.platformOperationsAlertAcknowledgedSnackbar,
      );

      await tapAppBarTab($, tabKey: QaTestKeys.platformOperationsReadinessTab);
      await $.pumpAndSettle(timeout: const Duration(seconds: 10));
      await $('Production Readiness').waitUntilVisible();
    },
  );
}
