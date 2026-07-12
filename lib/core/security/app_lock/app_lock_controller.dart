import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../biometric/biometric_authenticator.dart';
import 'app_lock_providers.dart';

/// P1-SEC-1 — the biometric App Lock state.
///  - [enabled]: the user turned App Lock on (persisted, device-level).
///  - [locked]: the app content is hidden behind the lock overlay until a
///    successful biometric unlock.
class AppLockState {
  const AppLockState({required this.enabled, required this.locked});

  final bool enabled;
  final bool locked;

  AppLockState copyWith({bool? enabled, bool? locked}) => AppLockState(
        enabled: enabled ?? this.enabled,
        locked: locked ?? this.locked,
      );

  @override
  bool operator ==(Object other) =>
      other is AppLockState && other.enabled == enabled && other.locked == locked;

  @override
  int get hashCode => Object.hash(enabled, locked);
}

/// The App Lock state machine. Pure of platform I/O except the injected
/// [BiometricAuthenticator]; the lifecycle clock is passed IN (DateTime) so the
/// grace-window logic is deterministically unit-testable.
///
/// Semantics:
///  - Cold start: `locked == enabled` — if App Lock is on, a fresh launch is
///    locked and requires a biometric before the app is revealed.
///  - Background then resume: if App Lock is on AND the app was backgrounded for
///    at least [graceWindow], it re-locks on resume. A quick app-switch (under
///    the grace window) does NOT re-prompt — avoids nagging on notification
///    peeks / camera returns while still protecting a real background.
///  - [unlock] runs the device biometric; ONLY a success clears the lock (there
///    is no PIN/passcode fallback — same hard-block philosophy as check-in).
class AppLockController extends Notifier<AppLockState> {
  /// A background shorter than this does not re-lock on resume.
  static const Duration graceWindow = Duration(seconds: 15);

  DateTime? _backgroundedAt;

  @override
  AppLockState build() {
    final enabled = ref.read(appLockStorageProvider)?.readEnabled() ?? false;
    return AppLockState(enabled: enabled, locked: enabled);
  }

  /// Lifecycle: the app went to the background. Record when, so resume can
  /// decide whether the away-time crossed the grace window.
  void onBackground(DateTime now) {
    if (!state.enabled) return;
    _backgroundedAt = now;
  }

  /// Lifecycle: the app returned to the foreground. Re-lock iff enabled and the
  /// away-time reached the grace window.
  void onResume(DateTime now) {
    if (!state.enabled || state.locked) return;
    final since = _backgroundedAt;
    if (since != null && now.difference(since) >= graceWindow) {
      state = state.copyWith(locked: true);
    }
    _backgroundedAt = null;
  }

  /// Runs the biometric; clears the lock only on success. Returns whether the
  /// app is now unlocked.
  Future<bool> unlock() async {
    if (!state.locked) return true;
    final result = await ref
        .read(appLockBiometricProvider)
        .authenticate(reason: 'Unlock Akshara');
    if (result.authenticated) {
      state = state.copyWith(locked: false);
      return true;
    }
    return false;
  }

  /// Enable/disable App Lock. Enabling requires a real biometric to exist AND a
  /// successful prompt first — otherwise a user with no enrolled biometric would
  /// lock themselves out permanently. Returns whether the new state took effect.
  /// Disabling always succeeds and clears any active lock.
  Future<bool> setEnabled(bool enabled) async {
    if (enabled == state.enabled) return true;
    if (!enabled) {
      state = const AppLockState(enabled: false, locked: false);
      await ref.read(appLockStorageProvider)?.writeEnabled(false);
      return true;
    }
    // Enabling: prove a biometric works on this device before we commit to it.
    final result = await ref
        .read(appLockBiometricProvider)
        .authenticate(reason: 'Confirm your biometric to turn on App Lock');
    if (!result.authenticated) return false;
    state = const AppLockState(enabled: true, locked: false);
    await ref.read(appLockStorageProvider)?.writeEnabled(true);
    return true;
  }
}
