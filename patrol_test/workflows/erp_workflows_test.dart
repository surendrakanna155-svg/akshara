import 'package:patrol/patrol.dart';

import 'package:akshara_erp/features/auth/qa_login_persona.dart';

import '../helpers/patrol_helpers.dart';

void main() {
  patrolTest(
    'workflow: erp school creation',
    config: aksharaPatrolConfig(),
    ($) async {
      await navigateErpWorkflow(
        $,
        QaLoginPersona.superAdmin,
        'controlCenter',
        subNavLabel: 'Schools',
        workflowAnchor: 'Create school',
      );
    },
  );

  patrolTest(
    'workflow: erp teacher roster',
    config: aksharaPatrolConfig(),
    ($) async {
      await navigateErpWorkflow(
        $,
        QaLoginPersona.superAdmin,
        'hr',
        subNavLabel: 'Employees',
        workflowAnchor: 'Teachers',
      );
    },
  );

  patrolTest(
    'workflow: erp student enrollment wizard',
    config: aksharaPatrolConfig(),
    ($) async {
      await navigateErpWorkflow(
        $,
        QaLoginPersona.superAdmin,
        'admissions',
        subNavLabel: 'Enrollment',
        workflowAnchor: 'Student profile',
      );
    },
  );

  patrolTest(
    'workflow: erp parent enrollment step',
    config: aksharaPatrolConfig(),
    ($) async {
      await navigateErpWorkflow(
        $,
        QaLoginPersona.superAdmin,
        'admissions',
        subNavLabel: 'Enrollment',
        workflowAnchor: 'Student profile',
      );
      await tapEnrollmentContinue($);
      await assertVisibleText($, 'Parent / guardian');
    },
  );

  patrolTest(
    'workflow: erp finance collections',
    config: aksharaPatrolConfig(),
    ($) async {
      await navigateErpWorkflow(
        $,
        QaLoginPersona.superAdmin,
        'finance',
        workflowAnchor: 'Fee Collected (MTD)',
      );
    },
  );

  patrolTest(
    'workflow: erp finance reports',
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
    'workflow: erp inventory assets',
    config: aksharaPatrolConfig(),
    ($) async {
      await navigateErpWorkflow(
        $,
        QaLoginPersona.superAdmin,
        'inventory',
        workflowAnchor: 'Total Assets',
      );
    },
  );

  patrolTest(
    'workflow: erp transport fleet',
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
    'workflow: erp library dashboard',
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
    'workflow: erp hostel dashboard',
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
    'workflow: erp sis student registry',
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
    'workflow: erp management analytics',
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
}
