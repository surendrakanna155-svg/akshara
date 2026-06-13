import 'package:patrol/patrol.dart';

import 'package:akshara_erp/features/auth/qa_login_persona.dart';

import '../helpers/patrol_helpers.dart';

void main() {
  patrolTest(
    'workflow: control center module adoption',
    config: aksharaPatrolConfig(),
    ($) async {
      await navigateErpWorkflow(
        $,
        QaLoginPersona.superAdmin,
        'controlCenter',
        workflowAnchor: 'ERP module adoption',
      );
    },
  );

  patrolTest(
    'workflow: control center create school',
    config: aksharaPatrolConfig(),
    ($) async {
      await navigateErpWorkflow(
        $,
        QaLoginPersona.superAdmin,
        'controlCenter',
        subNavLabel: 'Schools',
        workflowAnchor: 'Create school',
      );
    },
  );

  patrolTest(
    'workflow: control center subscriptions',
    config: aksharaPatrolConfig(),
    ($) async {
      await navigateErpWorkflow(
        $,
        QaLoginPersona.superAdmin,
        'controlCenter',
        subNavLabel: 'Subscriptions',
        workflowAnchor: 'Subscription plans',
      );
    },
  );

  patrolTest(
    'workflow: control center billing',
    config: aksharaPatrolConfig(),
    ($) async {
      await navigateErpWorkflow(
        $,
        QaLoginPersona.superAdmin,
        'controlCenter',
        subNavLabel: 'Billing',
        workflowAnchor: 'Platform revenue',
      );
    },
  );

  patrolTest(
    'workflow: control center crm pipeline',
    config: aksharaPatrolConfig(),
    ($) async {
      await navigateErpWorkflow(
        $,
        QaLoginPersona.superAdmin,
        'controlCenter',
        subNavLabel: 'CRM',
        workflowAnchor: 'Sales pipeline',
      );
    },
  );

  patrolTest(
    'workflow: control center support tickets',
    config: aksharaPatrolConfig(),
    ($) async {
      await navigateErpWorkflow(
        $,
        QaLoginPersona.superAdmin,
        'controlCenter',
        subNavLabel: 'Support',
        workflowAnchor: 'Support tickets',
      );
    },
  );

  patrolTest(
    'workflow: control center monitoring',
    config: aksharaPatrolConfig(),
    ($) async {
      await navigateErpWorkflow(
        $,
        QaLoginPersona.superAdmin,
        'controlCenter',
        subNavLabel: 'Monitoring',
        workflowAnchor: 'Feature flags',
      );
    },
  );

  patrolTest(
    'workflow: control center platform roles',
    config: aksharaPatrolConfig(),
    ($) async {
      await navigateErpWorkflow(
        $,
        QaLoginPersona.superAdmin,
        'controlCenter',
        subNavLabel: 'Roles',
        workflowAnchor: 'Platform roles',
      );
    },
  );
}
