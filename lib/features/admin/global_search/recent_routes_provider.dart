import 'package:flutter_riverpod/flutter_riverpod.dart';

/// In-memory recent route paths for global search shortcuts.
final recentRoutesProvider =
    NotifierProvider<RecentRoutesNotifier, List<String>>(RecentRoutesNotifier.new);

class RecentRoutesNotifier extends Notifier<List<String>> {
  static const maxEntries = 8;

  @override
  List<String> build() => const [];

  void record(String route) {
    if (route.isEmpty) return;
    final next = [route, ...state.where((r) => r != route)].take(maxEntries).toList();
    state = next;
  }
}

void recordRecentRoute(WidgetRef ref, String route) {
  ref.read(recentRoutesProvider.notifier).record(route);
}
