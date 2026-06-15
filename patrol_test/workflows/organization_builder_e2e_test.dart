import 'package:akshara_erp/core/testing/qa_test_keys.dart';
import 'package:akshara_erp/features/auth/qa_login_persona.dart';
import 'package:akshara_erp/router/route_names.dart';
import 'package:patrol/patrol.dart';

import '../helpers/patrol_app.dart';
import '../helpers/patrol_helpers.dart';

void main() {
  patrolTest(
    'journey: organization builder interview and preview',
    config: aksharaPatrolConfig(),
    ($) async {
      await bootstrapAndLogin($, QaLoginPersona.superAdmin);
      await goToErpRoute($, RouteNames.organizationBuilder);

      await assertVisibleKey($, QaTestKeys.organizationBuilderHubScreen);
      await $(QaTestKeys.organizationBuilderStartInterviewButton('pack_school'))
          .tap();
      await $.pumpAndSettle(timeout: const Duration(seconds: 10));
      await assertVisibleKey($, QaTestKeys.organizationBuilderInterviewScreen);

      await $(QaTestKeys.organizationBuilderInterviewNameField)
          .enterText('Akshara Patrol School');
      await $(QaTestKeys.organizationBuilderInterviewContinueButton).tap();
      await $.pumpAndSettle(timeout: const Duration(seconds: 10));

      await $(QaTestKeys.organizationBuilderInterviewScalePrimaryField)
          .enterText('800');
      await $(QaTestKeys.organizationBuilderInterviewScaleSecondaryField)
          .enterText('60');
      await $(QaTestKeys.organizationBuilderInterviewContinueButton).tap();
      await $.pumpAndSettle(timeout: const Duration(seconds: 10));

      for (var step = 0; step < 4; step++) {
        await $(QaTestKeys.organizationBuilderInterviewContinueButton).tap();
        await $.pumpAndSettle(timeout: const Duration(seconds: 10));
      }

      await $(QaTestKeys.organizationBuilderInterviewPreviewButton).tap();
      await $.pumpAndSettle(timeout: const Duration(seconds: 15));
      await assertVisibleKey($, QaTestKeys.organizationBuilderPreviewScreen);
    },
  );
}
