import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';

import 'package:akshara_erp/core/testing/qa_test_keys.dart';
import 'package:akshara_erp/features/auth/qa_login_persona.dart';
import 'package:akshara_erp/router/route_names.dart';

import '../helpers/patrol_app.dart';
import '../helpers/patrol_helpers.dart';

/// QW1 RBAC-isolation journeys for the 4 previously-missing personas
/// (QA-J-019 HR, QA-J-037 School Admin, QA-J-047 Director, QA-J-024 Staff) plus
/// the staff→/teacher cross-shell gate (QA-J-061). Proves each scoped persona
/// reaches its own module but is denied other modules + the platform
/// Control-Center — the live route-guard counterpart to the unit scoping test.

/// Asserts an ERP route is reachable for the active persona (no Access Denied).
Future<void> _reachable(
  PatrolIntegrationTester $,
  String route, {
  required String moduleRoot,
}) async {
  await goToErpRoute($, route);
  expect(
    $(QaTestKeys.accessDeniedScreen),
    findsNothing,
    reason: 'expected $route reachable for the active persona, got Access Denied',
  );
  final path = currentPatrolRoute($);
  expect(
    path.startsWith(moduleRoot),
    isTrue,
    reason: 'expected to stay on $moduleRoot, landed on $path',
  );
}

/// Asserts an ERP route is denied for the active persona. Denial manifests two
/// ways in this app: the ERP module guard renders [AccessDeniedScreen] (e.g.
/// Control-Center's role guard), OR the router redirects a permission-lacking
/// staff user back to their home shell (the route never renders). Either proves
/// denial; only genuine access (landing on the module with content) fails.
Future<void> _denied(
  PatrolIntegrationTester $,
  String route, {
  required String moduleRoot,
}) async {
  await goToErpRoute($, route);
  final showsAccessDenied = $(QaTestKeys.accessDeniedScreen).exists;
  final path = currentPatrolRoute($);
  final redirectedAway = !path.startsWith(moduleRoot);
  expect(
    showsAccessDenied || redirectedAway,
    isTrue,
    reason: 'expected $route denied (Access Denied or redirect), but the active '
        'persona landed on $path inside the module',
  );
}

void main() {
  // QA-J-019 — HR persona RBAC isolation.
  patrolTest(
    'qw1-rbac: HR reaches HR module but is denied finance and control center',
    config: aksharaPatrolConfig(),
    ($) async {
      await bootstrapAndLogin($, QaLoginPersona.hr);
      await assertVisibleKey($, QaTestKeys.adminHubScreen);
      await _reachable($, RouteNames.hrDashboard, moduleRoot: RouteNames.hr);
      await _denied($, RouteNames.financeDashboard,
          moduleRoot: RouteNames.finance);
      await _denied($, RouteNames.controlCenterDashboard,
          moduleRoot: RouteNames.controlCenter);
    },
  );

  // QA-J-037 — School Admin persona RBAC isolation.
  patrolTest(
    'qw1-rbac: School Admin reaches SIS but is denied control center',
    config: aksharaPatrolConfig(),
    ($) async {
      await bootstrapAndLogin($, QaLoginPersona.schoolAdmin);
      await assertVisibleKey($, QaTestKeys.adminHubScreen);
      await _reachable($, RouteNames.sisDashboard, moduleRoot: RouteNames.sis);
      await _denied($, RouteNames.controlCenterDashboard,
          moduleRoot: RouteNames.controlCenter);
    },
  );

  // QA-J-047 — Director persona RBAC isolation.
  patrolTest(
    'qw1-rbac: Director reaches director portal but is denied control center and SIS',
    config: aksharaPatrolConfig(),
    ($) async {
      await bootstrapAndLogin($, QaLoginPersona.director);
      await assertVisibleKey($, QaTestKeys.adminHubScreen);
      await _reachable(
        $,
        RouteNames.directorDashboard,
        moduleRoot: RouteNames.director,
      );
      await _denied($, RouteNames.controlCenterDashboard,
          moduleRoot: RouteNames.controlCenter);
      await _denied($, RouteNames.sisDashboard, moduleRoot: RouteNames.sis);
    },
  );

  // QA-J-024 + QA-J-061 — Staff (librarian) module isolation + staff to teacher
  // cross-shell gate.
  patrolTest(
    'qw1-rbac: Librarian reaches library but is denied finance and the teacher shell',
    config: aksharaPatrolConfig(),
    ($) async {
      await bootstrapAndLogin($, QaLoginPersona.staff);
      await assertVisibleKey($, QaTestKeys.adminHubScreen);
      await _reachable(
        $,
        RouteNames.libraryDashboard,
        moduleRoot: RouteNames.library,
      );
      await _denied($, RouteNames.financeDashboard,
          moduleRoot: RouteNames.finance);
      // Cross-shell: non-teaching staff cannot enter the teacher shell — the
      // router redirects them home (Admin Hub) rather than rendering the shell.
      await assertMobileForbiddenErpRoute(
        $,
        RouteNames.teacherDashboard,
        expectedHomeRoute: RouteNames.admin,
        expectedHomeScreenKey: QaTestKeys.adminHubScreen,
      );
    },
  );
}
