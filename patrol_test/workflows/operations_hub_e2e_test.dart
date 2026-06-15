import 'package:akshara_erp/core/testing/qa_test_keys.dart';
import 'package:akshara_erp/features/auth/qa_login_persona.dart';
import 'package:akshara_erp/router/route_names.dart';
import 'package:patrol/patrol.dart';

import '../helpers/patrol_app.dart';
import '../helpers/patrol_helpers.dart';

void main() {
  patrolTest(
    'journey: operations hub dismiss and complete actions',
    config: aksharaPatrolConfig(),
    ($) async {
      await bootstrapAndLogin($, QaLoginPersona.superAdmin);
      await goToErpRoute($, RouteNames.operationsHub);

      await assertVisibleText($, 'Critical Alerts');
      await $(QaTestKeys.operationsHubDismissAlertButton('student-risk'))
          .scrollTo()
          .tap();
      await $.pumpAndSettle(timeout: const Duration(seconds: 10));
      await assertVisibleKey($, QaTestKeys.operationsHubAlertDismissedSnackbar);

      await $(QaTestKeys.operationsHubCompleteActionButton('inv-pending'))
          .scrollTo()
          .tap();
      await $.pumpAndSettle(timeout: const Duration(seconds: 10));
      await assertVisibleKey(
          $, QaTestKeys.operationsHubActionCompletedSnackbar);
    },
  );
}
