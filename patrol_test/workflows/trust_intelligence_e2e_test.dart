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

      await assertVisibleText($, 'Recommendations');
      await $('Recommendations').tap();
      await $.pumpAndSettle(timeout: const Duration(seconds: 10));
      await assertVisibleText($, 'Finance Lead');

      await $('Executive Summary').tap();
      await $.pumpAndSettle(timeout: const Duration(seconds: 10));
      await assertVisibleText($, 'Trust trajectory remains positive');
    },
  );
}
