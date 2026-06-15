import 'package:akshara_erp/core/testing/qa_test_keys.dart';
import 'package:akshara_erp/features/auth/qa_login_persona.dart';
import 'package:akshara_erp/router/route_names.dart';
import 'package:patrol/patrol.dart';

import '../helpers/patrol_app.dart';
import '../helpers/patrol_helpers.dart';

void main() {
  patrolTest(
    'journey: ai content generate, copy, and share',
    config: aksharaPatrolConfig(),
    ($) async {
      await bootstrapAndLogin($, QaLoginPersona.superAdmin);
      await goToErpRoute($, RouteNames.aiContent);

      await $(QaTestKeys.aiContentPromptField)
          .scrollTo()
          .enterText('Create a notice about exam revision classes.');
      await $(QaTestKeys.aiContentGenerateButton).scrollTo().tap();
      await $.pumpAndSettle(timeout: const Duration(seconds: 10));

      await assertVisibleKey($, QaTestKeys.aiContentGeneratedSnackbar);
      await $(QaTestKeys.aiContentCopyButton).scrollTo().tap();
      await $.pumpAndSettle(timeout: const Duration(seconds: 10));
      await assertVisibleKey($, QaTestKeys.aiContentCopiedSnackbar);

      await $(QaTestKeys.aiContentShareButton).scrollTo().tap();
      await $.pumpAndSettle(timeout: const Duration(seconds: 10));
      await assertVisibleKey($, QaTestKeys.aiContentSharedSnackbar);
    },
  );
}
