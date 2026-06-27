import 'package:akshara_erp/features/auth/auth_models.dart';
import 'package:akshara_erp/features/auth/auth_token_provider.dart';
import 'package:akshara_erp/features/legal/legal_acceptance_screen.dart';
import 'package:akshara_erp/features/legal/legal_gate_provider.dart';
import 'package:akshara_erp/features/legal/legal_models.dart';
import 'package:akshara_erp/features/legal/legal_remote_data_source.dart';
import 'package:akshara_erp/router/app_router.dart';
import 'package:akshara_erp/router/route_names.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../test_helpers.dart';

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

/// In-memory stand-in for the network data source (no HTTP).
class _FakeLegalDataSource implements LegalRemoteDataSource {
  _FakeLegalDataSource(this._status, {this.acceptResult});

  final LegalStatus _status;
  LegalStatus? acceptResult;
  int acceptCalls = 0;
  bool throwOnFetch = false;

  @override
  Future<LegalStatus> fetchStatus() async {
    if (throwOnFetch) throw Exception('endpoint unavailable');
    return _status;
  }

  @override
  Future<LegalStatus> accept({
    required List<LegalPolicy> policies,
    String? deviceId,
  }) async {
    acceptCalls++;
    return acceptResult ?? _satisfied();
  }
}

const _authedParent = AuthState(
  status: AuthStatus.authenticated,
  phoneNumber: '9876543210',
  displayName: 'Ravi Kumar',
  role: UserRole.parent,
);

const _unauthenticated = AuthState(status: AuthStatus.unauthenticated);

