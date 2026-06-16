import 'package:patrol/patrol.dart';

import 'package:akshara_erp/core/testing/qa_test_keys.dart';
import 'package:akshara_erp/features/auth/qa_login_persona.dart';
import 'package:akshara_erp/router/route_names.dart';

import '../helpers/patrol_app.dart';
import '../helpers/patrol_helpers.dart';

void main() {
  patrolTest(
    'red-team: parent blocked from admin hub route',
    config: aksharaPatrolConfig(),
    ($) async {
      await bootstrapAndLogin($, QaLoginPersona.parent);
      await assertMobileForbiddenErpRoute(
        $,
        RouteNames.admin,
        expectedHomeRoute: RouteNames.parentDashboard,
        expectedHomeScreenKey: QaTestKeys.parentDashboardScreen,
      );
    },
  );

  patrolTest(
    'red-team: parent blocked from control center route',
    config: aksharaPatrolConfig(),
    ($) async {
      await bootstrapAndLogin($, QaLoginPersona.parent);
      await assertMobileForbiddenErpRoute(
        $,
        RouteNames.controlCenterDashboard,
        expectedHomeRoute: RouteNames.parentDashboard,
        expectedHomeScreenKey: QaTestKeys.parentDashboardScreen,
      );
    },
  );

  patrolTest(
    'red-team: student blocked from admin hub route',
    config: aksharaPatrolConfig(),
    ($) async {
      await bootstrapAndLogin($, QaLoginPersona.student);
      await assertMobileForbiddenErpRoute(
        $,
        RouteNames.admin,
        expectedHomeRoute: RouteNames.studentDashboard,
        expectedHomeScreenKey: QaTestKeys.studentDashboardScreen,
      );
    },
  );

  patrolTest(
    'red-team: student blocked from control center route',
    config: aksharaPatrolConfig(),
    ($) async {
      await bootstrapAndLogin($, QaLoginPersona.student);
      await assertMobileForbiddenErpRoute(
        $,
        RouteNames.controlCenterDashboard,
        expectedHomeRoute: RouteNames.studentDashboard,
        expectedHomeScreenKey: QaTestKeys.studentDashboardScreen,
      );
    },
  );
}
