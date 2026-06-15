import 'package:akshara_erp/core/testing/qa_test_keys.dart';
import 'package:akshara_erp/features/auth/qa_login_persona.dart';
import 'package:akshara_erp/router/route_names.dart';
import 'package:patrol/patrol.dart';

import '../helpers/patrol_app.dart';
import '../helpers/patrol_helpers.dart';

void main() {
  patrolTest(
    'journey: inventory replacement workflow approve',
    config: aksharaPatrolConfig(),
    ($) async {
      await bootstrapAndLogin($, QaLoginPersona.superAdmin);
      await goToErpRoute($, RouteNames.inventoryReplacements);
      await assertVisibleKey($, QaTestKeys.inventoryReplacementScreen);
      await assertVisibleText($, 'Pending');

      await $(QaTestKeys.inventoryReplacementApproveButton('rpl_1'))
          .scrollTo()
          .tap();
      await $.pumpAndSettle(timeout: const Duration(seconds: 10));
      await assertVisibleKey(
        $,
        QaTestKeys.inventoryReplacementApproveSuccessSnackbar,
      );
    },
  );
}
