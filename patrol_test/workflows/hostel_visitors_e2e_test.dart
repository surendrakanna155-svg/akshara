import 'package:patrol/patrol.dart';

import 'package:akshara_erp/features/auth/qa_login_persona.dart';

import '../helpers/patrol_helpers.dart';

void main() {
  patrolTest(
    'journey: hostel visitors register action',
    config: aksharaPatrolConfig(),
    ($) async {
      await navigateErpWorkflow(
        $,
        QaLoginPersona.superAdmin,
        'hostel',
        subNavLabel: 'Visitors',
        workflowAnchor: 'Active visitors',
      );
      await assertVisibleText($, 'Register visitor');
      await assertVisibleText($, 'Visitor log');
    },
  );
}
