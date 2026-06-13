import 'package:patrol/patrol.dart';

import 'package:akshara_erp/features/auth/qa_login_persona.dart';

import '../helpers/patrol_helpers.dart';

void main() {
  patrolTest(
    'workflow: hr dashboard',
    config: aksharaPatrolConfig(),
    ($) async {
      await navigateErpWorkflow(
        $,
        QaLoginPersona.superAdmin,
        'hr',
        workflowAnchor: 'Total Employees',
      );
    },
  );

  patrolTest(
    'workflow: hr employee directory',
    config: aksharaPatrolConfig(),
    ($) async {
      await navigateErpWorkflow(
        $,
        QaLoginPersona.superAdmin,
        'hr',
        subNavLabel: 'Employees',
        workflowAnchor: 'Employee directory',
      );
    },
  );

  patrolTest(
    'workflow: hr staff attendance',
    config: aksharaPatrolConfig(),
    ($) async {
      await navigateErpWorkflow(
        $,
        QaLoginPersona.superAdmin,
        'hr',
        subNavLabel: 'Attendance',
        workflowAnchor: 'Staff attendance',
      );
    },
  );

  patrolTest(
    'workflow: hr leave requests',
    config: aksharaPatrolConfig(),
    ($) async {
      await navigateErpWorkflow(
        $,
        QaLoginPersona.superAdmin,
        'hr',
        subNavLabel: 'Leave',
        workflowAnchor: 'Leave requests',
      );
    },
  );

  patrolTest(
    'workflow: hr payroll runs',
    config: aksharaPatrolConfig(),
    ($) async {
      await navigateErpWorkflow(
        $,
        QaLoginPersona.superAdmin,
        'hr',
        subNavLabel: 'Payroll',
        workflowAnchor: 'Payroll runs',
      );
    },
  );

  patrolTest(
    'workflow: hr recruitment pipeline',
    config: aksharaPatrolConfig(),
    ($) async {
      await navigateErpWorkflow(
        $,
        QaLoginPersona.superAdmin,
        'hr',
        subNavLabel: 'Recruitment',
        workflowAnchor: 'Recruitment pipeline',
      );
    },
  );

  patrolTest(
    'workflow: hr performance reviews',
    config: aksharaPatrolConfig(),
    ($) async {
      await navigateErpWorkflow(
        $,
        QaLoginPersona.superAdmin,
        'hr',
        subNavLabel: 'Performance',
        workflowAnchor: 'Performance reviews',
      );
    },
  );

  patrolTest(
    'workflow: hr settings',
    config: aksharaPatrolConfig(),
    ($) async {
      await navigateErpWorkflow(
        $,
        QaLoginPersona.superAdmin,
        'hr',
        subNavLabel: 'Settings',
        workflowAnchor: 'HR settings',
      );
    },
  );
}
