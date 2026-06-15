import 'package:patrol/patrol.dart';

import 'package:akshara_erp/features/auth/qa_login_persona.dart';

import '../helpers/patrol_helpers.dart';

void main() {
  patrolTest(
    'journey: finance defaulters aging filters',
    config: aksharaPatrolConfig(),
    ($) async {
      await navigateErpWorkflow(
        $,
        QaLoginPersona.superAdmin,
        'finance',
        subNavLabel: 'Defaulters',
        workflowAnchor: 'Aging buckets',
      );
      await $('31–60d').scrollTo().tap();
      await $.pumpAndSettle(timeout: const Duration(seconds: 8));
      await assertVisibleText($, 'Aging buckets');
    },
  );
}
