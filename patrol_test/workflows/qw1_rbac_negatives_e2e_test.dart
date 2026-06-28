import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';

import 'package:akshara_erp/core/testing/qa_test_keys.dart';
import 'package:akshara_erp/features/auth/qa_login_persona.dart';
import 'package:akshara_erp/router/route_names.dart';

import '../helpers/patrol_app.dart';
import '../helpers/patrol_helpers.dart';

/// QW1 RBAC negatives — Control-Center guard (QA-J-052) and ChainScope gating
/// (QA-J-048). Complements the persona isolation suite: proves the platform
/// Control-Center is Super-Admin-only and chain-only modules are blocked for a
/// single-school org.

Future<void> _expectAccessDenied(PatrolIntegrationTester $, String route) async {
  await goToErpRoute($, route);
  await assertVisibleKey($, QaTestKeys.accessDeniedScreen);
}

/// Navigates to [route] and asserts it is REACHED (active + no Access-Denied
/// screen) — the positive counterpart to [_expectAccessDenied].
Future<void> _expectRouteReached(
  PatrolIntegrationTester $,
  String route,
) async {
  await goToErpRoute($, route);
  await assertPatrolRoute($, route);
  expect($(QaTestKeys.accessDeniedScreen), findsNothing);
}

void main() {
  // QA-J-052 — Control-Center is Super-Admin-only: Finance (a permissioned staff
  // role) is denied; Super Admin is allowed.
  patrolTest(
    'qw1-rbac-neg: finance is denied the control center',
    config: aksharaPatrolConfig(),
    ($) async {
      await bootstrapAndLogin($, QaLoginPersona.finance);
      await _expectAccessDenied($, RouteNames.controlCenterDashboard);
    },
  );

  patrolTest(
    'qw1-rbac-neg: super admin reaches the control center',
    config: aksharaPatrolConfig(),
    ($) async {
      await bootstrapAndLogin($, QaLoginPersona.superAdmin);
      await goToErpRoute($, RouteNames.controlCenterDashboard);
      await assertPatrolRoute($, RouteNames.controlCenterDashboard);
      expect($(QaTestKeys.accessDeniedScreen), findsNothing);
    },
  );

  // QA-J-048 (negative) — ChainScope: a single-school director is denied
  // chain-only modules (franchise / multi-school / organization-builder).
  patrolTest(
    'qw1-rbac-neg: single-school director is denied chain-only modules',
    config: aksharaPatrolConfig(),
    ($) async {
      await bootstrapAndLogin($, QaLoginPersona.director);
      await _expectAccessDenied($, RouteNames.franchise);
      await _expectAccessDenied($, RouteNames.multiSchoolPortfolio);
      await _expectAccessDenied($, RouteNames.organizationBuilder);
    },
  );

  // QA-J-048 (positive) — ChainScope: a CHAIN-org director (chain perms +
  // isChainOrganization) IS allowed the same chain-only modules. Together with
  // the negative above this proves the gate is the chain flag, not the perms:
  // the single-school director is denied, the chain director is granted.
  patrolTest(
    'qw1-rbac-pos: chain-org director reaches chain-only modules',
    config: aksharaPatrolConfig(),
    ($) async {
      await bootstrapAndLogin($, QaLoginPersona.chainDirector);
      await _expectRouteReached($, RouteNames.franchise);
      await _expectRouteReached($, RouteNames.multiSchoolPortfolio);
      await _expectRouteReached($, RouteNames.organizationBuilder);
    },
  );
}
