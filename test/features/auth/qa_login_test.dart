import 'package:akshara_erp/core/config/chain_scope.dart';
import 'package:akshara_erp/core/config/environment.dart';
import 'package:akshara_erp/core/config/environment_provider.dart';
import 'package:akshara_erp/core/security/rbac_service.dart';
import 'package:akshara_erp/features/auth/auth_models.dart';
import 'package:akshara_erp/features/auth/auth_provider.dart';
import 'package:akshara_erp/features/auth/qa_login_persona.dart';
import 'package:akshara_erp/features/auth/qa_login_screen.dart';
import 'package:akshara_erp/router/route_guards.dart';
import 'package:akshara_erp/router/route_names.dart';
import 'package:akshara_erp/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../helpers/provider_test_overrides.dart';
import '../../test_helpers.dart';

Environment get _qaEnvironment => Environment.development.copyWith(
      enableQaLogin: true,
      disableDemoAuth: false,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    await initProviderTestPrefs();
  });

  group('QA login mode', () {
    testWidgets('shows persona buttons when QA login is enabled', (tester) async {
      useMobileViewport(tester);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            environmentProvider.overrideWith((ref) => _qaEnvironment),
            ...providerTestOverrides(),
          ],
          child: MaterialApp(
            theme: AksharaAppTheme.light(),
            home: const QaLoginScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // The persona list is a lazily-built ListView; scroll each button into
      // view before asserting (the list now exceeds a single mobile viewport).
      final scrollable = find.byType(Scrollable).first;
      for (final persona in QaLoginPersona.values) {
        final finder = find.text(persona.buttonLabel);
        await tester.scrollUntilVisible(finder, 80, scrollable: scrollable);
        expect(finder, findsOneWidget);
      }
    });

    testWidgets('parent persona opens parent dashboard route', (tester) async {
      useMobileViewport(tester);

      final router = GoRouter(
        initialLocation: RouteNames.qaLogin,
        routes: [
          GoRoute(
            path: RouteNames.qaLogin,
            builder: (context, state) => const QaLoginScreen(),
          ),
          GoRoute(
            path: RouteNames.parentDashboard,
            builder: (context, state) => const Scaffold(body: Text('Fees')),
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            environmentProvider.overrideWith((ref) => _qaEnvironment),
            ...providerTestOverrides(),
          ],
          child: MaterialApp.router(
            theme: AksharaAppTheme.light(),
            routerConfig: router,
          ),
        ),
      );

      await tester.pumpAndSettle();

      await tester.tap(find.text('Parent'));
      await tester.pumpAndSettle();

      expect(
        router.routeInformationProvider.value.uri.path,
        RouteNames.parentDashboard,
      );
    });

    test('signInQaPersona assigns role and authenticated status', () async {
      final container = ProviderContainer(
        overrides: [
          environmentProvider.overrideWith((ref) => _qaEnvironment),
          ...providerTestOverrides(),
        ],
      );
      addTearDown(container.dispose);

      await container.read(authProvider.notifier).signInQaPersona(
            QaLoginPersona.teacher,
          );

      final auth = container.read(authProvider);
      expect(auth.status, AuthStatus.authenticated);
      expect(auth.role, UserRole.teacher);
    });

    test(
        'QA-J-048 positive: chain-director persona flags a chain org and reaches '
        'chain-only modules through the real login + guard wiring', () async {
      final container = ProviderContainer(
        overrides: [
          environmentProvider.overrideWith((ref) => _qaEnvironment),
          ...providerTestOverrides(),
        ],
      );
      addTearDown(container.dispose);

      await container.read(authProvider.notifier).signInQaPersona(
            QaLoginPersona.chainDirector,
          );

      // The chain flag flows persona.isChainOrg → signInStaff → claims →
      // isChainOrgProvider, which is the ChainScope gate's grant condition.
      expect(container.read(authProvider).status, AuthStatus.authenticated);
      expect(container.read(isChainOrgProvider), isTrue);

      // Pure-RBAC reachability: the persona's curated perms include the
      // chain-only view perms (honored by userPermissionsProvider in QA builds).
      final rbac = container.read(rbacServiceProvider);
      for (final route in const [
        RouteNames.franchise,
        RouteNames.multiSchoolPortfolio,
        RouteNames.organizationBuilder,
      ]) {
        expect(ChainScope.isChainOnlyRoute(route), isTrue,
            reason: '$route must be chain-gated');
        expect(canAccessErpRoute(rbac, route), isTrue,
            reason: 'chain director must hold the view perm for $route');
      }

      // Still scoped — the platform control-center stays denied.
      expect(
        canAccessErpRoute(rbac, RouteNames.controlCenterDashboard),
        isFalse,
      );
    });

    test('QA-J-048 negative: single-school director does NOT flag a chain org',
        () async {
      final container = ProviderContainer(
        overrides: [
          environmentProvider.overrideWith((ref) => _qaEnvironment),
          ...providerTestOverrides(),
        ],
      );
      addTearDown(container.dispose);

      await container.read(authProvider.notifier).signInQaPersona(
            QaLoginPersona.director,
          );

      expect(container.read(isChainOrgProvider), isFalse);
      // No chain perm either — chain routes are denied at the pure-RBAC layer,
      // and the ChainScope gate would block them regardless.
      final rbac = container.read(rbacServiceProvider);
      expect(canAccessErpRoute(rbac, RouteNames.franchise), isFalse);
    });

    test('signInQaPersona is blocked when QA login disabled', () async {
      final container = ProviderContainer(
        overrides: [
          environmentProvider.overrideWith(
            (ref) => Environment.development.copyWith(enableQaLogin: false),
          ),
          ...providerTestOverrides(),
        ],
      );
      addTearDown(container.dispose);

      expect(
        () => container.read(authProvider.notifier).signInQaPersona(
              QaLoginPersona.parent,
            ),
        throwsA(isA<StateError>()),
      );
    });
  });
}
