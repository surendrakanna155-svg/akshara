import 'package:akshara_erp/core/testing/qa_test_keys.dart';
import 'package:akshara_erp/features/auth/qa_login_persona.dart';
import 'package:akshara_erp/router/route_names.dart';
import 'package:patrol/patrol.dart';

import '../helpers/patrol_app.dart';
import '../helpers/patrol_helpers.dart';

void main() {
  patrolTest(
    'journey: finance qr payment confirm',
    config: aksharaPatrolConfig(),
    ($) async {
      await bootstrapAndLogin($, QaLoginPersona.superAdmin);
      await goToErpRoute($, RouteNames.financeQrPayment);
      await assertVisibleText($, 'QR Payment');

      await tapByKey($, QaTestKeys.financeGenerateQrButton, scrollFirst: false);
      await assertVisibleKey($, QaTestKeys.financeConfirmQrPaymentButton,
          timeout: const Duration(seconds: 45));
      await $.pumpAndSettle(timeout: const Duration(seconds: 10));
      await scrollModuleBody($, 'QR Payment', times: 8);
      await tapByKey($, QaTestKeys.financeConfirmQrPaymentButton, scrollFirst: true);
      await assertVisibleKey($, QaTestKeys.financeQrPaymentConfirmedSnackbar,
          timeout: const Duration(seconds: 30));
    },
  );
}
