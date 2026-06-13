import 'package:patrol/patrol.dart';

import 'package:akshara_erp/features/auth/qa_login_persona.dart';

import '../helpers/patrol_app.dart';
import '../helpers/patrol_helpers.dart';

void main() {
  patrolTest(
    'workflow: teacher attendance mark',
    config: aksharaPatrolConfig(),
    ($) async {
      await bootstrapAndLogin($, QaLoginPersona.teacher);
      await tapBottomNav($, 'Classes');
      await assertVisibleText($, 'Mark Attendance');
      await assertVisibleText($, 'All present');
    },
  );

  patrolTest(
    'workflow: teacher attendance submit',
    config: aksharaPatrolConfig(),
    ($) async {
      await bootstrapAndLogin($, QaLoginPersona.teacher);
      await tapBottomNav($, 'Classes');
      await assertVisibleText($, 'Ravi Kumar');
      await scrollTap($, 'All present');
      await $('Submit').waitUntilVisible(timeout: const Duration(seconds: 15));
      await scrollTap($, 'Submit');
      await $.pumpAndSettle(timeout: const Duration(seconds: 10));
      await assertVisibleText($, 'Attendance submitted successfully.');
    },
  );

  patrolTest(
    'workflow: teacher homework review',
    config: aksharaPatrolConfig(),
    ($) async {
      await bootstrapAndLogin($, QaLoginPersona.teacher);
      await tapBottomNav($, 'Teach');
      await assertVisibleText($, 'Homework Review');
      await assertVisibleText($, 'Pending review');
    },
  );

  patrolTest(
    'workflow: teacher classes roster',
    config: aksharaPatrolConfig(),
    ($) async {
      await bootstrapAndLogin($, QaLoginPersona.teacher);
      await tapBottomNav($, 'Classes');
      await assertVisibleText($, 'Mark Attendance');
      await assertVisibleText($, 'Save draft');
    },
  );

  patrolTest(
    'workflow: teacher messages inbox',
    config: aksharaPatrolConfig(),
    ($) async {
      await bootstrapAndLogin($, QaLoginPersona.teacher);
      await tapBottomNav($, 'Messages');
      await assertVisibleText($, 'Messages');
    },
  );

  patrolTest(
    'workflow: teacher timetable',
    config: aksharaPatrolConfig(),
    ($) async {
      await bootstrapAndLogin($, QaLoginPersona.teacher);
      await scrollTap($, 'Timetable');
      await assertVisibleText($, 'Timetable');
    },
  );

  patrolTest(
    'workflow: teacher exams',
    config: aksharaPatrolConfig(),
    ($) async {
      await bootstrapAndLogin($, QaLoginPersona.teacher);
      await scrollTap($, 'Exams');
      await assertVisibleText($, 'Exams');
    },
  );

  patrolTest(
    'workflow: teacher schedule today',
    config: aksharaPatrolConfig(),
    ($) async {
      await bootstrapAndLogin($, QaLoginPersona.teacher);
      await scrollTap($, "Today's Classes");
      await assertVisibleText($, 'Good morning, Priya');
    },
  );

  patrolTest(
    'workflow: teacher attendance from quick action',
    config: aksharaPatrolConfig(),
    ($) async {
      await bootstrapAndLogin($, QaLoginPersona.teacher);
      await scrollTap($, 'Attendance');
      await assertVisibleText($, 'Mark Attendance');
    },
  );

  patrolTest(
    'workflow: teacher homework from quick action',
    config: aksharaPatrolConfig(),
    ($) async {
      await bootstrapAndLogin($, QaLoginPersona.teacher);
      await scrollTap($, 'Homework');
      await assertVisibleText($, 'Homework Review');
    },
  );
}
