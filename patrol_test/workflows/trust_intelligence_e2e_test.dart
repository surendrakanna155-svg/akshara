import 'package:akshara_erp/core/testing/qa_test_keys.dart';
import 'package:akshara_erp/features/auth/qa_login_persona.dart';
import 'package:akshara_erp/router/route_names.dart';
import 'package:patrol/patrol.dart';

import '../helpers/patrol_app.dart';
import '../helpers/patrol_helpers.dart';

void main() {
  patrolTest(
    'journey: trust intelligence recommendations and summary',
    config: aksharaPatrolConfig(),
    ($) async {
      await bootstrapAndLogin($, QaLoginPersona.superAdmin);
      await goToErpRoute($, RouteNames.organizationIntelligence);
      await assertVisibleKey($, QaTestKeys.trustIntelligenceScreen);

      await tapAppBarTabByIndex($, 5);
      await $.pumpAndSettle(timeout: const Duration(seconds: 15));
      await waitForLoadingToClear($, timeout: const Duration(seconds: 45));
      await assertVisibleText($, 'Drive fee recovery sprint',
          timeout: const Duration(seconds: 30));

      await tapAppBarTabByIndex($, 6);
      await $.pumpAndSettle(timeout: const Duration(seconds: 15));
      await waitForLoadingToClear($, timeout: const Duration(seconds: 45));
      await assertVisibleText(
        $,
        'Trust trajectory remains positive with targeted risk controls.',
        timeout: const Duration(seconds: 30),
      );
    },
  );
}
