import 'package:akshara_erp/core/testing/qa_test_keys.dart';
import 'package:akshara_erp/features/auth/qa_login_persona.dart';
import 'package:akshara_erp/router/route_names.dart';
import 'package:patrol/patrol.dart';

import '../helpers/patrol_helpers.dart';

void main() {
  patrolTest(
    'workflow: communication broadcast admin send',
    config: aksharaPatrolConfig(),
    ($) async {
      await navigateErpModuleRoute(
        $,
        QaLoginPersona.superAdmin,
        RouteNames.communicationBroadcastAdmin,
        screenKey: QaTestKeys.communicationBroadcastAdminScreen,
        workflowAnchor: 'Broadcast Admin',
      );

      await $('Title').enterText('Emergency notice');
      await $('Body').enterText('School closes early due to weather alert.');
      await $(QaTestKeys.communicationBroadcastSendButton).tap();
      await $.pumpAndSettle(timeout: const Duration(seconds: 10));
      await assertVisibleText($, 'Broadcast sent to');
    },
  );
}
