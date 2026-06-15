import 'package:patrol/patrol.dart';

import 'package:akshara_erp/features/auth/qa_login_persona.dart';

import '../helpers/patrol_helpers.dart';

void main() {
  patrolTest(
    'workflow: control center platform intelligence tabs',
    config: aksharaPatrolConfig(),
    ($) async {
      await navigateErpWorkflow(
        $,
        QaLoginPersona.superAdmin,
        'controlCenter',
        subNavLabel: 'Intelligence',
        workflowAnchor: 'Platform Owner',
      );
      await assertVisibleText($, 'School Comparison');
      await assertVisibleText($, 'Revenue');
      await assertVisibleText($, 'Risk');
    },
  );
}
