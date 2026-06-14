import 'package:akshara_erp/features/auth/qa_login_persona.dart';
import 'package:patrol/patrol.dart';

import '../helpers/patrol_helpers.dart';

void main() {
  patrolTest(
    'workflow: management workflow automation',
    config: aksharaPatrolConfig(),
    ($) async {
      await navigateErpWorkflow(
        $,
        QaLoginPersona.superAdmin,
        'management',
        subNavLabel: 'Workflow',
        workflowAnchor: 'Workflow Automation Platform',
      );
      await assertVisibleText($, 'Rules');
      await assertVisibleText($, 'Active');
      await assertVisibleText($, 'Escalations');
      await assertVisibleText($, 'Schedule');
    },
  );
}
