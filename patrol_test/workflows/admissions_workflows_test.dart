import 'package:patrol/patrol.dart';

import 'package:akshara_erp/features/auth/qa_login_persona.dart';

import '../helpers/patrol_helpers.dart';

void main() {
  patrolTest(
    'workflow: admissions leads pipeline',
    config: aksharaPatrolConfig(),
    ($) async {
      await navigateErpWorkflow(
        $,
        QaLoginPersona.superAdmin,
        'admissions',
        subNavLabel: 'Leads',
        workflowAnchor: 'New Lead',
      );
    },
  );

  patrolTest(
    'workflow: admissions applications queue',
    config: aksharaPatrolConfig(),
    ($) async {
      await navigateErpWorkflow(
        $,
        QaLoginPersona.superAdmin,
        'admissions',
        subNavLabel: 'Applications',
        workflowAnchor: 'New Application',
      );
    },
  );

  patrolTest(
    'workflow: admissions enrollment wizard start',
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
    'workflow: admissions enrollment parent step',
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
    'workflow: admissions approval queue',
    config: aksharaPatrolConfig(),
    ($) async {
      await navigateErpWorkflow(
        $,
        QaLoginPersona.superAdmin,
        'admissions',
        subNavLabel: 'Approval',
        workflowAnchor: 'Ananya Reddy',
      );
    },
  );
}
