// Living Dashboard — how fresh is what you are looking at?
//
// Owner rule (2026-07-30): "The dashboard should never imply 'live' unless it
// can prove it. Never present cached data as live."
//
// Before this, the only freshness signal in the product was
// `AksharaFreshnessChip`, which reported DEVICE CONNECTIVITY and nothing else.
// That is not the same question. A device can be online while the screen shows a
// payload fetched twenty minutes ago, and — worse — the offline read-cache
// replays bodies up to 24h old with an `X-NIKSHA-Offline-Cache` header that
// nothing in lib/ has ever read. So a 23-hour-old fee balance rendered under a
// green "Live" chip.
//
// This file is PURE: classification is a function of (what the network layer
// observed, how old it is, is the device online, when did we last try). No
// widgets, no clock — `now` is injected, as everywhere else in this lane.

import 'package:flutter/foundation.dart';

/// What the network layer observed for a surface's most recent read.
enum DataOrigin {
  /// A real 2xx from the server.
  network,

  /// The offline read-cache replayed a stored body (connectivity failure).
  cache,

  /// The read failed and nothing could be served.
  failure,
}

/// What the user is told. Ordered from most to least trustworthy.
enum DataFreshness {
  /// Fetched from the server just now.
  live,

  /// Fetched from the server, but a while ago — true, just not this second.
  recentlyRefreshed,

  /// Served from the offline cache. Real data, genuinely stale, and NEVER
  /// allowed to render as "live".
  cached,

  /// The device has no connection, so nothing can be refreshed.
  offline,

  /// We tried and could not get data. Distinct from `offline`: the connection
  /// is up, so this is the server or the request failing, and the user may be
  /// looking at nothing rather than at something old.
  refreshFailed,
}

/// The freshness of one surface's data, plus the age that justifies it.
@immutable
class DataFreshnessState {
  const DataFreshnessState({
    required this.freshness,
    this.age,
    this.observedAt,
  });

  const DataFreshnessState.unknown()
      : freshness = DataFreshness.live,
        age = null,
        observedAt = null;

  final DataFreshness freshness;

  /// How old the underlying payload is. Null when not meaningful (offline with
  /// nothing loaded, or a failure).
  final Duration? age;

  /// When the payload was produced (server fetch time, or the cache entry's
  /// stored timestamp).
  final DateTime? observedAt;

  /// True for anything the user must not read as current.
  bool get isStale =>
      freshness == DataFreshness.cached ||
      freshness == DataFreshness.offline ||
      freshness == DataFreshness.refreshFailed;

  @override
  bool operator ==(Object other) =>
      other is DataFreshnessState &&
      other.freshness == freshness &&
      other.age == age &&
      other.observedAt == observedAt;

  @override
  int get hashCode => Object.hash(freshness, age, observedAt);
}

/// How recent a network fetch has to be to still count as "live" rather than
/// "recently refreshed". Matched to the Phase 3 foreground poll (90s) so a
/// polling dashboard reads "Live" continuously instead of flickering between
/// the two labels every cycle.
const Duration kLiveWindow = Duration(minutes: 2);

/// Classify one surface's freshness. Pure; `now` is injected.
///
/// Precedence is deliberate and is the whole point of the function:
///
///  1. A cache replay is ALWAYS `cached`, even while the device is online and
///     even if it happened one second ago. The body is old; where it came from
///     is what matters, not when it was handed to us.
///  2. A failure with the device online is `refreshFailed` — the user should
///     know the server is not answering, not be told they are offline.
///  3. Offline outranks a stale network read: there is no point implying the
///     numbers might update when nothing can be fetched.
DataFreshnessState classifyFreshness({
  required DataOrigin? origin,
  required DateTime? observedAt,
  required bool isOnline,
  required DateTime now,
}) {
  final age = observedAt == null ? null : _nonNegative(now.difference(observedAt));

  // 1. Cache replay — never "live", whatever the connectivity says.
  if (origin == DataOrigin.cache) {
    return DataFreshnessState(
      freshness: DataFreshness.cached,
      age: age,
      observedAt: observedAt,
    );
  }

  // 2. A failure while connected is the server's fault, not the network's.
  if (origin == DataOrigin.failure) {
    return DataFreshnessState(
      freshness: isOnline ? DataFreshness.refreshFailed : DataFreshness.offline,
      age: age,
      observedAt: observedAt,
    );
  }

  // 3. Offline: nothing can refresh, so say so rather than implying currency.
  if (!isOnline) {
    return DataFreshnessState(
      freshness: DataFreshness.offline,
      age: age,
      observedAt: observedAt,
    );
  }

  // 4. A real network read. Live only inside the window it can justify.
  if (origin == DataOrigin.network && age != null) {
    return DataFreshnessState(
      freshness:
          age <= kLiveWindow ? DataFreshness.live : DataFreshness.recentlyRefreshed,
      age: age,
      observedAt: observedAt,
    );
  }

  // Nothing observed yet — the first paint, before any read has resolved.
  return const DataFreshnessState.unknown();
}

Duration _nonNegative(Duration d) => d.isNegative ? Duration.zero : d;

/// The age in words a person would use. Null when it is not worth saying.
String? formatFreshnessAge(Duration? age) {
  if (age == null || age < const Duration(minutes: 1)) return null;
  if (age < const Duration(hours: 1)) return '${age.inMinutes}m ago';
  if (age < const Duration(days: 1)) return '${age.inHours}h ago';
  return '${age.inDays}d ago';
}
