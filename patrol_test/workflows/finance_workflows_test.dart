import 'package:patrol/patrol.dart';

import 'package:akshara_erp/features/auth/qa_login_persona.dart';

import '../helpers/patrol_helpers.dart';

void main() {
  patrolTest(
    'workflow: finance fee structure create',
    config: aksharaPatrolConfig(),
    ($) async {
      await navigateErpWorkflow(
        $,
        QaLoginPersona.superAdmin,
        'finance',
        subNavLabel: 'Fee Structures',
        workflowAnchor: 'Create structure',
      );
    },
  );

  patrolTest(
    'workflow: finance generate student fee account',
    config: aksharaPatrolConfig(),
    ($) async {
      await navigateErpWorkflow(
        $,
        QaLoginPersona.superAdmin,
        'finance',
        subNavLabel: 'Fee Assignment',
        workflowAnchor: 'Generate student fee account',
      );
    },
  );

  patrolTest(
    'workflow: finance collect fee',
    config: aksharaPatrolConfig(),
    ($) async {
      await navigateErpWorkflow(
        $,
        QaLoginPersona.superAdmin,
        'finance',
        subNavLabel: 'Collections',
        workflowAnchor: 'Collected today',
      );
    },
  );

  patrolTest(
    'workflow: finance verify receipt lookup',
    config: aksharaPatrolConfig(),
    ($) async {
      await navigateErpWorkflow(
        $,
        QaLoginPersona.superAdmin,
        'finance',
        subNavLabel: 'Collections',
        workflowAnchor: 'Receipt lookup',
      );
    },
  );

  patrolTest(
    'workflow: finance report export',
    config: aksharaPatrolConfig(),
    ($) async {
      await navigateErpWorkflow(
        $,
        QaLoginPersona.superAdmin,
        'finance',
        subNavLabel: 'Reports',
        workflowAnchor: 'Export PDF',
      );
    },
  );

  patrolTest(
    'workflow: finance defaulters list',
    config: aksharaPatrolConfig(),
    ($) async {
      await navigateErpWorkflow(
        $,
        QaLoginPersona.superAdmin,
        'finance',
        subNavLabel: 'Defaulters',
        workflowAnchor: 'Defaulters list',
      );
    },
  );
}
