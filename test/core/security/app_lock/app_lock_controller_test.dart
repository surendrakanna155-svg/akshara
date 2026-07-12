// P1-SEC-1 — the App Lock state machine: cold-start lock, background→grace→
// re-lock on resume, biometric unlock (success only), enable-requires-biometric.

import 'package:akshara_erp/core/biometric/biometric_authenticator.dart';
import 'package:akshara_erp/core/security/app_lock/app_lock_providers.dart';
import 'package:akshara_erp/core/security/app_lock/app_lock_storage.dart';
import 'package:akshara_erp/core/providers/shared_preferences_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A biometric fake whose result is scripted.
class _FakeBiometric implements BiometricAuthenticator {
  _FakeBiometric(this._ok);
  bool _ok;
  int calls = 0;
  set ok(bool v) => _ok = v;
  @override
  Future<BiometricResult> authenticate({required String reason}) async {
    calls++;
    return _ok ? BiometricResult.success('face_id') : BiometricResult.failed();
  }
}

Future<ProviderContainer> _container({
  required bool enabledInPrefs,
  required _FakeBiometric biometric,
}) async {
  SharedPreferences.setMockInitialValues({
    if (enabledInPrefs) kAppLockEnabledKey: true,
  });
  final prefs = await SharedPreferences.getInstance();
  return ProviderContainer(overrides: [
    sharedPreferencesProvider.overrideWithValue(prefs),
    appLockBiometricProvider.overrideWithValue(biometric),
  ]);
}

final _t0 = DateTime.utc(2026, 7, 12, 10, 0, 0);

void main() {
  test('disabled: cold start is unlocked; lifecycle events do nothing', () async {
    final c = await _container(enabledInPrefs: false, biometric: _FakeBiometric(true));
    final ctrl = c.read(appLockControllerProvider.notifier);
    expect(c.read(appLockControllerProvider).locked, isFalse);
    ctrl.onBackground(_t0);
    ctrl.onResume(_t0.add(const Duration(minutes: 5)));
    expect(c.read(appLockControllerProvider).locked, isFalse, reason: 'no lock when disabled');
  });

  test('enabled: cold start is LOCKED and requires a biometric', () async {
    final c = await _container(enabledInPrefs: true, biometric: _FakeBiometric(true));
    expect(c.read(appLockControllerProvider).locked, isTrue, reason: 'fresh launch with App Lock on = locked');
  });

  test('a quick app-switch (under the grace window) does NOT re-lock', () async {
    final c = await _container(enabledInPrefs: true, biometric: _FakeBiometric(true));
    final ctrl = c.read(appLockControllerProvider.notifier);
    // Unlock first (simulate the cold-start unlock).
    await ctrl.unlock();
    expect(c.read(appLockControllerProvider).locked, isFalse);
    ctrl.onBackground(_t0);
    ctrl.onResume(_t0.add(const Duration(seconds: 5))); // < 15s grace
    expect(c.read(appLockControllerProvider).locked, isFalse, reason: 'brief background must not nag');
  });

  test('a real background (past the grace window) RE-LOCKS on resume', () async {
    final c = await _container(enabledInPrefs: true, biometric: _FakeBiometric(true));
    final ctrl = c.read(appLockControllerProvider.notifier);
    await ctrl.unlock();
    ctrl.onBackground(_t0);
    ctrl.onResume(_t0.add(const Duration(seconds: 30))); // > 15s grace
    expect(c.read(appLockControllerProvider).locked, isTrue);
  });

  test('unlock: a failed biometric keeps it LOCKED; a success clears it', () async {
    final bio = _FakeBiometric(false);
    final c = await _container(enabledInPrefs: true, biometric: bio);
    final ctrl = c.read(appLockControllerProvider.notifier);
    expect(await ctrl.unlock(), isFalse);
    expect(c.read(appLockControllerProvider).locked, isTrue, reason: 'no unlock on a failed biometric');
    bio.ok = true;
    expect(await ctrl.unlock(), isTrue);
    expect(c.read(appLockControllerProvider).locked, isFalse);
  });

  test('setEnabled(true): requires a successful biometric; a failure does NOT enable (no lock-out)', () async {
    final bio = _FakeBiometric(false);
    final c = await _container(enabledInPrefs: false, biometric: bio);
    final ctrl = c.read(appLockControllerProvider.notifier);
    expect(await ctrl.setEnabled(true), isFalse);
    expect(c.read(appLockControllerProvider).enabled, isFalse, reason: 'no biometric → App Lock not enabled');
    expect((await SharedPreferences.getInstance()).getBool(kAppLockEnabledKey), anyOf(isNull, isFalse));
  });

  test('setEnabled(true) with a working biometric enables + persists', () async {
    final c = await _container(enabledInPrefs: false, biometric: _FakeBiometric(true));
    final ctrl = c.read(appLockControllerProvider.notifier);
    expect(await ctrl.setEnabled(true), isTrue);
    expect(c.read(appLockControllerProvider).enabled, isTrue);
    expect((await SharedPreferences.getInstance()).getBool(kAppLockEnabledKey), isTrue);
  });

  test('setEnabled(false) disables, clears any lock, and persists — never prompts', () async {
    final bio = _FakeBiometric(true);
    final c = await _container(enabledInPrefs: true, biometric: bio);
    final ctrl = c.read(appLockControllerProvider.notifier);
    expect(c.read(appLockControllerProvider).locked, isTrue);
    final before = bio.calls;
    expect(await ctrl.setEnabled(false), isTrue);
    expect(c.read(appLockControllerProvider).enabled, isFalse);
    expect(c.read(appLockControllerProvider).locked, isFalse);
    expect(bio.calls, before, reason: 'disabling never prompts the biometric');
    expect((await SharedPreferences.getInstance()).getBool(kAppLockEnabledKey), isFalse);
  });
}
