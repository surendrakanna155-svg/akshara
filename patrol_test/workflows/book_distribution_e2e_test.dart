import 'package:akshara_erp/core/testing/qa_test_keys.dart';
import 'package:akshara_erp/features/auth/qa_login_persona.dart';
import 'package:akshara_erp/router/route_names.dart';
import 'package:patrol/patrol.dart';

import '../helpers/patrol_app.dart';
import '../helpers/patrol_helpers.dart';

void main() {
  patrolTest(
    'journey: inventory book distribution parity',
    config: aksharaPatrolConfig(),
    ($) async {
      await bootstrapAndLogin($, QaLoginPersona.superAdmin);
      await goToErpRoute($, RouteNames.inventoryDistribution);
      await assertVisibleKey($, QaTestKeys.inventoryDistributionScreen);
      await assertVisibleText($, 'Student distributions');

      await $(QaTestKeys.inventoryDistributionCreateFab).scrollTo().tap();
      await $.pumpAndSettle();
      await $(QaTestKeys.inventoryDistributionStudentIdField)
          .enterText('student_patrol_1');
      await $(QaTestKeys.inventoryDistributionCatalogItemField)
          .enterText('cat_1');
      await $(QaTestKeys.inventoryDistributionQuantityField).enterText('1');
      await $(QaTestKeys.inventoryDistributionCreateSubmitButton).tap();
      await $.pumpAndSettle(timeout: const Duration(seconds: 10));
      await assertVisibleKey(
        $,
        QaTestKeys.inventoryDistributionCreateSuccessSnackbar,
      );

      await $(QaTestKeys.inventoryDistributionMarkDistributedButton('dist_2'))
          .scrollTo()
          .tap();
      await $.pumpAndSettle(timeout: const Duration(seconds: 10));
      await assertVisibleKey(
        $,
        QaTestKeys.inventoryDistributionMarkDistributedSuccessSnackbar,
      );
    },
  );
}
