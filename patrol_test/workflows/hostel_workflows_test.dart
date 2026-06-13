import 'package:patrol/patrol.dart';

import 'package:akshara_erp/features/auth/qa_login_persona.dart';

import '../helpers/patrol_helpers.dart';

void main() {
  patrolTest(
    'workflow: hostel occupancy dashboard',
    config: aksharaPatrolConfig(),
    ($) async {
      await navigateErpWorkflow(
        $,
        QaLoginPersona.superAdmin,
        'hostel',
        workflowAnchor: 'Occupancy',
      );
    },
  );

  patrolTest(
    'workflow: hostel residents',
    config: aksharaPatrolConfig(),
    ($) async {
      await navigateErpWorkflow(
        $,
        QaLoginPersona.superAdmin,
        'hostel',
        subNavLabel: 'Students',
        workflowAnchor: 'Hostel residents',
      );
    },
  );

  patrolTest(
    'workflow: hostel room catalog',
    config: aksharaPatrolConfig(),
    ($) async {
      await navigateErpWorkflow(
        $,
        QaLoginPersona.superAdmin,
        'hostel',
        subNavLabel: 'Rooms',
        workflowAnchor: 'Room catalog',
      );
    },
  );

  patrolTest(
    'workflow: hostel attendance roster',
    config: aksharaPatrolConfig(),
    ($) async {
      await navigateErpWorkflow(
        $,
        QaLoginPersona.superAdmin,
        'hostel',
        subNavLabel: 'Attendance',
        workflowAnchor: 'Hostel attendance roster',
      );
    },
  );

  patrolTest(
    'workflow: hostel leave requests',
    config: aksharaPatrolConfig(),
    ($) async {
      await navigateErpWorkflow(
        $,
        QaLoginPersona.superAdmin,
        'hostel',
        subNavLabel: 'Leave',
        workflowAnchor: 'Leave requests',
      );
    },
  );

  patrolTest(
    'workflow: hostel mess menu',
    config: aksharaPatrolConfig(),
    ($) async {
      await navigateErpWorkflow(
        $,
        QaLoginPersona.superAdmin,
        'hostel',
        subNavLabel: 'Mess',
        workflowAnchor: 'Weekly menu',
      );
    },
  );

  patrolTest(
    'workflow: hostel visitors register',
    config: aksharaPatrolConfig(),
    ($) async {
      await navigateErpWorkflow(
        $,
        QaLoginPersona.superAdmin,
        'hostel',
        subNavLabel: 'Visitors',
        workflowAnchor: 'Register visitor',
      );
    },
  );

  patrolTest(
    'workflow: hostel reports',
    config: aksharaPatrolConfig(),
    ($) async {
      await navigateErpWorkflow(
        $,
        QaLoginPersona.superAdmin,
        'hostel',
        subNavLabel: 'Reports',
        workflowAnchor: 'Report catalog',
      );
    },
  );
}
