import 'package:patrol/patrol.dart';

import 'package:akshara_erp/core/testing/qa_test_keys.dart';
import 'package:akshara_erp/features/auth/qa_login_persona.dart';

import '../helpers/finance_journey_helpers.dart';
import '../helpers/patrol_app.dart';
import '../helpers/patrol_helpers.dart';

/// Finance fee collection write journey (mock mode).
void main() {
  patrolTest(
    'journey: finance record collection and receipt lookup',
    config: aksharaPatrolConfig(),
    ($) async {
      await bootstrapAndLogin($, QaLoginPersona.superAdmin);
      await openErpDrawer($);
      await $(QaTestKeys.erpNavModule('finance')).scrollTo().tap();
      await $.pumpAndSettle(timeout: const Duration(seconds: 15));
      await tapModuleSubNav($, 'finance', 'Collections');
      await assertVisibleText($, 'Collected today');

      await recordCollectionForInvoice($);
      await verifyReceiptInCollectionsList($, 'RCP-');
    },
  );
}
