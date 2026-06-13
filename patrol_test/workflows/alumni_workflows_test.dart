import 'package:patrol/patrol.dart';

import 'package:akshara_erp/features/auth/qa_login_persona.dart';

import '../helpers/patrol_helpers.dart';

void main() {
  patrolTest(
    'workflow: alumni dashboard',
    config: aksharaPatrolConfig(),
    ($) async {
      await navigateErpWorkflow(
        $,
        QaLoginPersona.superAdmin,
        'alumni',
        workflowAnchor: 'Recent SIS graduates',
      );
    },
  );

  patrolTest(
    'workflow: alumni registry',
    config: aksharaPatrolConfig(),
    ($) async {
      await navigateErpWorkflow(
        $,
        QaLoginPersona.superAdmin,
        'alumni',
        subNavLabel: 'Registry',
        workflowAnchor: 'Alumni registry',
      );
    },
  );

  patrolTest(
    'workflow: alumni events calendar',
    config: aksharaPatrolConfig(),
    ($) async {
      await navigateErpWorkflow(
        $,
        QaLoginPersona.superAdmin,
        'alumni',
        subNavLabel: 'Events',
        workflowAnchor: 'Event calendar',
      );
    },
  );

  patrolTest(
    'workflow: alumni donations ledger',
    config: aksharaPatrolConfig(),
    ($) async {
      await navigateErpWorkflow(
        $,
        QaLoginPersona.superAdmin,
        'alumni',
        subNavLabel: 'Donations',
        workflowAnchor: 'Donation ledger',
      );
    },
  );

  patrolTest(
    'workflow: alumni fundraising campaigns',
    config: aksharaPatrolConfig(),
    ($) async {
      await navigateErpWorkflow(
        $,
        QaLoginPersona.superAdmin,
        'alumni',
        subNavLabel: 'Campaigns',
        workflowAnchor: 'Fundraising campaigns',
      );
    },
  );

  patrolTest(
    'workflow: alumni mentorship pairs',
    config: aksharaPatrolConfig(),
    ($) async {
      await navigateErpWorkflow(
        $,
        QaLoginPersona.superAdmin,
        'alumni',
        subNavLabel: 'Mentorship',
        workflowAnchor: 'Mentorship pairs',
      );
    },
  );

  patrolTest(
    'workflow: alumni reports',
    config: aksharaPatrolConfig(),
    ($) async {
      await navigateErpWorkflow(
        $,
        QaLoginPersona.superAdmin,
        'alumni',
        subNavLabel: 'Reports',
        workflowAnchor: 'Report catalog',
      );
    },
  );
}
