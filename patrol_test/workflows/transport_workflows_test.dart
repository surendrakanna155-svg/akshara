import 'package:patrol/patrol.dart';

import 'package:akshara_erp/features/auth/qa_login_persona.dart';

import '../helpers/patrol_helpers.dart';

void main() {
  patrolTest(
    'workflow: transport fleet dashboard',
    config: aksharaPatrolConfig(),
    ($) async {
      await navigateErpWorkflow(
        $,
        QaLoginPersona.superAdmin,
        'transport',
        workflowAnchor: 'Live fleet assignments',
      );
    },
  );

  patrolTest(
    'workflow: transport route catalog',
    config: aksharaPatrolConfig(),
    ($) async {
      await navigateErpWorkflow(
        $,
        QaLoginPersona.superAdmin,
        'transport',
        subNavLabel: 'Routes',
        workflowAnchor: 'Route catalog',
      );
    },
  );

  patrolTest(
    'workflow: transport new route button',
    config: aksharaPatrolConfig(),
    ($) async {
      await navigateErpWorkflow(
        $,
        QaLoginPersona.superAdmin,
        'transport',
        subNavLabel: 'Routes',
        workflowAnchor: 'New route',
      );
    },
  );

  patrolTest(
    'workflow: transport vehicle registry',
    config: aksharaPatrolConfig(),
    ($) async {
      await navigateErpWorkflow(
        $,
        QaLoginPersona.superAdmin,
        'transport',
        subNavLabel: 'Vehicles',
        workflowAnchor: 'Vehicle registry',
      );
    },
  );

  patrolTest(
    'workflow: transport driver roster',
    config: aksharaPatrolConfig(),
    ($) async {
      await navigateErpWorkflow(
        $,
        QaLoginPersona.superAdmin,
        'transport',
        subNavLabel: 'Drivers',
        workflowAnchor: 'Driver roster',
      );
    },
  );

  patrolTest(
    'workflow: transport student allocation',
    config: aksharaPatrolConfig(),
    ($) async {
      await navigateErpWorkflow(
        $,
        QaLoginPersona.superAdmin,
        'transport',
        subNavLabel: 'Allocation',
        workflowAnchor: 'Student transport allocation',
      );
    },
  );

  patrolTest(
    'workflow: transport pickup attendance',
    config: aksharaPatrolConfig(),
    ($) async {
      await navigateErpWorkflow(
        $,
        QaLoginPersona.superAdmin,
        'transport',
        subNavLabel: 'Attendance',
        workflowAnchor: 'AM pickup attendance',
      );
    },
  );

  patrolTest(
    'workflow: transport vehicle telemetry',
    config: aksharaPatrolConfig(),
    ($) async {
      await navigateErpWorkflow(
        $,
        QaLoginPersona.superAdmin,
        'transport',
        subNavLabel: 'Tracking',
        workflowAnchor: 'Vehicle telemetry',
      );
    },
  );

  patrolTest(
    'workflow: transport reports',
    config: aksharaPatrolConfig(),
    ($) async {
      await navigateErpWorkflow(
        $,
        QaLoginPersona.superAdmin,
        'transport',
        subNavLabel: 'Reports',
        workflowAnchor: 'Report catalog',
      );
    },
  );
}
