import 'package:akshara_erp/features/auth/auth_models.dart';
import 'package:akshara_erp/router/app_router.dart';
import 'package:akshara_erp/router/route_names.dart';
import 'package:flutter_test/flutter_test.dart';

/// QW1 · QA-J-062 — legal-acceptance gate (trap + fail-open). Exercises the pure
/// [legalGateRedirect] decision: a blocked account is trapped on the acceptance
/// screen until it accepts; an unblocked account (incl. the endpoint-down
/// default `blocked = false`) is never trapped — fail-open so a legal outage
/// cannot lock users out. (The acceptance screen UI is covered under QW3/QW7.)
void main() {
  const authed = AuthState(status: AuthStatus.authenticated, role: UserRole.parent);
  const guest = AuthState();

  group('QA-J-062: legal acceptance gate', () {
    test('blocked account is redirected to the acceptance gate', () {
      expect(
        legalGateRedirect(authed, true, RouteNames.parentDashboard),
        RouteNames.legalAcceptance,
      );
    });

    test('blocked account stays on the gate (not bounced off)', () {
      expect(
        legalGateRedirect(authed, true, RouteNames.legalAcceptance),
        isNull,
      );
    });

    test('unblocked account is sent home if it lands on the gate', () {
      expect(
        legalGateRedirect(authed, false, RouteNames.legalAcceptance),
        isNot(RouteNames.legalAcceptance),
      );
    });

    test('FAIL-OPEN: unblocked (endpoint-down default) proceeds normally', () {
      // blocked == false is the fail-open default when the legal endpoint is
      // unavailable — the user must NOT be trapped.
      expect(
        legalGateRedirect(authed, false, RouteNames.parentDashboard),
        isNull,
      );
    });

    test('unauthenticated users are never gated', () {
      expect(
        legalGateRedirect(guest, true, RouteNames.parentDashboard),
        isNull,
      );
    });
  });
}
