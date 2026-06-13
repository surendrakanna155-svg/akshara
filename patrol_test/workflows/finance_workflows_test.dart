import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
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
      await openErpModule($, QaLoginPersona.superAdmin, 'finance');
      await tapModuleSubNav($, 'finance', 'Collections');
      await assertVisibleText($, 'Collected today');
      expect(find.byIcon(Icons.search), findsWidgets);
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
        workflowAnchor: 'Report catalog',
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
