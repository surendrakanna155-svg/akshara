import 'package:patrol/patrol.dart';

import 'package:akshara_erp/core/testing/qa_test_keys.dart';
import 'package:akshara_erp/features/auth/qa_login_persona.dart';
import 'package:akshara_erp/router/route_names.dart';

import '../helpers/patrol_app.dart';
import '../helpers/patrol_helpers.dart';

void main() {
  patrolTest(
    'journey: finance persona uses universal AI assistant',
    config: aksharaPatrolConfig(),
    ($) async {
      await bootstrapAndLogin($, QaLoginPersona.finance);
      await goToErpRoute($, RouteNames.aiAssistant);
      await $.pumpAndSettle(timeout: const Duration(seconds: 10));

      await assertVisibleText($, 'Finance Intelligence');
      await assertVisibleKey($, QaTestKeys.universalAiAssistantStreamingToggle);

      await $('Summarize collection risk for this month').scrollTo().tap();
      await $.pumpAndSettle(timeout: const Duration(seconds: 10));

      await assertVisibleKey($, QaTestKeys.copilotPersonaReplyPanel);
      await assertVisibleText($, 'Finance Copilot');
    },
  );
}
