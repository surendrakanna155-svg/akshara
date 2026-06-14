import 'package:patrol/patrol.dart';

import 'package:akshara_erp/features/auth/qa_login_persona.dart';
import 'package:akshara_erp/router/route_names.dart';

import '../helpers/patrol_app.dart';
import '../helpers/patrol_helpers.dart';
import '../helpers/transport_allocation_journey_helpers.dart';

void main() {
  patrolTest(
    'journey: transport student allocation assign transfer remove E2E',
    config: aksharaPatrolConfig(),
    ($) async {
      await bootstrapAndLogin($, QaLoginPersona.superAdmin);
      await goToErpRoute($, RouteNames.transportAllocation);
      await assertVisibleText($, 'Student transport allocation');
      await assignStudentTransportRow($, 'alloc_5');
      await transferStudentTransportRow($, 'alloc_5');
      await removeStudentTransportRow($, 'alloc_5');
    },
  );
}
