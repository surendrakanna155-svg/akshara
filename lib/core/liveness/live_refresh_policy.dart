// Living Dashboard — when a dashboard may refresh itself.
//
// Design: docs/design/living-dashboard/LIVING_DASHBOARD_ARCHITECTURE.md §3.5.
// Owner decision D1 (2026-07-30): resume-refresh + foreground poll. Not FCM
// (iOS has no GoogleService-Info.plist and FCM_STUB_MODE defaults true), and not
// Realtime (there is no Supabase client in this app at all).
//
// This file is PURE so the interesting part — when we deliberately DON'T
// refresh — is provable without a clock, a network, or a widget tree. The
// mechanism that calls it lives in live_refresh_scope.dart.
//
// The restraint matters as much as the refreshing. A dashboard that polls while
// backgrounded, or while offline, or twice in the same second because the user
// flicked between apps, burns battery and data on a school-issued phone and
// makes the product feel worse, not more alive.

import 'package:flutter/foundation.dart';

@immutable
class LiveRefreshPolicy {
  const LiveRefreshPolicy({
    this.interval = const Duration(seconds: 90),
    this.resumeThreshold = const Duration(seconds: 20),
    this.minGap = const Duration(seconds: 5),
  });

  /// How often a visible, foreground dashboard re-reads its data.
  ///
  /// 90s is chosen against what this data actually is: attendance, fees and
  /// approvals move on minutes-to-hours timescales, so a tighter loop would cost
  /// battery and mobile data without ever showing the user something new.
  final Duration interval;

  /// A resume only refetches if the app was away at least this long. Flicking to
  /// the notification shade and back is not a reason to re-hit the API.
  final Duration resumeThreshold;

  /// Hard debounce across every trigger — no two refreshes closer than this,
  /// whatever asked for them.
  final Duration minGap;

  /// The periodic-tick decision.
  bool shouldRefreshOnTick({
    required DateTime? lastRefreshAt,
    required DateTime now,
    required bool isOnline,
    required bool isForeground,
  }) {
    if (!_canRefresh(isOnline: isOnline, isForeground: isForeground)) return false;
    if (lastRefreshAt == null) return true;
    return !now.isBefore(lastRefreshAt.add(interval));
  }

  /// The app-resume decision. Deliberately separate from the tick: coming back
  /// to a dashboard is a stronger signal than time passing, so it uses a much
  /// shorter threshold — but still not zero.
  bool shouldRefreshOnResume({
    required DateTime? lastRefreshAt,
    required DateTime now,
    required bool isOnline,
    Duration? awayFor,
  }) {
    // A resume IS the foreground transition, so `isForeground` is implied.
    if (!_canRefresh(isOnline: isOnline, isForeground: true)) return false;
    if (lastRefreshAt == null) return true;
    if (now.isBefore(lastRefreshAt.add(minGap))) return false;
    if (awayFor != null && awayFor < resumeThreshold) return false;
    return !now.isBefore(lastRefreshAt.add(resumeThreshold));
  }

  bool _canRefresh({required bool isOnline, required bool isForeground}) {
    // Offline: the request would fail and, worse, the offline read-cache would
    // replay a stale payload as though it were fresh. Staying put and letting
    // the freshness chip say "Offline · saved data" is the honest behaviour.
    if (!isOnline) return false;
    // Backgrounded: nobody is looking, and a school phone's battery is not ours
    // to spend.
    if (!isForeground) return false;
    return true;
  }
}
