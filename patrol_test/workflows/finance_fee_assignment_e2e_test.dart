import 'package:patrol/patrol.dart';

import 'package:akshara_erp/core/testing/qa_test_keys.dart';
import 'package:akshara_erp/features/auth/qa_login_persona.dart';

import '../helpers/finance_journey_helpers.dart';
import '../helpers/patrol_app.dart';
import '../helpers/patrol_helpers.dart';

/// Finance fee assignment write journey (mock mode, pre-seeded handoff).
void main() {
  patrolTest(
    'journey: finance fee assignment from handoff',
    config: aksharaPatrolConfig(),
    ($) async {
      await bootstrapAndLogin($, QaLoginPersona.superAdmin);
      await openErpDrawer($);
      await $(QaTestKeys.erpNavModule('finance')).scrollTo().tap();
      await $.pumpAndSettle(timeout: const Duration(seconds: 15));
      await tapModuleSubNav($, 'finance', 'Fee Assignment');
      await assertVisibleText($, 'Admissions handoff queue');
      await assignFeePlanForStudent($, 'Ananya Reddy');
    },
  );
}
