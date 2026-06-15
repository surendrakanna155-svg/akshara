import 'package:patrol/patrol.dart';

import 'package:akshara_erp/core/testing/qa_test_keys.dart';
import 'package:akshara_erp/features/auth/qa_login_persona.dart';

import '../helpers/patrol_app.dart';
import '../helpers/patrol_helpers.dart';

void main() {
  patrolTest(
    'journey: finance offline payment record and reconcile',
    config: aksharaPatrolConfig(),
    ($) async {
      await bootstrapAndLogin($, QaLoginPersona.superAdmin);
      await openErpDrawer($);
      await $(QaTestKeys.erpNavModule('finance')).scrollTo().tap();
      await $.pumpAndSettle(timeout: const Duration(seconds: 15));

      await tapModuleSubNav($, 'finance', 'Offline Payments');
      await assertVisibleText($, 'Offline payment records');

      await $(QaTestKeys.financeRecordOfflinePaymentFab).scrollTo().tap();
      await $.pumpAndSettle();
      await $(QaTestKeys.financeOfflinePaymentInvoiceField).enterText('inv_1');
      await $(QaTestKeys.financeOfflinePaymentStudentField)
          .enterText('Patrol Student');
      await $(QaTestKeys.financeOfflinePaymentAmountField).enterText('4500');
      await $(QaTestKeys.financeOfflinePaymentReferenceField)
          .enterText('PATROL-CHQ-1');
      await $(QaTestKeys.financeOfflinePaymentSubmitButton).tap();
      await $.pumpAndSettle(timeout: const Duration(seconds: 10));
      await assertVisibleKey(
          $, QaTestKeys.financeOfflinePaymentSuccessSnackbar);

      await $(QaTestKeys.financeReconcileOfflinePaymentButton('op_1'))
          .scrollTo()
          .tap();
      await $.pumpAndSettle(timeout: const Duration(seconds: 10));
      await assertVisibleKey(
        $,
        QaTestKeys.financeOfflinePaymentReconcileSuccessSnackbar,
      );
    },
  );
}
