import 'package:patrol/patrol.dart';

import 'package:akshara_erp/features/auth/qa_login_persona.dart';

import '../helpers/patrol_helpers.dart';

void main() {
  patrolTest(
    'journey: management tasks pending filter',
    config: aksharaPatrolConfig(),
    ($) async {
      await navigateErpWorkflow(
        $,
        QaLoginPersona.superAdmin,
        'management',
        subNavLabel: 'Tasks',
        workflowAnchor: 'Approval queue',
      );
      await $('Pending').scrollTo().tap();
      await $.pumpAndSettle(timeout: const Duration(seconds: 8));
      await assertVisibleText($, 'Approval queue');
    },
  );
}
