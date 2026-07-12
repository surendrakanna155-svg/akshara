import 'package:flutter/widgets.dart' show AppLifecycleState;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../biometric/biometric_authenticator.dart';
import 'app_lock_providers.dart';

/// Whether a lifecycle transition is a TRUE background that should arm the App
/// Lock timer (audit F1). ONLY `paused`/`detached` — NOT `inactive`/`hidden`,
/// which also fire transiently during the resume handshake
/// (paused→hidden→inactive→resumed); arming on those would reset the timer at
/// ~resume time and silently defeat re-lock. Pure so the app-shell wiring is
/// unit-testable.
bool appLockArmsOnBackground(AppLifecycleState state) =>
    state == AppLifecycleState.paused || state == AppLifecycleState.detached;

/// Whether a lifecycle state should engage the PRIVACY SCRIM that hides content
/// from the OS app-switcher / recents snapshot while App Lock is enabled (audit
/// P1-1). Distinct from [appLockArmsOnBackground]: the scrim is a pure VISUAL
/// cover with no biometric timer, so it can safely include `hidden` (an earlier
/// background signal that lets the scrim paint BEFORE the OS captures its
/// snapshot). It deliberately EXCLUDES `inactive` — that fires on transient
/// interruptions (notification-shade / control-centre pulls) where the app is
/// still foreground, and flashing a scrim there would nag. Cleared on `resumed`.
bool appLockObscuresOnState(AppLifecycleState state) =>
    state == AppLifecycleState.paused ||
    state == AppLifecycleState.hidden ||
    state == AppLifecycleState.detached;

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
    // Always consume the timestamp FIRST (audit P2-1): if it is left set — e.g.
    // the app was backgrounded while already locked, so the guard below returns
    // early — a later benign resume (notification-shade peek) would compute a
    // huge away-time against the stale mark and spuriously re-lock. Clearing it
    // unconditionally keeps the fail-safe (a genuine long background still sets
    // a fresh mark via onBackground) without the phantom re-lock.
    final since = _backgroundedAt;
    _backgroundedAt = null;
    if (!state.enabled || state.locked) return;
    if (since != null) {
      final away = now.difference(since);
      // Fail-safe (audit F4): a NEGATIVE away-time means the wall clock moved
      // backwards while backgrounded (device clock change) — treat it as a long
      // background and LOCK, rather than letting a clock rollback dodge the lock.
      if (away.isNegative || away >= graceWindow) {
        state = state.copyWith(locked: true);
      }
    }
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
