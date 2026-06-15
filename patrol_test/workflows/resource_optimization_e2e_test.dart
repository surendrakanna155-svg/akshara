import 'package:akshara_erp/core/testing/qa_test_keys.dart';
import 'package:akshara_erp/features/auth/qa_login_persona.dart';
import 'package:akshara_erp/router/route_names.dart';
import 'package:patrol/patrol.dart';

import '../helpers/patrol_app.dart';
import '../helpers/patrol_helpers.dart';

void main() {
  patrolTest(
    'journey: resource optimization apply and dismiss',
    config: aksharaPatrolConfig(),
    ($) async {
      await bootstrapAndLogin($, QaLoginPersona.superAdmin);
      await goToErpRoute($, RouteNames.resourceOptimization);

      await assertVisibleText($, 'Resource Optimization Engine');
      await $(QaTestKeys.resourceOptimizationApplyButton(
              'staffing_balance_load'))
          .scrollTo()
          .tap();
      await $.pumpAndSettle(timeout: const Duration(seconds: 10));
      await assertVisibleKey($, QaTestKeys.resourceOptimizationAppliedSnackbar);

      await $(QaTestKeys.resourceOptimizationDismissButton(
              'staffing_reduce_idle'))
          .scrollTo()
          .tap();
      await $.pumpAndSettle(timeout: const Duration(seconds: 10));
      await assertVisibleKey(
          $, QaTestKeys.resourceOptimizationDismissedSnackbar);
    },
  );
}
