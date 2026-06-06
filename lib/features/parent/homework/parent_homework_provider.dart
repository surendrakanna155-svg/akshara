import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'homework_models.dart';

/// Active homework filter selected in PA-05.
final homeworkFilterProvider = StateProvider<HomeworkFilter>(
  (ref) => HomeworkFilter.all,
);

/// Reserved for API loading state.
final parentHomeworkLoadingProvider = StateProvider<bool>((ref) => false);

/// Reserved for API error state.
final parentHomeworkErrorProvider = StateProvider<bool>((ref) => false);

/// Toggle used to emulate empty payload state.
final parentHomeworkEmptyProvider = StateProvider<bool>((ref) => false);

/// Base homework payload.
final _parentHomeworkBaseDataProvider = Provider<ParentHomeworkData>(
  (ref) => ParentHomeworkData.mock(),
);

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
        .where((item) => item.status == ParentHomeworkStatus.pending)
        .toList(growable: false),
    HomeworkFilter.submitted => baseItems
        .where((item) => item.status == ParentHomeworkStatus.submitted)
        .toList(growable: false),
    HomeworkFilter.overdue => baseItems
        .where((item) => item.status == ParentHomeworkStatus.overdue)
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
