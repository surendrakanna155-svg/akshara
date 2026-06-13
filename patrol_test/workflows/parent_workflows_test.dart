import 'package:patrol/patrol.dart';

import 'package:akshara_erp/core/testing/qa_test_keys.dart';
import 'package:akshara_erp/features/auth/qa_login_persona.dart';

import '../helpers/patrol_app.dart';
import '../helpers/patrol_helpers.dart';

void main() {
  patrolTest(
    'workflow: parent attendance',
    config: aksharaPatrolConfig(),
    ($) async {
      await bootstrapAndLogin($, QaLoginPersona.parent);
      await tapBottomNav($, 'Academics');
      await assertVisibleText($, 'Attendance');
    },
  );

  patrolTest(
    'workflow: parent homework via academics shortcuts',
    config: aksharaPatrolConfig(),
    ($) async {
      await bootstrapAndLogin($, QaLoginPersona.parent);
      await tapBottomNav($, 'Academics');
      await scrollTap($, 'Homework');
      await assertVisibleText($, 'Homework');
    },
  );

  patrolTest(
    'workflow: parent fees overview',
    config: aksharaPatrolConfig(),
    ($) async {
      await bootstrapAndLogin($, QaLoginPersona.parent);
      await tapBottomNav($, 'Fees');
      await assertVisibleText($, 'Fees');
    },
  );

  patrolTest(
    'workflow: parent pay fee',
    config: aksharaPatrolConfig(),
    ($) async {
      await bootstrapAndLogin($, QaLoginPersona.parent);
      await scrollTap($, 'Pay Fee');
      await assertVisibleText($, 'Pay Fee');
    },
  );

  patrolTest(
    'workflow: parent receipts',
    config: aksharaPatrolConfig(),
    ($) async {
      await bootstrapAndLogin($, QaLoginPersona.parent);
      await tapBottomNav($, 'Fees');
      await $(QaTestKeys.receiptHistoryButton).scrollTo().tap();
      await $.pumpAndSettle(timeout: const Duration(seconds: 10));
      await assertVisibleText($, 'Receipts');
    },
  );

  patrolTest(
    'workflow: parent exams',
    config: aksharaPatrolConfig(),
    ($) async {
      await bootstrapAndLogin($, QaLoginPersona.parent);
      await tapBottomNav($, 'Academics');
      await scrollTap($, 'Exams');
      await assertVisibleText($, 'Exams');
    },
  );

  patrolTest(
    'workflow: parent timetable',
    config: aksharaPatrolConfig(),
    ($) async {
      await bootstrapAndLogin($, QaLoginPersona.parent);
      await scrollTap($, 'Timetable');
      await assertVisibleText($, 'Timetable');
    },
  );

  patrolTest(
    'workflow: parent academic report',
    config: aksharaPatrolConfig(),
    ($) async {
      await bootstrapAndLogin($, QaLoginPersona.parent);
      await scrollTap($, 'Full report');
      await assertVisibleText($, 'Academic Report');
    },
  );

  patrolTest(
    'workflow: parent fees pay now CTA',
    config: aksharaPatrolConfig(),
    ($) async {
      await bootstrapAndLogin($, QaLoginPersona.parent);
      await tapBottomNav($, 'Fees');
      await scrollTap($, 'Pay Now');
      await assertVisibleText($, 'Pay Fee');
    },
  );

  patrolTest(
    'workflow: parent experience hub',
    config: aksharaPatrolConfig(),
    ($) async {
      await bootstrapAndLogin($, QaLoginPersona.parent);
      await scrollTap($, 'Parent Experience Hub');
      await assertVisibleText($, 'Parent Experience');
    },
  );
}
