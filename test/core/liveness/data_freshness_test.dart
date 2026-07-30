// Living Dashboard — freshness classification.
//
// The rule these exist to enforce, in the owner's words: "Never present cached
// data as live." The precedence tests below are the ones that would catch a
// regression of that rule.

import 'package:flutter_test/flutter_test.dart';
import 'package:akshara_erp/core/liveness/data_freshness.dart';

void main() {
  final now = DateTime.utc(2026, 7, 30, 12, 0);

  DataFreshnessState classify({
    DataOrigin? origin,
    Duration? age,
    bool isOnline = true,
  }) {
    return classifyFreshness(
      origin: origin,
      observedAt: age == null ? null : now.subtract(age),
      isOnline: isOnline,
      now: now,
    );
  }

  group('the rule: cached is never live', () {
    test('a cache replay is cached even while ONLINE', () {
      final s = classify(origin: DataOrigin.cache, age: const Duration(seconds: 5));
      expect(s.freshness, DataFreshness.cached);
      expect(s.isStale, isTrue);
    });

    test('a cache replay is cached even when it happened one second ago', () {
      // Recency must never launder provenance: the BODY is old, whatever time
      // the cache handed it to us.
      final s = classify(origin: DataOrigin.cache, age: const Duration(seconds: 1));
      expect(s.freshness, DataFreshness.cached);
    });

    test('a 23h cache replay reports its real age', () {
      final s = classify(origin: DataOrigin.cache, age: const Duration(hours: 23));
      expect(s.freshness, DataFreshness.cached);
      expect(formatFreshnessAge(s.age), '23h ago');
    });
  });

  group('network reads', () {
    test('a fresh fetch is live', () {
      expect(
        classify(origin: DataOrigin.network, age: const Duration(seconds: 10)).freshness,
        DataFreshness.live,
      );
    });

    test('live survives a full poll cycle so the label does not flicker', () {
      expect(
        classify(origin: DataOrigin.network, age: const Duration(seconds: 95)).freshness,
        DataFreshness.live,
        reason: 'the Phase 3 foreground poll is 90s; live must outlast it',
      );
    });

    test('an older fetch degrades to recentlyRefreshed, not live', () {
      final s = classify(origin: DataOrigin.network, age: const Duration(minutes: 20));
      expect(s.freshness, DataFreshness.recentlyRefreshed);
      expect(s.isStale, isFalse, reason: 'it is real server data, just not this second');
    });

    test('a network read while offline reports offline, not live', () {
      // Connectivity dropped after the fetch: nothing can refresh, so implying
      // currency would be dishonest.
      expect(
        classify(
          origin: DataOrigin.network,
          age: const Duration(seconds: 5),
          isOnline: false,
        ).freshness,
        DataFreshness.offline,
      );
    });
  });

  group('failures', () {
    test('a failure while ONLINE is refreshFailed, not offline', () {
      expect(
        classify(origin: DataOrigin.failure, age: const Duration(minutes: 2)).freshness,
        DataFreshness.refreshFailed,
        reason: 'blaming the network when the server is down misleads the user',
      );
    });

    test('a failure while OFFLINE is offline', () {
      expect(
        classify(
          origin: DataOrigin.failure,
          age: const Duration(minutes: 2),
          isOnline: false,
        ).freshness,
        DataFreshness.offline,
      );
    });

    test('both failure states count as stale', () {
      expect(classify(origin: DataOrigin.failure).isStale, isTrue);
      expect(classify(origin: DataOrigin.failure, isOnline: false).isStale, isTrue);
    });
  });

  group('edges', () {
    test('nothing observed yet does not claim staleness on first paint', () {
      final s = classify(origin: null);
      expect(s.isStale, isFalse);
      expect(s.age, isNull);
    });

    test('a clock skew into the future clamps to zero, never negative', () {
      final s = classifyFreshness(
        origin: DataOrigin.network,
        observedAt: now.add(const Duration(minutes: 10)),
        isOnline: true,
        now: now,
      );
      expect(s.age, Duration.zero);
      expect(s.freshness, DataFreshness.live);
    });

    test('formatFreshnessAge stays quiet under a minute and scales above it', () {
      expect(formatFreshnessAge(null), isNull);
      expect(formatFreshnessAge(const Duration(seconds: 30)), isNull);
      expect(formatFreshnessAge(const Duration(minutes: 5)), '5m ago');
      expect(formatFreshnessAge(const Duration(hours: 3)), '3h ago');
      expect(formatFreshnessAge(const Duration(days: 2)), '2d ago');
    });
  });
}
