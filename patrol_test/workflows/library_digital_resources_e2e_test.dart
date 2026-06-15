import 'package:patrol/patrol.dart';

import 'package:akshara_erp/features/auth/qa_login_persona.dart';

import '../helpers/patrol_helpers.dart';

void main() {
  patrolTest(
    'journey: library digital resources filters',
    config: aksharaPatrolConfig(),
    ($) async {
      await navigateErpWorkflow(
        $,
        QaLoginPersona.superAdmin,
        'library',
        subNavLabel: 'Digital',
        workflowAnchor: 'Digital resources',
      );
      await $('Student app').scrollTo().tap();
      await $.pumpAndSettle(timeout: const Duration(seconds: 8));
      await assertVisibleText($, 'Digital resources');
    },
  );
}
