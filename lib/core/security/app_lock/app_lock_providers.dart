import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../biometric/biometric_authenticator.dart';
import '../../providers/shared_preferences_provider.dart';
import 'app_lock_controller.dart';
import 'app_lock_storage.dart';

/// P1-SEC-1 — App Lock wiring.

/// Persistence for the App Lock preference. Null when SharedPreferences is not
/// overridden (bare widget tests) — the controller then defaults to disabled.
final appLockStorageProvider = Provider<AppLockStorage?>((ref) {
  try {
    return AppLockStorage(ref.watch(sharedPreferencesProvider));
  } on StateError {
    return null;
  }
});

/// The device biometric used for App Lock (overridable in tests with a fake).
final appLockBiometricProvider = Provider<BiometricAuthenticator>(
  (ref) => LocalAuthBiometricAuthenticator(),
);

/// App-wide App Lock state (enabled/locked).
final appLockControllerProvider =
    NotifierProvider<AppLockController, AppLockState>(AppLockController.new);
