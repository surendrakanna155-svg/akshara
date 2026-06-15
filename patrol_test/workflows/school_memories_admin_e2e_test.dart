import 'package:patrol/patrol.dart';

import 'package:akshara_erp/core/testing/qa_test_keys.dart';
import 'package:akshara_erp/features/auth/qa_login_persona.dart';
import 'package:akshara_erp/router/route_names.dart';

import '../helpers/patrol_app.dart';
import '../helpers/patrol_helpers.dart';

void main() {
  patrolTest(
    'journey: school memories admin create and publish event',
    config: aksharaPatrolConfig(),
    ($) async {
      await bootstrapAndLogin($, QaLoginPersona.superAdmin);
      await goToErpRoute($, RouteNames.schoolMemories);
      await assertVisibleKey($, QaTestKeys.schoolMemoriesScreen);
      await assertVisibleText($, 'School Memories');

      await $(QaTestKeys.schoolMemoriesCreateFab).scrollTo().tap();
      await $.pumpAndSettle();
      await $(QaTestKeys.schoolMemoriesCreateTitleField)
          .enterText('Patrol Memories Event');
      await $(QaTestKeys.schoolMemoriesCreateDescriptionField)
          .enterText('Patrol coverage for memories admin');
      await $(QaTestKeys.schoolMemoriesCreateSubmitButton).tap();
      await $.pumpAndSettle(timeout: const Duration(seconds: 10));
      await assertVisibleKey($, QaTestKeys.schoolMemoriesCreatedSnackbar);

      await $('Patrol Memories Event').scrollTo().tap();
      await $.pumpAndSettle(timeout: const Duration(seconds: 10));
      await $(QaTestKeys.schoolMemoriesPublishButton).scrollTo().tap();
      await $.pumpAndSettle(timeout: const Duration(seconds: 10));
      await assertVisibleKey($, QaTestKeys.schoolMemoriesPublishedSnackbar);
    },
  );
}
