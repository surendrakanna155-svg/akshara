import 'package:patrol/patrol.dart';

import 'package:akshara_erp/core/testing/qa_test_keys.dart';
import 'package:akshara_erp/features/auth/qa_login_persona.dart';
import 'package:akshara_erp/router/route_names.dart';

import '../helpers/patrol_app.dart';
import '../helpers/patrol_helpers.dart';

void main() {
  patrolTest(
    'journey: AI assistant settings saves access mode preference',
    config: aksharaPatrolConfig(),
    ($) async {
      await bootstrapAndLogin($, QaLoginPersona.parent);
      await goToErpRoute($, RouteNames.parentProfile);

      await $(QaTestKeys.aiAssistantSettingsLink).scrollTo().tap();
      await $.pumpAndSettle(timeout: const Duration(seconds: 10));

      await $(QaTestKeys.aiAccessModeOption('floating_bubble')).tap();
      await $.pumpAndSettle();

      await $(QaTestKeys.aiAccessFloatingBubbleToggle).tap();
      await $.pumpAndSettle();

      await assertVisibleKey($, QaTestKeys.aiAccessSyncNote);
      await assertVisibleText($, 'Floating bubble');
    },
  );
}
