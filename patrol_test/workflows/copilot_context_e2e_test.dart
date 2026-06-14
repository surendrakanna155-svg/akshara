import 'package:patrol/patrol.dart';

import 'package:akshara_erp/core/testing/qa_test_keys.dart';
import 'package:akshara_erp/features/auth/qa_login_persona.dart';
import 'package:akshara_erp/router/route_names.dart';

import '../helpers/patrol_app.dart';
import '../helpers/patrol_helpers.dart';

void main() {
  patrolTest(
    'journey: management dashboard opens context-aware copilot',
    config: aksharaPatrolConfig(),
    ($) async {
      await bootstrapAndLogin($, QaLoginPersona.superAdmin);
      await goToErpRoute($, RouteNames.managementDashboard);
      await assertVisibleText($, 'Revenue (MTD)');

      await $(QaTestKeys.erpCopilotButton).scrollTo().tap();
      await $.pumpAndSettle(timeout: const Duration(seconds: 10));
      await assertVisibleKey($, QaTestKeys.copilotContextBanner);
      await assertVisibleText($, 'Owner Dashboard');

      await $(QaTestKeys.copilotNewConversationButton).scrollTo().tap();
      await $.pumpAndSettle(timeout: const Duration(seconds: 10));

      await $(QaTestKeys.copilotMessageField).enterText('Summarize revenue trends');
      await $(QaTestKeys.copilotSendButton).tap();
      await $.pumpAndSettle(timeout: const Duration(seconds: 10));

      await assertVisibleText($, 'Platform Owner');
      await assertVisibleText($, 'Revenue (MTD)');
    },
  );
}
