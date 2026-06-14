import 'package:patrol/patrol.dart';

import 'package:akshara_erp/features/auth/qa_login_persona.dart';
import 'package:akshara_erp/router/route_names.dart';

import '../helpers/patrol_app.dart';
import '../helpers/patrol_helpers.dart';
import '../helpers/transport_journey_helpers.dart';

void main() {
  patrolTest(
    'journey: transport route draft then activate E2E',
    config: aksharaPatrolConfig(),
    ($) async {
      await bootstrapAndLogin($, QaLoginPersona.superAdmin);
      await goToErpRoute($, RouteNames.transportRoutes);
      await assertVisibleText($, 'Route catalog');
      await createTransportRouteDraft($);
      await activateTransportRouteDraft($);
    },
  );
}
