// Living Dashboard — reading freshness back out on the UI side.

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/widgets/akshara_freshness_chip.dart';
import 'data_freshness.dart';
import 'data_freshness_recorder.dart';

/// The app-wide recorder. Constructed here and handed to the offline read-cache
/// interceptor at Dio setup, so there is exactly one sink.
final dataFreshnessRecorderProvider = Provider<DataFreshnessRecorder>((ref) {
  final recorder = DataFreshnessRecorder();
  ref.onDispose(recorder.dispose);
  return recorder;
});

/// Freshness for one surface, keyed by the API path it reads
/// (e.g. `/management/dashboard`).
///
/// Recomputed whenever the recorder reports a new observation OR connectivity
/// flips, because both change the answer: going offline turns a perfectly good
/// network read into "offline", since nothing can refresh it any more.
final dataFreshnessProvider =
    Provider.family<DataFreshnessState, String>((ref, path) {
  final recorder = ref.watch(dataFreshnessRecorderProvider);
  final online = ref.watch(aksharaFreshnessOnlineProvider);

  void onChange() => ref.invalidateSelf();
  recorder.addListener(onChange);
  ref.onDispose(() => recorder.removeListener(onChange));

  final observation = recorder.observationFor(path);
  return classifyFreshness(
    origin: observation?.origin,
    observedAt: observation?.observedAt,
    isOnline: online,
    now: DateTime.now(),
  );
});

/// Presentation for one freshness state: what to say, and whether it is a
/// reassurance or a warning.
@immutable
class FreshnessPresentation {
  const FreshnessPresentation({
    required this.label,
    required this.semanticLabel,
    required this.tone,
  });

  final String label;
  final String semanticLabel;
  final FreshnessTone tone;
}

enum FreshnessTone { good, neutral, warning }

/// Turn a state into words. Pure so the copy is testable — and the copy is the
/// product here: the whole point is that a user can tell at a glance whether
/// they are looking at fresh or cached data.
FreshnessPresentation presentFreshness(DataFreshnessState state) {
  final age = formatFreshnessAge(state.age);
  switch (state.freshness) {
    case DataFreshness.live:
      return const FreshnessPresentation(
        label: 'Live',
        semanticLabel: 'Data is live',
        tone: FreshnessTone.good,
      );
    case DataFreshness.recentlyRefreshed:
      return FreshnessPresentation(
        label: age == null ? 'Updated' : 'Updated $age',
        semanticLabel: 'Data was last updated ${age ?? 'recently'}',
        tone: FreshnessTone.neutral,
      );
    case DataFreshness.cached:
      // Never the word "live", and always the age — a saved copy that does not
      // say how old it is invites the user to assume it is current.
      return FreshnessPresentation(
        label: age == null ? 'Saved copy' : 'Saved copy · $age',
        semanticLabel: 'Showing a saved copy from ${age ?? 'earlier'}',
        tone: FreshnessTone.warning,
      );
    case DataFreshness.offline:
      return const FreshnessPresentation(
        label: 'Offline',
        semanticLabel: 'Offline — this cannot refresh',
        tone: FreshnessTone.warning,
      );
    case DataFreshness.refreshFailed:
      return const FreshnessPresentation(
        label: "Couldn't refresh",
        semanticLabel: 'The last refresh failed',
        tone: FreshnessTone.warning,
      );
  }
}
