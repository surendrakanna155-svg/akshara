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
      await waitForLoadingToClear($);
      await assertVisibleKey(
        $,
        QaTestKeys.resourceOptimizationApplyButton('staffing_balance_load'),
        timeout: const Duration(seconds: 45),
      );
      await tapByKey(
        $,
        QaTestKeys.resourceOptimizationApplyButton('staffing_balance_load'),
      );
      await $.pumpAndSettle(timeout: const Duration(seconds: 10));
      await assertSnackBarText($, 'Optimization recommendation applied');

      await tapByKey(
        $,
        QaTestKeys.resourceOptimizationDismissButton('staffing_reduce_idle'),
      );
      await $.pumpAndSettle(timeout: const Duration(seconds: 10));
      await assertSnackBarText($, 'Optimization recommendation dismissed');
    },
  );
}
