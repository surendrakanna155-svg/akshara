// QA-X-031 (security) — Auth tokens are stored encrypted-at-rest on device.
//
// THREAT: an attacker with filesystem / backup access to a device should not be
// able to read the access/refresh tokens in plaintext. The defence is the
// storage-backend SELECTION made by createDefaultSecureStorageBackend
// (lib/core/auth/secure_storage_backend.dart):
//   • production (non-web, forcePreferences:false) MUST yield the
//     FlutterSecureStorageBackend — iOS/macOS Keychain, Android
//     EncryptedSharedPreferences → Keystore (encryptedSharedPreferences:true).
//   • the plaintext PreferencesStorageBackend is the fallback ONLY for
//     kIsWeb || forcePreferences (web has no secure enclave; forced is tests).
//
// This proves the SELECTION contract — i.e. tokens are NOT persisted to plaintext
// SharedPreferences on a real device. TokenStorage is a thin JSON wrapper over
// whichever backend it is handed (token_storage.dart), so the security boundary
// is entirely in which backend the factory picks.
//
// NOTE: these tests run on the Flutter test host (kIsWeb == false), so the
// production branch is exercised for real. The web branch is asserted via the
// forcePreferences:true equivalence (kIsWeb cannot be toggled at runtime in a
// host test; the factory treats `forcePreferences || kIsWeb` identically).

import 'package:akshara_erp/core/auth/secure_storage_backend.dart';
import 'package:akshara_erp/features/auth/token_storage.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  // Guard: this host is not web, so the production branch below is the real
  // (non-web) path. If this ever runs under web, the production assertion would
  // be vacuously satisfied — fail loudly instead.
  group('QA-X-031: production storage selection (non-web device)', () {
    test('QA-X-031: a real (non-web) device build is NOT web', () {
      expect(kIsWeb, isFalse,
          reason: 'These tests assert the on-device (non-web) selection.');
    });

    test(
        'QA-X-031: production (forcePreferences:false, non-web) yields the '
        'ENCRYPTED FlutterSecureStorageBackend, never plaintext prefs', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      final backend = createDefaultSecureStorageBackend(
        prefs,
        forcePreferences: false,
      );

      // The whole point of QA-X-031: on device, tokens go through the encrypted
      // enclave, NOT plaintext SharedPreferences.
      expect(backend, isA<FlutterSecureStorageBackend>());
      expect(backend, isNot(isA<PreferencesStorageBackend>()),
          reason: 'Tokens must not be stored in plaintext SharedPreferences.');
    });

    test('QA-X-031: the default (no flag) selection is also encrypted', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      // forcePreferences defaults to false — the production default.
      final backend = createDefaultSecureStorageBackend(prefs);

      expect(backend, isA<FlutterSecureStorageBackend>());
    });

    test(
        'QA-X-031: TokenStorage in production is wired to the encrypted backend, '
        'so persisted tokens never land in plaintext prefs', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      final backend = createDefaultSecureStorageBackend(prefs);
      // TokenStorage is backend-agnostic; what matters is which backend it wraps.
      final storage = TokenStorage(backend);

      expect(storage, isNotNull);
      expect(backend, isA<FlutterSecureStorageBackend>(),
          reason: 'TokenStorage must persist via the encrypted enclave on device.');

      // Belt-and-braces: nothing was written to plaintext SharedPreferences by
      // merely constructing the production storage.
      expect(prefs.getString(kAuthTokensStorageKey), isNull);
    });
  });

  // The fallback is intentional and bounded: web has no secure enclave, and
  // tests force it. The factory treats `forcePreferences || kIsWeb` the same, so
  // forcePreferences:true is the runtime-testable equivalent of the web branch.
  group('QA-X-031: bounded plaintext fallback (web / forced only)', () {
    test('QA-X-031: forcePreferences:true (the web/test branch) yields '
        'PreferencesStorageBackend', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      final backend = createDefaultSecureStorageBackend(
        prefs,
        forcePreferences: true,
      );

      // Allowed plaintext fallback — web/tests only, never a real device build.
      expect(backend, isA<PreferencesStorageBackend>());
      expect(backend, isNot(isA<FlutterSecureStorageBackend>()));
    });

    test('QA-X-031: the forced fallback still round-trips tokens (functional, '
        'just not encrypted)', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final backend = createDefaultSecureStorageBackend(
        prefs,
        forcePreferences: true,
      );

      await backend.write('k', 'v');
      expect(await backend.read('k'), 'v');
      // On the plaintext branch the value IS visible in SharedPreferences — which
      // is exactly why this branch is gated to web/tests, not device builds.
      expect(prefs.getString('k'), 'v');
    });
  });
}
