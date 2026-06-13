import 'package:patrol/patrol.dart';

import 'package:akshara_erp/features/auth/qa_login_persona.dart';

import '../helpers/patrol_app.dart';
import '../helpers/patrol_helpers.dart';

/// One APK build — smoke across personas (run in ~2 min after first compile).
void main() {
  patrolTest(
    'smoke: teacher attendance submit',
    config: aksharaPatrolConfig(),
    ($) async {
      await bootstrapAndLogin($, QaLoginPersona.teacher);
      await tapBottomNav($, 'Classes');
      await assertVisibleText($, 'Ravi Kumar');
      await scrollTap($, 'All present');
      await $('Submit').waitUntilVisible(timeout: const Duration(seconds: 15));
      await scrollTap($, 'Submit');
      await assertVisibleText($, 'Attendance submitted successfully.');
    },
  );

  patrolTest(
    'smoke: parent fees and pay',
    config: aksharaPatrolConfig(),
    ($) async {
      await bootstrapAndLogin($, QaLoginPersona.parent);
      await tapBottomNav($, 'Fees');
      await scrollTap($, 'Pay Now');
      await assertVisibleText($, 'Pay Fee');
    },
  );

  patrolTest(
    'smoke: student homework',
    config: aksharaPatrolConfig(),
    ($) async {
      await bootstrapAndLogin($, QaLoginPersona.student);
      await tapBottomNav($, 'Learn');
      await assertVisibleText($, 'Homework');
    },
  );

  patrolTest(
    'smoke: principal SIS registry',
    config: aksharaPatrolConfig(),
    ($) async {
      await navigateErpWorkflow(
        $,
        QaLoginPersona.principal,
        'sis',
        subNavLabel: 'Student Registry',
        workflowAnchor: 'Export',
      );
    },
  );

  patrolTest(
    'smoke: erp admissions enrollment',
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
}
