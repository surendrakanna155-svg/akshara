// P1-SEC-1 — the App Lock overlay: auto-prompts, stays until a successful
// unlock, FULLY blocks the content behind it (audit F2), and offers a sign-out
// escape (audit F3).

import 'package:akshara_erp/core/biometric/biometric_authenticator.dart';
import 'package:akshara_erp/core/providers/shared_preferences_provider.dart';
import 'package:akshara_erp/core/security/app_lock/app_lock_overlay.dart';
import 'package:akshara_erp/core/security/app_lock/app_lock_providers.dart';
import 'package:akshara_erp/core/security/app_lock/app_lock_storage.dart';
import 'package:akshara_erp/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeBiometric implements BiometricAuthenticator {
  _FakeBiometric(this.ok);
  bool ok;
  int calls = 0;
  @override
  Future<BiometricResult> authenticate({required String reason}) async {
    calls++;
    return ok ? BiometricResult.success('face_id') : BiometricResult.failed();
  }
}

Future<List<Override>> _overrides(bool enabled, _FakeBiometric bio) async {
  SharedPreferences.setMockInitialValues({if (enabled) kAppLockEnabledKey: true});
  final prefs = await SharedPreferences.getInstance();
  return [
    sharedPreferencesProvider.overrideWithValue(prefs),
    appLockBiometricProvider.overrideWithValue(bio),
  ];
}

void main() {
  testWidgets('overlay auto-prompts; a FAILED biometric keeps it up + shows the retry/sign-out hint',
      (tester) async {
    final bio = _FakeBiometric(false);
    await tester.pumpWidget(ProviderScope(
      overrides: await _overrides(true, bio),
      child: MaterialApp(
        theme: AksharaAppTheme.light(),
        home: Scaffold(body: AppLockOverlay(onSignOut: () async {})),
      ),
    ));
    await tester.pumpAndSettle();
    expect(bio.calls, greaterThanOrEqualTo(1));
    expect(find.byKey(const Key('app-lock-overlay')), findsOneWidget);
    expect(find.byKey(const Key('app-lock-failed')), findsOneWidget);
  });

  testWidgets('audit F2: a tap in the overlay MARGIN does NOT reach the content behind it', (tester) async {
    var contentTapped = false;
    await tester.pumpWidget(ProviderScope(
      overrides: await _overrides(true, _FakeBiometric(false)),
      child: MaterialApp(
        theme: AksharaAppTheme.light(),
        home: Scaffold(
          body: Stack(
            children: [
              // Full-screen tappable content simulating the app behind the lock.
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => contentTapped = true,
                  child: const SizedBox.expand(),
                ),
              ),
              Positioned.fill(child: AppLockOverlay(onSignOut: () async {})),
            ],
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();
    // Tap the top-left corner — well outside the centered lock card.
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();
    expect(contentTapped, isFalse, reason: 'the overlay must absorb taps, not pass them through');
  });

  testWidgets('audit F3: "Sign out instead" confirms inline then invokes the sign-out escape', (tester) async {
    var signedOut = false;
    await tester.pumpWidget(ProviderScope(
      overrides: await _overrides(true, _FakeBiometric(false)),
      child: MaterialApp(
        theme: AksharaAppTheme.light(),
        home: Scaffold(body: AppLockOverlay(onSignOut: () async => signedOut = true)),
      ),
    ));
    await tester.pumpAndSettle();
    // No confirm control is shown until the user asks to sign out.
    expect(find.byKey(const Key('app-lock-signout-confirm')), findsNothing);
    await tester.tap(find.byKey(const Key('app-lock-signout-button')));
    await tester.pumpAndSettle();
    // Inline confirm appears; Cancel returns to the lock card.
    expect(find.byKey(const Key('app-lock-signout-confirm')), findsOneWidget);
    await tester.tap(find.byKey(const Key('app-lock-signout-cancel')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('app-lock-signout-confirm')), findsNothing);
    // Re-open and confirm → the escape fires.
    await tester.tap(find.byKey(const Key('app-lock-signout-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('app-lock-signout-confirm')));
    await tester.pumpAndSettle();
    expect(signedOut, isTrue);
  });

  testWidgets(
      'audit P0-1: the sign-out escape works with NO Navigator ancestor (MaterialApp.router builder — the production mount)',
      (tester) async {
    // Reproduces the real tree: the overlay lives in the MaterialApp.router
    // BUILDER, a sibling of GoRouter's Navigator, so it has no Navigator/
    // ModalRoute ancestor. The old showDialog-based confirm threw here (silently
    // breaking the F3 escape → permanent lock-out); the inline confirm must not.
    var signedOut = false;
    final router = GoRouter(
      routes: [GoRoute(path: '/', builder: (_, __) => const Scaffold(body: SizedBox.shrink()))],
    );
    await tester.pumpWidget(ProviderScope(
      overrides: await _overrides(true, _FakeBiometric(false)),
      child: MaterialApp.router(
        theme: AksharaAppTheme.light(),
        routerConfig: router,
        builder: (context, child) => Stack(
          children: [
            child ?? const SizedBox.shrink(),
            Positioned.fill(child: AppLockOverlay(onSignOut: () async => signedOut = true)),
          ],
        ),
      ),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('app-lock-signout-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('app-lock-signout-confirm')));
    await tester.pumpAndSettle();
    expect(signedOut, isTrue, reason: 'inline confirm must not depend on a Navigator ancestor');
    expect(tester.takeException(), isNull);
  });

  testWidgets('tapping Unlock with a working biometric clears the lock in the controller', (tester) async {
    final bio = _FakeBiometric(false);
    late ProviderContainer container;
    await tester.pumpWidget(ProviderScope(
      overrides: await _overrides(true, bio),
      child: Consumer(builder: (context, ref, _) {
        container = ProviderScope.containerOf(context);
        return MaterialApp(
          theme: AksharaAppTheme.light(),
          home: Scaffold(body: AppLockOverlay(onSignOut: () async {})),
        );
      }),
    ));
    await tester.pumpAndSettle();
    expect(container.read(appLockControllerProvider).locked, isTrue);
    bio.ok = true;
    await tester.tap(find.byKey(const Key('app-lock-unlock-button')));
    await tester.pumpAndSettle();
    expect(container.read(appLockControllerProvider).locked, isFalse);
  });
}
