import 'package:patrol/patrol.dart';

import 'package:akshara_erp/features/auth/qa_login_persona.dart';

import '../helpers/management_approval_journey_helpers.dart';
import '../helpers/patrol_app.dart';
import '../helpers/patrol_helpers.dart';

void main() {
  patrolTest(
    'journey: management approval E2E',
    config: aksharaPatrolConfig(),
    ($) async {
      await bootstrapAndLogin($, QaLoginPersona.superAdmin);
      await navigateErpWorkflow(
        $,
        QaLoginPersona.superAdmin,
        'management',
        subNavLabel: 'Tasks',
        workflowAnchor: 'Approval queue',
      );
      await approveFirstManagementItem($);
    },
  );
}
