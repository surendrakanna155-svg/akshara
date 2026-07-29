import 'package:akshara_erp/features/auth/qa_login_persona.dart';
import 'package:akshara_erp/router/route_names.dart';
import 'package:patrol/patrol.dart';

import '../helpers/patrol_app.dart';
import '../helpers/patrol_helpers.dart';

void main() {
  patrolTest(
    'journey: director portal sub-route navigation',
    config: aksharaPatrolConfig(),
    ($) async {
      await bootstrapAndLogin($, QaLoginPersona.superAdmin);

      await goToErpRoute($, RouteNames.directorSchools);
      await waitForLoadingToClear($, timeout: const Duration(seconds: 30));
      await assertVisibleText($, 'NIKSHA North Campus');

      await goToErpRoute($, RouteNames.directorRevenue);
      await waitForLoadingToClear($, timeout: const Duration(seconds: 30));
      await assertVisibleText($, 'Chain Revenue');

      await goToErpRoute($, RouteNames.directorCompliance);
      await waitForLoadingToClear($, timeout: const Duration(seconds: 30));
      await assertVisibleText($, 'School');
    },
  );
}
