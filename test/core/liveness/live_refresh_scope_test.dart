// Living Dashboard — the refresh MECHANISM (the policy is tested separately).
//
// These prove the wiring actually fires: a resume after a real absence refetches,
// a quick flick away does not, and a disposed scope stops ticking. The last one
// matters because a leaked periodic timer would keep hitting the API from a
// screen the user has already left.

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:akshara_erp/core/liveness/live_refresh_policy.dart';
import 'package:akshara_erp/core/liveness/live_refresh_scope.dart';
import 'package:akshara_erp/shared/widgets/akshara_freshness_chip.dart';

/// A clock the test drives in lockstep with `tester.pump`, so elapsed widget
/// time and elapsed policy time agree. Without this the scope would read the
/// real wall clock, which barely moves during a test.
class _FakeClock {
  DateTime value = DateTime.utc(2026, 7, 30, 12, 0);
  DateTime call() => value;
}

Future<void> _pump(
  WidgetTester tester, {
  required VoidCallback onRefresh,
  required _FakeClock clock,
  bool online = true,
  LiveRefreshPolicy policy = const LiveRefreshPolicy(),
}) {
  return tester.pumpWidget(
    ProviderScope(
      overrides: [aksharaFreshnessOnlineProvider.overrideWithValue(online)],
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: LiveRefreshScope(
          surfaceKey: 'test-surface',
          policy: policy,
          now: clock.call,
          onRefresh: onRefresh,
          child: const SizedBox.shrink(),
        ),
      ),
    ),
  );
}

/// Advance both the widget clock and the policy clock together.
Future<void> _advance(WidgetTester tester, _FakeClock clock, Duration d) async {
  clock.value = clock.value.add(d);
  await tester.pump(d);
}

void main() {
  testWidgets('a resume after a real absence refetches', (tester) async {
    var refreshes = 0;
    final clock = _FakeClock();
    await _pump(tester, onRefresh: () => refreshes++, clock: clock);

    // Background, wait past the resume threshold, come back.
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await _advance(tester, clock, const Duration(seconds: 30));
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();

    expect(refreshes, 1);
  });

  testWidgets('a quick flick away and back does NOT refetch', (tester) async {
    var refreshes = 0;
    final clock = _FakeClock();
    await _pump(tester, onRefresh: () => refreshes++, clock: clock);

    // Prime a recent refresh, then leave for barely any time.
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await _advance(tester, clock, const Duration(seconds: 30));
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(refreshes, 1, reason: 'first real resume');

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await _advance(tester, clock, const Duration(seconds: 2));
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();

    expect(refreshes, 1, reason: 'a glance at the shade is not a refresh reason');
  });

  testWidgets('offline resume does not refetch', (tester) async {
    var refreshes = 0;
    final clock = _FakeClock();
    await _pump(tester, onRefresh: () => refreshes++, online: false, clock: clock);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await _advance(tester, clock, const Duration(minutes: 5));
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();

    expect(refreshes, 0);
  });

  testWidgets('the foreground tick refreshes once the interval elapses', (tester) async {
    var refreshes = 0;
    final clock = _FakeClock();
    await _pump(
      tester,
      onRefresh: () => refreshes++,
      clock: clock,
      policy: const LiveRefreshPolicy(interval: Duration(seconds: 30)),
    );

    await _advance(tester, clock, const Duration(seconds: 16));
    expect(refreshes, 1, reason: 'first tick: never refreshed yet');

    await _advance(tester, clock, const Duration(seconds: 16));
    expect(refreshes, 1, reason: 'inside the interval — stay put');

    await _advance(tester, clock, const Duration(seconds: 20));
    expect(refreshes, 2, reason: 'interval elapsed');

    // Leave the tree so the periodic timer is cancelled before the test ends.
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('disposing the scope stops the ticker', (tester) async {
    var refreshes = 0;
    final clock = _FakeClock();
    await _pump(
      tester,
      onRefresh: () => refreshes++,
      clock: clock,
      policy: const LiveRefreshPolicy(interval: Duration(seconds: 30)),
    );
    await _advance(tester, clock, const Duration(seconds: 16));
    expect(refreshes, 1);

    await tester.pumpWidget(const SizedBox.shrink());
    await _advance(tester, clock, const Duration(minutes: 5));

    expect(
      refreshes,
      1,
      reason: 'a leaked timer would keep hitting the API from a dead screen',
    );
  });
}
