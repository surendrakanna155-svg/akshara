// Living Dashboard — refresh policy. Pure and clock-injected.
//
// The valuable assertions here are the NEGATIVE ones: a dashboard that polls
// while backgrounded, while offline, or twice a second because the user flicked
// between apps costs battery and mobile data on a school-issued phone and makes
// the product feel worse, not more alive.

import 'package:flutter_test/flutter_test.dart';
import 'package:akshara_erp/core/liveness/live_refresh_policy.dart';

void main() {
  const policy = LiveRefreshPolicy();
  final now = DateTime.utc(2026, 7, 30, 12, 0);

  group('foreground tick', () {
    test('never refreshed yet → refresh', () {
      expect(
        policy.shouldRefreshOnTick(
          lastRefreshAt: null,
          now: now,
          isOnline: true,
          isForeground: true,
        ),
        isTrue,
      );
    });

    test('refreshes once the interval has elapsed', () {
      expect(
        policy.shouldRefreshOnTick(
          lastRefreshAt: now.subtract(const Duration(seconds: 91)),
          now: now,
          isOnline: true,
          isForeground: true,
        ),
        isTrue,
      );
    });

    test('stays put inside the interval', () {
      expect(
        policy.shouldRefreshOnTick(
          lastRefreshAt: now.subtract(const Duration(seconds: 30)),
          now: now,
          isOnline: true,
          isForeground: true,
        ),
        isFalse,
      );
    });

    test('never polls while backgrounded, however stale', () {
      expect(
        policy.shouldRefreshOnTick(
          lastRefreshAt: now.subtract(const Duration(hours: 6)),
          now: now,
          isOnline: true,
          isForeground: false,
        ),
        isFalse,
        reason: 'nobody is looking; a school phone battery is not ours to spend',
      );
    });

    test('never polls while offline, however stale', () {
      expect(
        policy.shouldRefreshOnTick(
          lastRefreshAt: now.subtract(const Duration(hours: 6)),
          now: now,
          isOnline: false,
          isForeground: true,
        ),
        isFalse,
        reason:
            'the request would fail and the offline cache would replay a stale '
            'payload as though it were fresh',
      );
    });
  });

  group('app resume', () {
    test('a long absence refreshes', () {
      expect(
        policy.shouldRefreshOnResume(
          lastRefreshAt: now.subtract(const Duration(minutes: 10)),
          now: now,
          isOnline: true,
          awayFor: const Duration(minutes: 10),
        ),
        isTrue,
      );
    });

    test('a glance at the notification shade does NOT refetch', () {
      expect(
        policy.shouldRefreshOnResume(
          lastRefreshAt: now.subtract(const Duration(minutes: 5)),
          now: now,
          isOnline: true,
          awayFor: const Duration(seconds: 3),
        ),
        isFalse,
        reason: 'flicking away and back is not a reason to re-hit the API',
      );
    });

    test('the hard debounce beats even a long absence', () {
      // Refreshed 1s ago (say, by the tick) then resumed after a long away —
      // still no second call.
      expect(
        policy.shouldRefreshOnResume(
          lastRefreshAt: now.subtract(const Duration(seconds: 1)),
          now: now,
          isOnline: true,
          awayFor: const Duration(hours: 2),
        ),
        isFalse,
      );
    });

    test('offline resume does not refresh', () {
      expect(
        policy.shouldRefreshOnResume(
          lastRefreshAt: now.subtract(const Duration(hours: 2)),
          now: now,
          isOnline: false,
          awayFor: const Duration(hours: 2),
        ),
        isFalse,
      );
    });

    test('resume is more eager than the tick for the same staleness', () {
      final lastRefresh = now.subtract(const Duration(seconds: 40));
      expect(
        policy.shouldRefreshOnTick(
          lastRefreshAt: lastRefresh,
          now: now,
          isOnline: true,
          isForeground: true,
        ),
        isFalse,
      );
      expect(
        policy.shouldRefreshOnResume(
          lastRefreshAt: lastRefresh,
          now: now,
          isOnline: true,
          awayFor: const Duration(minutes: 1),
        ),
        isTrue,
        reason: 'coming back to a screen is a stronger signal than time passing',
      );
    });
  });
}
