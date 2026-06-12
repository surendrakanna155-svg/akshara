import 'package:akshara_erp/core/config/environment.dart';
import 'package:akshara_erp/core/config/environment_provider.dart';
import 'package:akshara_erp/core/providers/router_provider.dart';
import 'package:akshara_erp/features/auth/login_screen.dart';
import 'package:akshara_erp/features/auth/otp_verification_screen.dart';
import 'package:akshara_erp/router/route_names.dart';
import 'package:akshara_erp/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../helpers/provider_test_overrides.dart';
import '../../test_helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    await initProviderTestPrefs();
  });

  group('first-run navigation', () {
    testWidgets('OTP app bar back returns to login when OTP is pending', (
      tester,
    ) async {
      useMobileViewport(tester);

      late GoRouter router;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            environmentProvider.overrideWith((ref) => Environment.development),
            ...providerTestOverrides(),
          ],
          child: Consumer(
            builder: (context, ref, _) {
              router = ref.watch(goRouterProvider);
              return MaterialApp.router(
                theme: AksharaAppTheme.light(),
                routerConfig: router,
              );
            },
          ),
        ),
      );

      await tester.pump();
      router.go(RouteNames.login);
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextFormField), '9876543210');
      await tester.tap(find.text('Continue'));
      await tester.pump(const Duration(milliseconds: 700));
      await tester.pumpAndSettle();

      expect(find.byType(OtpVerificationScreen), findsOneWidget);
      expect(
        router.routeInformationProvider.value.uri.path,
        RouteNames.otpVerification,
      );

      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pumpAndSettle();

      expect(find.byType(LoginScreen), findsOneWidget);
      expect(
        router.routeInformationProvider.value.uri.path,
        RouteNames.login,
      );
    });

    testWidgets('system back from OTP returns to login', (tester) async {
      useMobileViewport(tester);

      late GoRouter router;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            environmentProvider.overrideWith((ref) => Environment.development),
            ...providerTestOverrides(),
          ],
          child: Consumer(
            builder: (context, ref, _) {
              router = ref.watch(goRouterProvider);
              return MaterialApp.router(
                theme: AksharaAppTheme.light(),
                routerConfig: router,
              );
            },
          ),
        ),
      );

      await tester.pump();
      router.go(RouteNames.login);
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextFormField), '9876543210');
      await tester.tap(find.text('Continue'));
      await tester.pump(const Duration(milliseconds: 700));
      await tester.pumpAndSettle();

      expect(find.byType(OtpVerificationScreen), findsOneWidget);

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      expect(find.byType(LoginScreen), findsOneWidget);
      expect(
        router.routeInformationProvider.value.uri.path,
        RouteNames.login,
      );
    });
  });
}
