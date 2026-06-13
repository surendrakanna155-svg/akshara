import 'package:patrol/patrol.dart';

import 'package:akshara_erp/core/testing/qa_test_keys.dart';
import 'package:akshara_erp/features/auth/qa_login_persona.dart';

import '../helpers/patrol_app.dart';
import '../helpers/patrol_helpers.dart';

void main() {
  patrolTest(
    'workflow: student homework',
    config: aksharaPatrolConfig(),
    ($) async {
      await bootstrapAndLogin($, QaLoginPersona.student);
      await tapBottomNav($, 'Learn');
      await assertVisibleText($, 'Homework');
    },
  );

  patrolTest(
    'workflow: student attendance',
    config: aksharaPatrolConfig(),
    ($) async {
      await bootstrapAndLogin($, QaLoginPersona.student);
      await scrollTap($, 'Present today');
      await assertVisibleText($, 'Attendance');
    },
  );

  patrolTest(
    'workflow: student exams upcoming',
    config: aksharaPatrolConfig(),
    ($) async {
      await bootstrapAndLogin($, QaLoginPersona.student);
      await tapBottomNav($, 'Results');
      await assertVisibleText($, 'Exams');
      await assertVisibleText($, 'Upcoming');
    },
  );

  patrolTest(
    'workflow: student timetable',
    config: aksharaPatrolConfig(),
    ($) async {
      await bootstrapAndLogin($, QaLoginPersona.student);
      await tapBottomNav($, 'Schedule');
      await assertVisibleText($, 'Timetable');
    },
  );

  patrolTest(
    'workflow: student profile',
    config: aksharaPatrolConfig(),
    ($) async {
      await bootstrapAndLogin($, QaLoginPersona.student);
      await $(QaTestKeys.profileButton).tap();
      await $.pumpAndSettle(timeout: const Duration(seconds: 10));
      await assertVisibleText($, 'Profile');
    },
  );

  patrolTest(
    'workflow: student submit homework quick action',
    config: aksharaPatrolConfig(),
    ($) async {
      await bootstrapAndLogin($, QaLoginPersona.student);
      await scrollTap($, 'Submit HW');
      await assertVisibleText($, 'Homework');
    },
  );

  patrolTest(
    'workflow: student full schedule',
    config: aksharaPatrolConfig(),
    ($) async {
      await bootstrapAndLogin($, QaLoginPersona.student);
      await scrollTap($, 'Full schedule');
      await assertVisibleText($, 'Timetable');
    },
  );
}
