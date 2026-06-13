import 'package:patrol/patrol.dart';

import 'package:akshara_erp/features/auth/qa_login_persona.dart';

import '../helpers/patrol_helpers.dart';

void main() {
  patrolTest(
    'workflow: management dashboard',
    config: aksharaPatrolConfig(),
    ($) async {
      await navigateErpWorkflow(
        $,
        QaLoginPersona.superAdmin,
        'management',
        workflowAnchor: 'Principal overview',
      );
    },
  );

  patrolTest(
    'workflow: management analytics enrollment',
    config: aksharaPatrolConfig(),
    ($) async {
      await navigateErpWorkflow(
        $,
        QaLoginPersona.superAdmin,
        'management',
        subNavLabel: 'Analytics',
        workflowAnchor: 'Enrollment trend',
      );
    },
  );

  patrolTest(
    'workflow: management admissions drilldown',
    config: aksharaPatrolConfig(),
    ($) async {
      await navigateErpWorkflow(
        $,
        QaLoginPersona.superAdmin,
        'management',
        subNavLabel: 'Admissions',
        workflowAnchor: 'Funnel stages',
      );
    },
  );

  patrolTest(
    'workflow: management finance drilldown',
    config: aksharaPatrolConfig(),
    ($) async {
      await navigateErpWorkflow(
        $,
        QaLoginPersona.superAdmin,
        'management',
        subNavLabel: 'Finance',
        workflowAnchor: 'Finance module drill-down',
      );
    },
  );

  patrolTest(
    'workflow: management academics',
    config: aksharaPatrolConfig(),
    ($) async {
      await navigateErpWorkflow(
        $,
        QaLoginPersona.superAdmin,
        'management',
        subNavLabel: 'Academics',
        workflowAnchor: 'Academic metrics',
      );
    },
  );

  patrolTest(
    'workflow: management performance',
    config: aksharaPatrolConfig(),
    ($) async {
      await navigateErpWorkflow(
        $,
        QaLoginPersona.superAdmin,
        'management',
        subNavLabel: 'Performance',
        workflowAnchor: 'Class performance',
      );
    },
  );

  patrolTest(
    'workflow: management tasks',
    config: aksharaPatrolConfig(),
    ($) async {
      await navigateErpWorkflow(
        $,
        QaLoginPersona.superAdmin,
        'management',
        subNavLabel: 'Tasks',
        workflowAnchor: 'Approval queue',
      );
    },
  );
}
