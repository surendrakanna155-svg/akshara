import 'package:akshara_erp/core/testing/qa_test_keys.dart';
import 'package:akshara_erp/features/auth/qa_login_persona.dart';
import 'package:patrol/patrol.dart';

import '../helpers/patrol_app.dart';
import '../helpers/patrol_helpers.dart';

void main() {
  patrolTest(
    'journey: finance qr payment confirm',
    config: aksharaPatrolConfig(),
    ($) async {
      await bootstrapAndLogin($, QaLoginPersona.superAdmin);
      await openErpDrawer($);
      await $(QaTestKeys.erpNavModule('finance')).scrollTo().tap();
      await $.pumpAndSettle(timeout: const Duration(seconds: 15));
      await tapModuleSubNav($, 'finance', 'Collections');

      await $(QaTestKeys.financeQrPayButton).scrollTo().tap();
      await $.pumpAndSettle(timeout: const Duration(seconds: 8));
      await assertVisibleText($, 'QR Payment');

      await $(QaTestKeys.financeGenerateQrButton).tap();
      await $.pumpAndSettle(timeout: const Duration(seconds: 8));
      await assertVisibleText($, 'upi://pay?');

      await $(QaTestKeys.financeQrReceiptField).enterText('RCP-QR-E2E-1');
      await $(QaTestKeys.financeConfirmQrPaymentButton).tap();
      await $.pumpAndSettle(timeout: const Duration(seconds: 10));
      await assertVisibleKey($, QaTestKeys.financeQrPaymentConfirmedSnackbar);
    },
  );
}
