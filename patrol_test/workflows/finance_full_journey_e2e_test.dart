import 'package:patrol/patrol.dart';

import 'package:akshara_erp/core/testing/qa_test_keys.dart';
import 'package:akshara_erp/features/auth/qa_login_persona.dart';

import '../helpers/finance_journey_helpers.dart';
import '../helpers/patrol_app.dart';
import '../helpers/patrol_helpers.dart';

/// Single-session finance journey: assign → invoice → collect → receipt.
void main() {
  patrolTest(
    'journey: finance assign collect receipt chain',
    config: aksharaPatrolConfig(),
    ($) async {
      await bootstrapAndLogin($, QaLoginPersona.superAdmin);
      await openErpDrawer($);
      await $(QaTestKeys.erpNavModule('finance')).scrollTo().tap();
      await $.pumpAndSettle(timeout: const Duration(seconds: 15));
      await tapModuleSubNav($, 'finance', 'Fee Assignment');
      await assertVisibleText($, 'Admissions handoff queue');

      await completeFinanceAssignCollectJourney($, 'Ananya Reddy');
    },
  );
}
