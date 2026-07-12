// P1-SEC-1 — the App Lock overlay: auto-prompts, stays until a successful
// unlock, and (via the settings toggle) enabling requires a biometric.

import 'package:akshara_erp/core/biometric/biometric_authenticator.dart';
import 'package:akshara_erp/core/providers/shared_preferences_provider.dart';
import 'package:akshara_erp/core/security/app_lock/app_lock_overlay.dart';
import 'package:akshara_erp/core/security/app_lock/app_lock_providers.dart';
import 'package:akshara_erp/core/security/app_lock/app_lock_storage.dart';
import 'package:akshara_erp/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
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
  testWidgets('overlay auto-prompts on mount; a FAILED biometric keeps it up + shows the retry hint',
      (tester) async {
    final bio = _FakeBiometric(false);
    await tester.pumpWidget(ProviderScope(
      overrides: await _overrides(true, bio),
      child: MaterialApp(theme: AksharaAppTheme.light(), home: const Scaffold(body: AppLockOverlay())),
    ));
    await tester.pumpAndSettle();
    expect(bio.calls, greaterThanOrEqualTo(1), reason: 'auto-prompted');
    expect(find.byKey(const Key('app-lock-overlay')), findsOneWidget);
    expect(find.byKey(const Key('app-lock-failed')), findsOneWidget);
    expect(find.text('Akshara is locked'), findsOneWidget);
  });

  testWidgets('tapping Unlock with a working biometric clears the lock in the controller',
      (tester) async {
    final bio = _FakeBiometric(false); // auto-prompt fails first
    final overrides = await _overrides(true, bio);
    late ProviderContainer container;
    await tester.pumpWidget(ProviderScope(
      overrides: overrides,
      child: Consumer(builder: (context, ref, _) {
        container = ProviderScope.containerOf(context);
        return MaterialApp(theme: AksharaAppTheme.light(), home: const Scaffold(body: AppLockOverlay()));
      }),
    ));
    await tester.pumpAndSettle();
    expect(container.read(appLockControllerProvider).locked, isTrue);
    bio.ok = true; // now the biometric works
    await tester.tap(find.byKey(const Key('app-lock-unlock-button')));
    await tester.pumpAndSettle();
    expect(container.read(appLockControllerProvider).locked, isFalse, reason: 'success clears the lock');
  });
}
