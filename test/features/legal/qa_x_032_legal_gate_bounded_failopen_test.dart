// QA-X-032 (security) — the legal-acceptance gate fails OPEN, but the fail-open
// is BOUNDED (re-evaluated every refresh; no permanent bypass).
//
// DESIGN (lib/features/legal/legal_gate_provider.dart + lib/router/app_router.dart):
//   • refresh() catches ANY data-source error and sets phase=error, NOT blocked.
//     isBlocked is true ONLY when phase==blocked (a positive "you must accept"
//     from the server). So an outage never traps a user out of the app (fail-OPEN).
//   • legalGateRedirect(auth, blocked:false, location) returns null (pass-through)
//     — the router only diverts to the acceptance screen on a POSITIVE block.
//   • THE BOUND: every login re-runs refresh() (legalGateSyncProvider), so once the
//     source is reachable again and reports "blocked", isBlocked flips to true. The
//     fail-open is a transient grace during an outage, NOT a permanent escape hatch
//     a user can keep by staying offline-then-online.
//
// This is the security-honest framing: fail-open is acceptable for a legal gate
// ONLY because it is bounded. These tests prove BOTH halves — the open (1,2) and
// the bound (3) — against a faked remote data source.

import 'package:akshara_erp/features/auth/auth_models.dart';
import 'package:akshara_erp/features/auth/auth_token_provider.dart';
import 'package:akshara_erp/features/legal/legal_gate_provider.dart';
import 'package:akshara_erp/features/legal/legal_models.dart';
import 'package:akshara_erp/features/legal/legal_remote_data_source.dart';
import 'package:akshara_erp/router/app_router.dart';
import 'package:akshara_erp/router/route_names.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const _privacy = LegalPolicy(
  key: 'privacy',
  title: 'Privacy Policy',
  version: '2.0',
  summary: 'How we handle your data.',
  path: '/privacy',
);

LegalStatus _blocked() => const LegalStatus(
      policies: [_privacy],
      outstanding: [_privacy],
      satisfied: false,
    );

LegalStatus _satisfied() => const LegalStatus(
      policies: [_privacy],
      outstanding: [],
      satisfied: true,
    );

/// Faked remote source whose reachability + verdict we flip between refreshes.
class _ScriptedLegalDataSource implements LegalRemoteDataSource {
  _ScriptedLegalDataSource(this.next);

  /// The status the next fetchStatus() returns; if [throwNext] is set, it throws.
  LegalStatus next;
  bool throwNext = false;
  int fetchCalls = 0;

  @override
  Future<LegalStatus> fetchStatus() async {
    fetchCalls++;
    if (throwNext) throw Exception('legal endpoint unreachable');
    return next;
  }

  @override
  Future<LegalStatus> accept({
    required List<LegalPolicy> policies,
    String? deviceId,
  }) async =>
      _satisfied();
}

const _authed = AuthState(
  status: AuthStatus.authenticated,
  phoneNumber: '9876543210',
  displayName: 'Ravi Kumar',
  role: UserRole.parent,
);

ProviderContainer _container(_ScriptedLegalDataSource src) {
  final c = ProviderContainer(
    overrides: [
      legalRemoteDataSourceProvider.overrideWithValue(src),
      authTokensProvider.overrideWithValue(null),
    ],
  );
  addTearDown(c.dispose);
  return c;
}

void main() {
  group('QA-X-032: the gate fails OPEN on a source error', () {
    test('QA-X-032: when the legal source THROWS, refresh() → phase==error and '
        'isBlocked==false (app stays usable)', () async {
      final src = _ScriptedLegalDataSource(_blocked())..throwNext = true;
      final c = _container(src);

      await c.read(legalGateProvider.notifier).refresh();

      final state = c.read(legalGateProvider);
      expect(state.phase, LegalGatePhase.error);
      expect(state.isBlocked, isFalse,
          reason: 'A legal-endpoint outage must NOT block the user (fail-open).');
      expect(c.read(legalGateBlockedProvider), isFalse);
    });

    test('QA-X-032: legalGateRedirect(blocked:false) is pass-through (null) — '
        'the router never diverts without a POSITIVE block', () {
      // This is the router consequence of fail-open: error/unknown/loading all
      // surface as blocked==false, and that returns null (no redirect).
      expect(
        legalGateRedirect(_authed, false, RouteNames.parentDashboard),
        isNull,
      );
    });
  });

  group('QA-X-032: the fail-open is BOUNDED (no permanent bypass)', () {
    test('QA-X-032: after an outage, a later reachable "blocked" verdict flips '
        'isBlocked back to true on the next refresh', () async {
      // First refresh: source is DOWN → fail-open (error, not blocked).
      final src = _ScriptedLegalDataSource(_blocked())..throwNext = true;
      final c = _container(src);

      await c.read(legalGateProvider.notifier).refresh();
      expect(c.read(legalGateProvider).phase, LegalGatePhase.error);
      expect(c.read(legalGateProvider).isBlocked, isFalse);

      // Source comes BACK and reports the user is blocked. A re-check (the gate
      // re-runs refresh on every login via legalGateSyncProvider) must now block.
      src
        ..throwNext = false
        ..next = _blocked();
      await c.read(legalGateProvider.notifier).refresh();

      final state = c.read(legalGateProvider);
      expect(state.phase, LegalGatePhase.blocked,
          reason: 'A reachable "blocked" must re-block — fail-open is transient.');
      expect(state.isBlocked, isTrue);
      expect(c.read(legalGateBlockedProvider), isTrue);
      // The block then drives the router to the acceptance screen.
      expect(
        legalGateRedirect(_authed, true, RouteNames.parentDashboard),
        RouteNames.legalAcceptance,
      );
      expect(src.fetchCalls, 2, reason: 'Each refresh re-queries the source.');
    });

    test('QA-X-032: a transient outage between two satisfied checks never '
        'latches a stale block (open stays open until a positive block)', () async {
      final src = _ScriptedLegalDataSource(_satisfied());
      final c = _container(src);

      // Reachable + satisfied → not blocked.
      await c.read(legalGateProvider.notifier).refresh();
      expect(c.read(legalGateProvider).phase, LegalGatePhase.satisfied);
      expect(c.read(legalGateProvider).isBlocked, isFalse);

      // Outage → fail-open (error), still not blocked.
      src.throwNext = true;
      await c.read(legalGateProvider.notifier).refresh();
      expect(c.read(legalGateProvider).phase, LegalGatePhase.error);
      expect(c.read(legalGateProvider).isBlocked, isFalse);

      // Back + satisfied → still not blocked. No phantom block was introduced.
      src
        ..throwNext = false
        ..next = _satisfied();
      await c.read(legalGateProvider.notifier).refresh();
      expect(c.read(legalGateProvider).phase, LegalGatePhase.satisfied);
      expect(c.read(legalGateProvider).isBlocked, isFalse);
    });
  });
}
