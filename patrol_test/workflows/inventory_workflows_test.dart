import 'package:patrol/patrol.dart';

import 'package:akshara_erp/core/testing/qa_test_keys.dart';
import 'package:akshara_erp/features/auth/qa_login_persona.dart';
import 'package:akshara_erp/router/route_names.dart';

import '../helpers/patrol_helpers.dart';

void main() {
  patrolTest(
    'workflow: inventory assets registry',
    config: aksharaPatrolConfig(),
    ($) async {
      await navigateErpWorkflow(
        $,
        QaLoginPersona.superAdmin,
        'inventory',
        subNavLabel: 'Assets',
        workflowAnchor: 'Asset registry',
      );
    },
  );

  patrolTest(
    'workflow: inventory asset allocation',
    config: aksharaPatrolConfig(),
    ($) async {
      await navigateErpWorkflow(
        $,
        QaLoginPersona.superAdmin,
        'inventory',
        subNavLabel: 'Allocation',
        workflowAnchor: 'Asset allocation',
      );
    },
  );

  patrolTest(
    'workflow: inventory report catalog',
    config: aksharaPatrolConfig(),
    ($) async {
      await navigateErpWorkflow(
        $,
        QaLoginPersona.superAdmin,
        'inventory',
        subNavLabel: 'Reports',
        workflowAnchor: 'Report catalog',
      );
    },
  );

  patrolTest(
    'workflow: inventory procurement orders',
    config: aksharaPatrolConfig(),
    ($) async {
      await navigateErpWorkflow(
        $,
        QaLoginPersona.superAdmin,
        'inventory',
        subNavLabel: 'Procurement',
        workflowAnchor: 'Purchase orders',
      );
    },
  );

  patrolTest(
    'workflow: inventory distribution lifecycle',
    config: aksharaPatrolConfig(),
    ($) async {
      await navigateErpModuleRoute(
        $,
        QaLoginPersona.superAdmin,
        RouteNames.inventoryLifecycle,
        screenKey: QaTestKeys.inventoryLifecycleScreen,
        workflowAnchor: 'Assets tracked',
      );
    },
  );
}
