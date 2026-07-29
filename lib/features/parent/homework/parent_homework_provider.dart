import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/repositories/repository_providers.dart';
import '../../../shared/async/erp_async_state.dart';
import '../parent_active_child_provider.dart';
import 'homework_models.dart';

/// Active homework filter selected in PA-05.
final homeworkFilterProvider = StateProvider<HomeworkFilter>(
  (ref) => HomeworkFilter.all,
);

final parentHomeworkLoadingProvider = StateProvider<bool>((ref) => false);
final parentHomeworkErrorProvider = StateProvider<bool>((ref) => false);
final parentHomeworkEmptyProvider = StateProvider<bool>((ref) => false);

final parentHomeworkFutureProvider = FutureProvider<ParentHomeworkData>((ref) async {
  return ref.read(parentRepositoryProvider).getHomework(query: ref.watch(parentRepositoryQueryProvider));
});

/// CERT-002 — honest-async contract for `/parent/homework`.
final parentHomeworkViewStateProvider =
    Provider<ErpViewState<ParentHomeworkData>>((ref) {
  return resolveErpAsync<ParentHomeworkData>(
    ref.watch(parentHomeworkFutureProvider),
    forceLoading: ref.watch(parentHomeworkLoadingProvider),
    forceError: ref.watch(parentHomeworkErrorProvider),
    forceEmpty: ref.watch(parentHomeworkEmptyProvider),
    errorMessage: 'Unable to load homework right now.',
  );
});

final _parentHomeworkBaseDataProvider = Provider<ParentHomeworkData>((ref) {
  return honestPayload(
    ref.watch(parentHomeworkViewStateProvider),
    ParentHomeworkData.empty,
  );
});

/// Filtered homework rows based on [homeworkFilterProvider].
final parentHomeworkItemsProvider = Provider<List<ParentHomeworkItem>>((ref) {
  final baseItems = ref.watch(_parentHomeworkBaseDataProvider).items;
  final forceEmpty = ref.watch(parentHomeworkEmptyProvider);
  if (forceEmpty) {
    return const <ParentHomeworkItem>[];
  }

  final filter = ref.watch(homeworkFilterProvider);
  return switch (filter) {
    HomeworkFilter.all => baseItems,
    HomeworkFilter.pending => baseItems
        .where((item) => item.effectiveStatus == ParentHomeworkStatus.pending)
        .toList(growable: false),
    HomeworkFilter.submitted => baseItems
        .where((item) => item.effectiveStatus.isSubmitted)
        .toList(growable: false),
    HomeworkFilter.overdue => baseItems
        .where((item) => item.effectiveStatus == ParentHomeworkStatus.overdue)
        .toList(growable: false),
  };
});

/// Final payload consumed by the screen with filtered items.
final parentHomeworkDataProvider = Provider<ParentHomeworkData>((ref) {
  final base = ref.watch(_parentHomeworkBaseDataProvider);
  final items = ref.watch(parentHomeworkItemsProvider);

  return ParentHomeworkData(
    childName: base.childName,
    childClass: base.childClass,
    unreadNotifications: base.unreadNotifications,
    insightMessage: base.insightMessage,
    insightActionLabel: base.insightActionLabel,
    items: items,
  );
});
