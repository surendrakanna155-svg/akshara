import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/repository_future.dart';
import '../../../core/repositories/repository_providers.dart';
import '../../../core/tenant/tenant_provider.dart';
import 'events_models.dart';

/// Active events section tab.
final parentEventSectionProvider = StateProvider<EventSection>(
  (ref) => EventSection.upcoming,
);

final parentEventsLoadingProvider = StateProvider<bool>((ref) => false);
final parentEventsErrorProvider = StateProvider<bool>((ref) => false);
final parentEventsEmptyProvider = StateProvider<bool>((ref) => false);

final parentEventsFutureProvider = FutureProvider<ParentEventsData>((ref) async {
  return ref.read(parentRepositoryProvider).getEvents(query: ref.watch(repositoryQueryProvider));
});

final parentEventsProvider = Provider<ParentEventsData>((ref) {
  final data = watchRepositoryFuture(
    ref,
    ref.watch(parentEventsFutureProvider),
    manualLoading: ref.watch(parentEventsLoadingProvider),
    manualError: ref.watch(parentEventsErrorProvider),
    manualEmpty: ref.watch(parentEventsEmptyProvider),
  );
  final resolved = data ??
      ref.watch(parentEventsFutureProvider).value ??
      const ParentEventsData(
        childName: 'Ravi Kumar',
        childClass: '8-A',
        unreadNotifications: 2,
        upcomingEvents: [],
        pastEvents: [],
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
