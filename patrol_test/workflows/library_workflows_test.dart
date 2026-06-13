import 'package:patrol/patrol.dart';

import 'package:akshara_erp/features/auth/qa_login_persona.dart';

import '../helpers/patrol_helpers.dart';

void main() {
  patrolTest(
    'workflow: library dashboard recent issues',
    config: aksharaPatrolConfig(),
    ($) async {
      await navigateErpWorkflow(
        $,
        QaLoginPersona.superAdmin,
        'library',
        workflowAnchor: 'Recent issues',
      );
    },
  );

  patrolTest(
    'workflow: library catalog add book',
    config: aksharaPatrolConfig(),
    ($) async {
      await navigateErpWorkflow(
        $,
        QaLoginPersona.superAdmin,
        'library',
        subNavLabel: 'Catalog',
        workflowAnchor: 'Add book',
      );
    },
  );

  patrolTest(
    'workflow: library issue books',
    config: aksharaPatrolConfig(),
    ($) async {
      await navigateErpWorkflow(
        $,
        QaLoginPersona.superAdmin,
        'library',
        subNavLabel: 'Issue',
        workflowAnchor: 'Issue books',
      );
    },
  );

  patrolTest(
    'workflow: library return books',
    config: aksharaPatrolConfig(),
    ($) async {
      await navigateErpWorkflow(
        $,
        QaLoginPersona.superAdmin,
        'library',
        subNavLabel: 'Returns',
        workflowAnchor: 'Return books',
      );
    },
  );

  patrolTest(
    'workflow: library members',
    config: aksharaPatrolConfig(),
    ($) async {
      await navigateErpWorkflow(
        $,
        QaLoginPersona.superAdmin,
        'library',
        subNavLabel: 'Members',
        workflowAnchor: 'Library members',
      );
    },
  );

  patrolTest(
    'workflow: library overdue fines',
    config: aksharaPatrolConfig(),
    ($) async {
      await navigateErpWorkflow(
        $,
        QaLoginPersona.superAdmin,
        'library',
        subNavLabel: 'Fines',
        workflowAnchor: 'Overdue fines',
      );
    },
  );

  patrolTest(
    'workflow: library digital resources',
    config: aksharaPatrolConfig(),
    ($) async {
      await navigateErpWorkflow(
        $,
        QaLoginPersona.superAdmin,
        'library',
        subNavLabel: 'Digital',
        workflowAnchor: 'Digital resources',
      );
    },
  );

  patrolTest(
    'workflow: library reports',
    config: aksharaPatrolConfig(),
    ($) async {
      await navigateErpWorkflow(
        $,
        QaLoginPersona.superAdmin,
        'library',
        subNavLabel: 'Reports',
        workflowAnchor: 'Report catalog',
      );
    },
  );
}
