import 'package:patrol/patrol.dart';

import 'package:akshara_erp/core/testing/qa_test_keys.dart';
import 'package:akshara_erp/features/auth/qa_login_persona.dart';

import '../helpers/patrol_app.dart';
import '../helpers/patrol_helpers.dart';

void main() {
  patrolTest(
    'journey: parent receipt pdf export E2E',
    config: aksharaPatrolConfig(),
    ($) async {
      await bootstrapAndLogin($, QaLoginPersona.parent);
      await tapBottomNav($, 'Fees');
      await $(QaTestKeys.receiptHistoryButton).scrollTo().tap();
      await $.pumpAndSettle(timeout: const Duration(seconds: 10));
      await $('Term 1 — Full payment').tap();
      await $.pumpAndSettle(timeout: const Duration(seconds: 10));
      await $(QaTestKeys.parentReceiptDownloadButton).tap();
      await $.pumpAndSettle(timeout: const Duration(seconds: 15));
      await assertVisibleKey($, QaTestKeys.parentReceiptPdfSuccessSnackbar);
    },
  );
}
