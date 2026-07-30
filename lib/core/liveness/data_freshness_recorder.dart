// Living Dashboard — the sink that makes freshness knowable.
//
// The network layer is the only place that knows whether a body came off the
// wire or out of the offline read-cache. That knowledge previously died there:
// `OfflineReadCacheInterceptor` sets `X-NIKSHA-Offline-Cache` on every replayed
// response and nothing in lib/ ever read it, so cached data reached the screen
// indistinguishable from live data.
//
// This recorder is the one-way channel out. The interceptor reports what it
// observed, per request path; surfaces read it back and classify with the pure
// `classifyFreshness`. Deliberately dumb — it stores observations and notifies;
// every judgement lives in data_freshness.dart.

import 'package:flutter/foundation.dart';

import 'data_freshness.dart';

@immutable
class FreshnessObservation {
  const FreshnessObservation({required this.origin, required this.observedAt});

  final DataOrigin origin;

  /// For a network read, when we fetched it. For a cache replay, the timestamp
  /// the CACHE ENTRY carries — not when it was replayed. That distinction is
  /// what stops a 23-hour-old body reading as seconds old.
  final DateTime observedAt;
}

class DataFreshnessRecorder extends ChangeNotifier {
  final Map<String, FreshnessObservation> _byPath = <String, FreshnessObservation>{};

  /// Report what the network layer observed for [path].
  ///
  /// Called from an interceptor, so it must never throw and never block: a
  /// freshness bookkeeping failure must not break a real read.
  void record(String path, DataOrigin origin, DateTime observedAt) {
    _byPath[_normalize(path)] =
        FreshnessObservation(origin: origin, observedAt: observedAt);
    notifyListeners();
  }

  /// The observation for a surface's endpoint.
  ///
  /// Exact match first; otherwise the longest recorded path that this surface's
  /// prefix covers, so `/management/dashboard` still resolves when the request
  /// carried a query string or a sub-path.
  FreshnessObservation? observationFor(String path) {
    final key = _normalize(path);
    final exact = _byPath[key];
    if (exact != null) return exact;

    FreshnessObservation? best;
    var bestLen = -1;
    for (final entry in _byPath.entries) {
      if (entry.key.startsWith(key) && entry.key.length > bestLen) {
        best = entry.value;
        bestLen = entry.key.length;
      }
    }
    return best;
  }

  @visibleForTesting
  void clear() {
    _byPath.clear();
    notifyListeners();
  }

  static String _normalize(String path) {
    final withoutQuery = path.split('?').first;
    if (withoutQuery.length > 1 && withoutQuery.endsWith('/')) {
      return withoutQuery.substring(0, withoutQuery.length - 1);
    }
    return withoutQuery;
  }
}
