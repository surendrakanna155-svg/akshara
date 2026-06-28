import 'package:patrol/patrol.dart';

import 'package:akshara_erp/core/testing/qa_test_keys.dart';
import 'package:akshara_erp/features/auth/qa_login_persona.dart';
import 'package:akshara_erp/router/route_names.dart';

import '../helpers/patrol_app.dart';
import '../helpers/patrol_helpers.dart';

/// QW1 · QA-J-009 — Student RBAC isolation across product shells. A student
/// session deep-linking into the parent shell (/parent/*) and the teacher shell
/// (/teacher/*) must NOT land there — the role-aware router redirects the
/// student home. Complements red_team_route_security (student blocked from the
/// admin hub / control-center) by covering the other two product shells.

void main() {
  patrolTest(
    'qw1-j009: student is redirected away from the parent shell',
    config: aksharaPatrolConfig(),
    ($) async {
      await bootstrapAndLogin($, QaLoginPersona.student);
      await assertMobileForbiddenErpRoute(
        $,
        RouteNames.parentDashboard,
        expectedHomeRoute: RouteNames.studentDashboard,
        expectedHomeScreenKey: QaTestKeys.studentDashboardScreen,
      );
    },
  );

  patrolTest(
    'qw1-j009: student is redirected away from the teacher shell',
    config: aksharaPatrolConfig(),
    ($) async {
      await bootstrapAndLogin($, QaLoginPersona.student);
      await assertMobileForbiddenErpRoute(
        $,
        RouteNames.teacherDashboard,
        expectedHomeRoute: RouteNames.studentDashboard,
        expectedHomeScreenKey: QaTestKeys.studentDashboardScreen,
      );
    },
  );
}
