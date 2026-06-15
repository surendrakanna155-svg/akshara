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
      await assertVisibleText($, 'Principal overview');

      await openCopilotViaFloatingDock($);
      await assertVisibleKey(
        $,
        QaTestKeys.copilotNewConversationButton,
        timeout: const Duration(seconds: 45),
      );
      await assertVisibleKey($, QaTestKeys.copilotContextBanner);
    },
  );
}
