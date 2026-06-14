import 'package:patrol/patrol.dart';

import 'package:akshara_erp/features/auth/qa_login_persona.dart';

import '../helpers/patrol_helpers.dart';

void main() {
  patrolTest(
    'workflow: sis continuity migration',
    config: aksharaPatrolConfig(),
    ($) async {
      await navigateErpWorkflow(
        $,
        QaLoginPersona.superAdmin,
        'sis',
        subNavLabel: 'Continuity',
        workflowAnchor: 'Continuity migration wizard',
      );
      await assertVisibleText($, 'Preview continuity');
      await assertVisibleText($, 'Execute continuity');
    },
  );
}
