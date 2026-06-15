import 'package:akshara_erp/core/testing/qa_test_keys.dart';
import 'package:akshara_erp/features/auth/qa_login_persona.dart';
import 'package:akshara_erp/router/route_names.dart';
import 'package:patrol/patrol.dart';

import '../helpers/patrol_app.dart';
import '../helpers/patrol_helpers.dart';

void main() {
  patrolTest(
    'journey: dynamic widget platform registry and runtime',
    config: aksharaPatrolConfig(),
    ($) async {
      await bootstrapAndLogin($, QaLoginPersona.superAdmin);
      await goToErpRoute($, RouteNames.dynamicWidgets);

      await assertVisibleKey($, QaTestKeys.dynamicWidgetRegistryScreen);
      await assertVisibleKey($, QaTestKeys.dynamicWidgetCatalogItem('school_health'));

      await $(QaTestKeys.dynamicWidgetOpenRuntimeButton).tap();
      await $.pumpAndSettle(timeout: const Duration(seconds: 10));
      await assertVisibleKey($, QaTestKeys.dynamicWidgetRuntimeScreen);
      await assertVisibleKey($, QaTestKeys.dynamicWidgetRuntimeTile('school_health'));

      await goToErpRoute($, RouteNames.dynamicWidgetLayout);
      await assertVisibleKey($, QaTestKeys.dynamicWidgetLayoutEditorScreen);
      await assertVisibleKey($, QaTestKeys.dynamicWidgetLayoutItem('school_health'));
    },
  );
}
