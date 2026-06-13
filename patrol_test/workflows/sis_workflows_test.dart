import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';

import 'package:akshara_erp/features/auth/qa_login_persona.dart';

import '../helpers/patrol_helpers.dart';

void main() {
  patrolTest(
    'workflow: sis search student',
    config: aksharaPatrolConfig(),
    ($) async {
      await openErpModule($, QaLoginPersona.superAdmin, 'sis');
      await tapModuleSubNav($, 'sis', 'Student Registry');
      await assertVisibleText($, 'Export');
      expect(find.byIcon(Icons.search), findsWidgets);
      await scrollTap($, 'Export');
      await assertVisibleText($, 'Export');
    },
  );

  patrolTest(
    'workflow: sis student registry export',
    config: aksharaPatrolConfig(),
    ($) async {
      await navigateErpWorkflow(
        $,
        QaLoginPersona.superAdmin,
        'sis',
        subNavLabel: 'Student Registry',
        workflowAnchor: 'Export',
      );
    },
  );

  patrolTest(
    'workflow: sis promote student',
    config: aksharaPatrolConfig(),
    ($) async {
      await navigateErpWorkflow(
        $,
        QaLoginPersona.superAdmin,
        'sis',
        subNavLabel: 'Academic Assignment',
        workflowAnchor: 'Promote',
      );
    },
  );

  patrolTest(
    'workflow: sis admissions conversion',
    config: aksharaPatrolConfig(),
    ($) async {
      await navigateErpWorkflow(
        $,
        QaLoginPersona.superAdmin,
        'sis',
        subNavLabel: 'Admissions Conversion',
        workflowAnchor: 'Admissions conversion',
      );
    },
  );

  patrolTest(
    'workflow: sis dashboard totals',
    config: aksharaPatrolConfig(),
    ($) async {
      await navigateErpWorkflow(
        $,
        QaLoginPersona.principal,
        'sis',
        workflowAnchor: 'Total Students',
      );
    },
  );

  patrolTest(
    'workflow: sis registry filter active',
    config: aksharaPatrolConfig(),
    ($) async {
      await openErpModule($, QaLoginPersona.principal, 'sis');
      await tapModuleSubNav($, 'sis', 'Student Registry');
      await assertVisibleText($, 'Active');
      await assertVisibleText($, 'Prospect');
    },
  );
}
