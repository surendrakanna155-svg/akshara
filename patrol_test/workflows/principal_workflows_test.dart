import 'package:patrol/patrol.dart';

import 'package:akshara_erp/core/testing/qa_test_keys.dart';
import 'package:akshara_erp/features/auth/qa_login_persona.dart';

import '../helpers/patrol_app.dart';
import '../helpers/patrol_helpers.dart';

void main() {
  patrolTest(
    'workflow: principal SIS dashboard',
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
    'workflow: principal SIS registry',
    config: aksharaPatrolConfig(),
    ($) async {
      await bootstrapAndLogin($, QaLoginPersona.principal);
      await openErpDrawer($);
      await $(QaTestKeys.erpNavModule('sis')).scrollTo().tap();
      await $.pumpAndSettle(timeout: const Duration(seconds: 15));
      await tapModuleSubNav($, 'sis', 'Student Registry');
      await $('Export').scrollTo();
      await assertVisibleText($, 'Export');
    },
  );

  patrolTest(
    'workflow: principal admissions pipeline',
    config: aksharaPatrolConfig(),
    ($) async {
      await navigateErpWorkflow(
        $,
        QaLoginPersona.principal,
        'admissions',
        workflowAnchor: 'Total Leads (MTD)',
      );
    },
  );

  patrolTest(
    'workflow: principal finance dashboard',
    config: aksharaPatrolConfig(),
    ($) async {
      await navigateErpWorkflow(
        $,
        QaLoginPersona.principal,
        'finance',
        workflowAnchor: 'Fee Collected (MTD)',
      );
    },
  );

  patrolTest(
    'workflow: principal inventory dashboard',
    config: aksharaPatrolConfig(),
    ($) async {
      await navigateErpWorkflow(
        $,
        QaLoginPersona.principal,
        'inventory',
        workflowAnchor: 'Total Assets',
      );
    },
  );

  patrolTest(
    'workflow: principal analytics',
    config: aksharaPatrolConfig(),
    ($) async {
      await bootstrapAndLogin($, QaLoginPersona.principal);
      await tapPrincipalQuickAction($, 'attendance');
      await $('Class summary').scrollTo();
      await assertVisibleText($, 'Class summary');
    },
  );

  patrolTest(
    'workflow: principal tasks approvals',
    config: aksharaPatrolConfig(),
    ($) async {
      await bootstrapAndLogin($, QaLoginPersona.principal);
      await tapPrincipalQuickAction($, 'approvals');
      await assertVisibleText($, 'Approval queue');
    },
  );

  patrolTest(
    'workflow: principal management intelligence',
    config: aksharaPatrolConfig(),
    ($) async {
      await bootstrapAndLogin($, QaLoginPersona.principal);
      await tapPrincipalQuickAction($, 'risk');
      await $('Communication engagement').scrollTo();
      await assertVisibleText($, 'Communication engagement');
    },
  );

  patrolTest(
    'workflow: principal management finance',
    config: aksharaPatrolConfig(),
    ($) async {
      await bootstrapAndLogin($, QaLoginPersona.principal);
      await tapPrincipalQuickAction($, 'fees');
      await $('Finance module drill-down').scrollTo();
      await assertVisibleText($, 'Finance module drill-down');
    },
  );
}
