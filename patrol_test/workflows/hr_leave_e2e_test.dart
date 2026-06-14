import 'package:patrol/patrol.dart';

import 'package:akshara_erp/features/auth/qa_login_persona.dart';
import 'package:akshara_erp/router/route_names.dart';

import '../helpers/hr_journey_helpers.dart';
import '../helpers/patrol_app.dart';
import '../helpers/patrol_helpers.dart';

/// HR leave submit journey (mock mode).
void main() {
  patrolTest(
    'journey: hr leave request submit E2E',
    config: aksharaPatrolConfig(),
    ($) async {
      await bootstrapAndLogin($, QaLoginPersona.superAdmin);
      await goToErpRoute($, RouteNames.hrLeave);
      await assertVisibleText($, 'Leave requests');
      await submitHrLeaveRequest($);
    },
  );
}
