import 'package:akshara_erp/core/testing/qa_test_keys.dart';
import 'package:akshara_erp/features/auth/qa_login_persona.dart';
import 'package:akshara_erp/router/route_names.dart';
import 'package:patrol/patrol.dart';

import '../helpers/patrol_helpers.dart';

void main() {
  patrolTest(
    'workflow: parent meeting summary',
    config: aksharaPatrolConfig(),
    ($) async {
      await navigateErpModuleRoute(
        $,
        QaLoginPersona.superAdmin,
        RouteNames.parentMeetings,
        screenKey: QaTestKeys.parentMeetingsScreen,
        workflowAnchor: 'Parent Meeting Summary',
      );

      await $(QaTestKeys.parentMeetingTile('pm_1')).tap();
      await $.pumpAndSettle(timeout: const Duration(seconds: 10));
      await assertVisibleText($, 'AI Summary');
    },
  );
}
