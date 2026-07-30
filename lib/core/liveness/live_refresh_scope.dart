// Living Dashboard — the mechanism that keeps a dashboard current.
//
// Wrap a dashboard body in this and it refreshes itself on app resume and on a
// slow foreground tick, instead of only when the user drags down. All of the
// "should we?" logic lives in the pure LiveRefreshPolicy next door; this widget
// only supplies the clock, the lifecycle events and the timer.
//
// Why this exists at all: before it, `app.dart`'s resume handler flushed the
// write outbox and re-armed App Lock but invalidated NO read provider, so a
// dashboard left open across a background/resume showed stale numbers
// indefinitely — silently, because the freshness chip only ever reported
// connectivity, never payload age.

import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/widgets/akshara_freshness_chip.dart';
import 'data_freshness_providers.dart';
import 'live_refresh_policy.dart';

/// The instant this surface last ATTEMPTED a refresh, keyed per surface.
///
/// Attempt, not arrival — it exists to rate-limit, and marking on attempt is the
/// safe direction (a hung request must not trigger an immediate retry).
///
/// Do NOT drive a "last updated" label from this: if the fetch failed, the
/// attempt time would claim a freshness the data does not have. Payload age has
/// its own honest source — `DataFreshnessRecorder`, fed by the read-cache
/// interceptor, which knows whether a body came off the wire or out of the
/// cache. Use `dataFreshnessProvider` for anything user-facing.
final lastRefreshAttemptProvider =
    StateProvider.family<DateTime?, String>((ref, surfaceKey) => null);

class LiveRefreshScope extends ConsumerStatefulWidget {
  const LiveRefreshScope({
    super.key,
    required this.surfaceKey,
    required this.onRefresh,
    required this.child,
    this.policy = const LiveRefreshPolicy(),
    this.enabled = true,
    this.now = DateTime.now,
    this.surfacePath,
  });

  /// The clock, injected for the same reason the backend resolver injects
  /// `nowIso`: the decisions here are time-based, and a widget that reads the
  /// wall clock directly cannot be tested — `tester.pump(Duration)` advances
  /// Flutter's timers but not `DateTime.now()`, so a fixed-clock scope would
  /// silently never re-refresh under test while looking correct.
  final DateTime Function() now;

  /// Identifies this surface's freshness entry, e.g. `management-dashboard`.
  final String surfaceKey;

  /// Re-read the data. Called only when the policy allows it; must be cheap to
  /// call repeatedly (a provider invalidation, not a rebuild of the world).
  final VoidCallback onRefresh;

  final Widget child;
  final LiveRefreshPolicy policy;

  /// Escape hatch for tests and for surfaces that must never self-refresh.
  final bool enabled;

  /// The API path this surface reads, e.g. `/management/dashboard`.
  ///
  /// When supplied, a freshness chip is shown above the child WHENEVER the data
  /// is stale — cached, offline, or a failed refresh — so the user is never left
  /// to assume a saved copy is current. Omit it to keep the scope purely a
  /// refresher with no visual footprint.
  final String? surfacePath;

  @override
  ConsumerState<LiveRefreshScope> createState() => _LiveRefreshScopeState();
}

class _LiveRefreshScopeState extends ConsumerState<LiveRefreshScope>
    with WidgetsBindingObserver {
  Timer? _ticker;
  DateTime? _backgroundedAt;
  bool _foreground = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (widget.enabled) _startTicker();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _startTicker() {
    _ticker?.cancel();
    // Tick faster than the refresh interval so the policy — not the timer —
    // decides. That keeps the cadence honest after a pause/resume, where a
    // timer aligned to the interval would drift.
    _ticker = Timer.periodic(const Duration(seconds: 15), (_) => _onTick());
  }

  bool get _isOnline => ref.read(aksharaFreshnessOnlineProvider);

  DateTime? get _lastRefresh =>
      ref.read(lastRefreshAttemptProvider(widget.surfaceKey));

  void _markRefreshed(DateTime at) {
    ref.read(lastRefreshAttemptProvider(widget.surfaceKey).notifier).state = at;
  }

  void _onTick() {
    if (!mounted || !widget.enabled) return;
    final now = widget.now();
    if (!widget.policy.shouldRefreshOnTick(
      lastRefreshAt: _lastRefresh,
      now: now,
      isOnline: _isOnline,
      isForeground: _foreground,
    )) {
      return;
    }
    _markRefreshed(now);
    widget.onRefresh();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (!mounted || !widget.enabled) return;

    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      _foreground = false;
      _backgroundedAt ??= widget.now();
      return;
    }

    if (state != AppLifecycleState.resumed) return;

    _foreground = true;
    final now = widget.now();
    final awayFor =
        _backgroundedAt == null ? null : now.difference(_backgroundedAt!);
    _backgroundedAt = null;

    if (widget.policy.shouldRefreshOnResume(
      lastRefreshAt: _lastRefresh,
      now: now,
      isOnline: _isOnline,
      awayFor: awayFor,
    )) {
      _markRefreshed(now);
      widget.onRefresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    final path = widget.surfacePath;
    if (path == null) return widget.child;

    final freshness = ref.watch(dataFreshnessProvider(path));
    // Only ever appears when the data is NOT current. Two reasons: a permanent
    // "Live" badge is noise the user learns to ignore (and would then miss the
    // one time it mattered), and rendering nothing in the healthy case means no
    // dashboard's layout — or golden — changes for fresh data.
    if (!freshness.isStale) return widget.child;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Align(
            alignment: AlignmentDirectional.centerStart,
            child: AksharaFreshnessChip(surfacePath: path),
          ),
        ),
        Expanded(child: widget.child),
      ],
    );
  }
}
