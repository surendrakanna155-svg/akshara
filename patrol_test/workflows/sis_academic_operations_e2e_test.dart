import 'package:patrol/patrol.dart';

import 'package:akshara_erp/features/auth/qa_login_persona.dart';

import '../helpers/patrol_helpers.dart';

void main() {
  patrolTest(
    'workflow: sis promotion preview',
    config: aksharaPatrolConfig(),
    ($) async {
      await navigateErpWorkflow(
        $,
        QaLoginPersona.superAdmin,
        'sis',
        subNavLabel: 'Promotion',
        workflowAnchor: 'Promotion wizard',
      );
      await scrollTap($, 'Continue');
      await assertVisibleText($, 'Confirm class mapping rules');
    },
  );

  patrolTest(
    'workflow: sis reshuffle preview',
    config: aksharaPatrolConfig(),
    ($) async {
      await navigateErpWorkflow(
        $,
        QaLoginPersona.superAdmin,
        'sis',
        subNavLabel: 'Reshuffle',
        workflowAnchor: 'Student reshuffle',
      );
      await assertVisibleText($, 'Execute reshuffle');
    },
  );

  patrolTest(
    'workflow: sis section balance tabs',
    config: aksharaPatrolConfig(),
    ($) async {
      await navigateErpWorkflow(
        $,
        QaLoginPersona.superAdmin,
        'sis',
        subNavLabel: 'Section Balance',
        workflowAnchor: 'Section Balance',
      );
      await assertVisibleText($, 'Quarterly');
      await assertVisibleText($, 'Performance');
    },
  );
}
