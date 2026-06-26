import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/repository_future.dart';
import '../../../core/repositories/repository_providers.dart';
import '../parent_active_child_provider.dart';
import 'events_models.dart';

/// Active events section tab.
final parentEventSectionProvider = StateProvider<EventSection>(
  (ref) => EventSection.upcoming,
);

final parentEventsLoadingProvider = StateProvider<bool>((ref) => false);
final parentEventsErrorProvider = StateProvider<bool>((ref) => false);
final parentEventsEmptyProvider = StateProvider<bool>((ref) => false);

final parentEventsFutureProvider = FutureProvider<ParentEventsData>((ref) async {
  return ref.read(parentRepositoryProvider).getEvents(query: ref.watch(parentRepositoryQueryProvider));
});

final parentEventsProvider = Provider<ParentEventsData>((ref) {
  final data = watchRepositoryFuture(
    ref,
    ref.watch(parentEventsFutureProvider),
    manualLoading: ref.watch(parentEventsLoadingProvider),
    manualError: ref.watch(parentEventsErrorProvider),
    manualEmpty: ref.watch(parentEventsEmptyProvider),
  );
  // PAR-9: fall back to the real active child, not a hardcoded demo student.
  final child = ref.watch(parentActiveChildProvider);
  final resolved = data ??
      ref.watch(parentEventsFutureProvider).value ??
      ParentEventsData(
        childName: child?.name ?? '',
        childClass: child?.classLabel ?? '',
        unreadNotifications: 0,
        upcomingEvents: const [],
        pastEvents: const [],
      );

  if (ref.watch(parentEventsEmptyProvider)) {
    return ParentEventsData(
      childName: resolved.childName,
      childClass: resolved.childClass,
      unreadNotifications: resolved.unreadNotifications,
      upcomingEvents: const [],
      pastEvents: const [],
    );
  }

  return resolved;
});