void main() {
  // The pure redirect function the router uses — this is the authoritative
  // answer to "does it ask at first time?".
  group('legalGateRedirect (the gate decision)', () {
    test('FIRST-TIME LOGIN: authenticated user with outstanding policies is '
        'sent to the acceptance gate', () {
      expect(
        legalGateRedirect(_authedParent, true, RouteNames.parentDashboard),
        RouteNames.legalAcceptance,
      );
    });

    test('ACCEPTED USER: not blocked → stays where they are (not asked again)',
        () {
      expect(
        legalGateRedirect(_authedParent, false, RouteNames.parentDashboard),
        isNull,
      );
    });

    test('unauthenticated users are never gated', () {
      expect(
        legalGateRedirect(_unauthenticated, true, RouteNames.parentDashboard),
        isNull,
      );
    });

    test('a blocked user already on the gate is allowed to stay there', () {
      expect(
        legalGateRedirect(_authedParent, true, RouteNames.legalAcceptance),
        isNull,
      );
    });

    test('a satisfied user who opens the gate is sent home (never trapped)', () {
      expect(
        legalGateRedirect(_authedParent, false, RouteNames.legalAcceptance),
        RouteNames.parentDashboard,
      );
    });
  });

  group('LegalGateController', () {
    test('a first-time user (outstanding policies) resolves to BLOCKED', () async {
      final fake = _FakeLegalDataSource(_blocked());
      final container = ProviderContainer(
        overrides: [
          legalRemoteDataSourceProvider.overrideWithValue(fake),
          authTokensProvider.overrideWithValue(null),
        ],
      );
      addTearDown(container.dispose);

      expect(container.read(legalGateProvider).phase, LegalGatePhase.unknown);

      await container.read(legalGateProvider.notifier).refresh();

      expect(container.read(legalGateProvider).phase, LegalGatePhase.blocked);
      expect(container.read(legalGateProvider).isBlocked, isTrue);
      expect(container.read(legalGateProvider).outstanding, hasLength(1));
      expect(container.read(legalGateBlockedProvider), isTrue);
    });

    test('accepting the outstanding policies clears the gate (SATISFIED)',
        () async {
      final fake = _FakeLegalDataSource(_blocked(), acceptResult: _satisfied());
      final container = ProviderContainer(
        overrides: [
          legalRemoteDataSourceProvider.overrideWithValue(fake),
          authTokensProvider.overrideWithValue(null),
        ],
      );
      addTearDown(container.dispose);

      await container.read(legalGateProvider.notifier).refresh();
      expect(container.read(legalGateProvider).isBlocked, isTrue);

      final ok =
          await container.read(legalGateProvider.notifier).acceptOutstanding();

      expect(ok, isTrue);
      expect(fake.acceptCalls, 1);
      expect(container.read(legalGateProvider).phase, LegalGatePhase.satisfied);
      expect(container.read(legalGateBlockedProvider), isFalse);
    });

    test('an endpoint error is FAIL-OPEN (error phase, never blocks)', () async {
      final fake = _FakeLegalDataSource(_blocked())..throwOnFetch = true;
      final container = ProviderContainer(
        overrides: [
          legalRemoteDataSourceProvider.overrideWithValue(fake),
          authTokensProvider.overrideWithValue(null),
        ],
      );
      addTearDown(container.dispose);

      await container.read(legalGateProvider.notifier).refresh();

      expect(container.read(legalGateProvider).phase, LegalGatePhase.error);
      expect(container.read(legalGateProvider).isBlocked, isFalse);
      expect(container.read(legalGateBlockedProvider), isFalse);
    });
  });

  group('LegalStatus.fromEnvelope', () {
    test('parses the {data:{...}} envelope', () {
      final status = LegalStatus.fromEnvelope({
        'data': {
          'satisfied': false,
          'policies': [
            {
              'key': 'privacy',
              'title': 'Privacy Policy',
              'version': '2.0',
              'summary': 's',
              'path': '/privacy',
            }
          ],
          'outstanding': [
            {
              'key': 'privacy',
              'title': 'Privacy Policy',
              'version': '2.0',
              'summary': 's',
              'path': '/privacy',
            }
          ],
        },
        'error': null,
      });

      expect(status.satisfied, isFalse);
      expect(status.outstanding, hasLength(1));
      expect(status.outstanding.first.key, 'privacy');
      expect(status.outstanding.first.version, '2.0');
    });

    test('an empty/garbage body yields satisfied (nothing outstanding)', () {
      final status = LegalStatus.fromEnvelope(null);
      expect(status.satisfied, isTrue);
      expect(status.outstanding, isEmpty);
    });
  });

  group('end-to-end through the real app router', () {
    testWidgets('FIRST-TIME LOGIN: the app redirects to the legal gate screen',
        (tester) async {
      final router = createAppRouter(
        readAuth: () => _authedParent,
        readLegalBlocked: () => true,
      );

      await pumpAksharaRouter(
        tester,
        router: router,
        authOverride: _authedParent,
        overrides: [
          legalRemoteDataSourceProvider
              .overrideWithValue(_FakeLegalDataSource(_blocked())),
          authTokensProvider.overrideWithValue(null),
        ],
      );

      router.go(RouteNames.parentDashboard);
      await tester.pumpAndSettle();

      expect(
        router.routeInformationProvider.value.uri.path,
        RouteNames.legalAcceptance,
      );
      expect(find.byType(LegalAcceptanceScreen), findsOneWidget);
    });

    testWidgets('ACCEPTED USER: reaches the dashboard without being asked',
        (tester) async {
      final router = createAppRouter(
        readAuth: () => _authedParent,
        readLegalBlocked: () => false,
      );

      await pumpAksharaRouter(
        tester,
        router: router,
        authOverride: _authedParent,
        overrides: [
          legalRemoteDataSourceProvider
              .overrideWithValue(_FakeLegalDataSource(_satisfied())),
          authTokensProvider.overrideWithValue(null),
        ],
      );

      router.go(RouteNames.parentDashboard);
      await tester.pumpAndSettle();

      expect(
        router.routeInformationProvider.value.uri.path,
        RouteNames.parentDashboard,
      );
    });
  });

  group('LegalAcceptanceScreen', () {
    testWidgets('shows outstanding policies and records acceptance', (
      tester,
    ) async {
      final fake = _FakeLegalDataSource(_blocked(), acceptResult: _satisfied());

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            legalRemoteDataSourceProvider.overrideWithValue(fake),
            authTokensProvider.overrideWithValue(null),
          ],
          child: const MaterialApp(home: LegalAcceptanceScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Privacy Policy'), findsOneWidget);
      expect(find.byKey(LegalAcceptanceScreen.acceptButtonKey), findsOneWidget);

      // Accept is gated behind the "I have read and agree" checkbox.
      await tester.tap(find.byKey(LegalAcceptanceScreen.agreeCheckboxKey));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(LegalAcceptanceScreen.acceptButtonKey));
      await tester.pumpAndSettle();

      expect(fake.acceptCalls, 1);
    });
  });
}
