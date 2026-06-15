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

      await $(QaTestKeys.parentMeetingsCreateButton).tap();
      await $.pumpAndSettle(timeout: const Duration(seconds: 5));
      await $(QaTestKeys.parentMeetingsStudentIdField).enterText('STU_3044');
      await $(QaTestKeys.parentMeetingsStudentNameField).enterText('Ria Menon');
      await $(QaTestKeys.parentMeetingsParentNameField).enterText('Anil Menon');
      await $(QaTestKeys.parentMeetingsTeacherNameField).enterText('Ms. Nisha');
      await $(QaTestKeys.parentMeetingsCreateSubmitButton).tap();
      await $.pumpAndSettle(timeout: const Duration(seconds: 8));

      await assertVisibleText($, 'Ria Menon');
      await $(QaTestKeys.parentMeetingTile('pm_2')).tap();
      await $.pumpAndSettle(timeout: const Duration(seconds: 8));

      await $(QaTestKeys.parentMeetingsGenerateSummaryButton).tap();
      await $.pumpAndSettle(timeout: const Duration(seconds: 12));
      await assertVisibleText($, 'AI Summary');
    },
  );
}
