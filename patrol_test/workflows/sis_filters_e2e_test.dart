import 'package:akshara_erp/core/testing/qa_test_keys.dart';
import 'package:patrol/patrol.dart';

import 'package:akshara_erp/features/auth/qa_login_persona.dart';

import '../helpers/patrol_helpers.dart';

void main() {
  patrolTest(
    'journey: sis registry active filter and search',
    config: aksharaPatrolConfig(),
    ($) async {
      await navigateErpWorkflow(
        $,
        QaLoginPersona.superAdmin,
        'sis',
        subNavLabel: 'Student Registry',
        workflowAnchor: 'Export',
      );
      await $('Active').scrollTo().tap();
      await $.pumpAndSettle(timeout: const Duration(seconds: 8));
      await $(QaTestKeys.sisRegistrySearchField).enterText('Arjun');
      await $.pumpAndSettle(timeout: const Duration(seconds: 8));
      await assertVisibleText($, 'Export');
    },
  );
}
