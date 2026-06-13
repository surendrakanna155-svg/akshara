import 'package:patrol/patrol.dart';

import 'package:akshara_erp/features/auth/qa_login_persona.dart';

import '../helpers/patrol_app.dart';
import '../helpers/patrol_helpers.dart';

/// Marks key persona/module screens for screenshot regression tooling.
void main() {
  patrolTest(
    'screenshot: principal management dashboard',
    config: aksharaPatrolConfig(),
    ($) async {
      await bootstrapAndLogin($, QaLoginPersona.principal);
      await assertVisibleText($, 'Principal');
      await capturePatrolScreenshot($, 'principal_dashboard', subdir: 'v18_6');
    },
  );

  patrolTest(
    'screenshot: teacher home',
    config: aksharaPatrolConfig(),
    ($) async {
      await bootstrapAndLogin($, QaLoginPersona.teacher);
      await assertVisibleText($, 'Classes');
      await capturePatrolScreenshot($, 'teacher_home', subdir: 'v18_6');
    },
  );

  patrolTest(
    'screenshot: parent fees',
    config: aksharaPatrolConfig(),
    ($) async {
      await bootstrapAndLogin($, QaLoginPersona.parent);
      await tapBottomNav($, 'Fees');
      await assertVisibleText($, 'Fees');
      await capturePatrolScreenshot($, 'parent_fees', subdir: 'v18_6');
    },
  );

  patrolTest(
    'screenshot: student learn hub',
    config: aksharaPatrolConfig(),
    ($) async {
      await bootstrapAndLogin($, QaLoginPersona.student);
      await tapBottomNav($, 'Learn');
      await assertVisibleText($, 'Homework');
      await capturePatrolScreenshot($, 'student_learn', subdir: 'v18_6');
    },
  );

  patrolTest(
    'screenshot: finance collections',
    config: aksharaPatrolConfig(),
    ($) async {
      await navigateErpWorkflow(
        $,
        QaLoginPersona.superAdmin,
        'finance',
        subNavLabel: 'Collections',
        workflowAnchor: 'Collected today',
      );
      await capturePatrolScreenshot($, 'finance_collections', subdir: 'v18_6');
    },
  );

  patrolTest(
    'screenshot: inventory dashboard',
    config: aksharaPatrolConfig(),
    ($) async {
      await navigateErpWorkflow(
        $,
        QaLoginPersona.superAdmin,
        'inventory',
        workflowAnchor: 'Total Assets',
      );
      await capturePatrolScreenshot($, 'inventory_dashboard', subdir: 'v18_6');
    },
  );

  patrolTest(
    'screenshot: finance reports',
    config: aksharaPatrolConfig(),
    ($) async {
      await navigateErpWorkflow(
        $,
        QaLoginPersona.superAdmin,
        'finance',
        subNavLabel: 'Reports',
        workflowAnchor: 'Export PDF',
      );
      await capturePatrolScreenshot($, 'finance_reports', subdir: 'v18_6');
    },
  );

  patrolTest(
    'screenshot: management analytics',
    config: aksharaPatrolConfig(),
    ($) async {
      await navigateErpWorkflow(
        $,
        QaLoginPersona.superAdmin,
        'management',
        subNavLabel: 'Analytics',
        workflowAnchor: 'Enrollment trend',
      );
      await capturePatrolScreenshot($, 'management_analytics', subdir: 'v18_6');
    },
  );

  patrolTest(
    'screenshot: admissions enrollment',
    config: aksharaPatrolConfig(),
    ($) async {
      await navigateErpWorkflow(
        $,
        QaLoginPersona.superAdmin,
        'admissions',
        subNavLabel: 'Enrollment',
        workflowAnchor: 'Student profile',
      );
      await capturePatrolScreenshot($, 'admissions_enrollment', subdir: 'v18_6');
    },
  );

  patrolTest(
    'screenshot: sis registry',
    config: aksharaPatrolConfig(),
    ($) async {
      await navigateErpWorkflow(
        $,
        QaLoginPersona.principal,
        'sis',
        subNavLabel: 'Student Registry',
        workflowAnchor: 'Export',
      );
      await capturePatrolScreenshot($, 'sis_registry', subdir: 'v18_6');
    },
  );
}
