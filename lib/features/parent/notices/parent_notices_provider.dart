import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/repository_future.dart';
import '../../../core/repositories/repository_providers.dart';
import '../../../core/tenant/tenant_provider.dart';
import 'notices_models.dart';

/// Active notice category filter.
final parentNoticeCategoryProvider = StateProvider<NoticeCategory>(
  (ref) => NoticeCategory.all,
);

final parentNoticesLoadingProvider = StateProvider<bool>((ref) => false);
final parentNoticesErrorProvider = StateProvider<bool>((ref) => false);
final parentNoticesEmptyProvider = StateProvider<bool>((ref) => false);

final parentNoticesFutureProvider = FutureProvider<List<ParentNotice>>((ref) async {
  return ref.read(parentRepositoryProvider).getNotices(query: ref.watch(repositoryQueryProvider));
});

final _parentNoticesBaseProvider = Provider<List<ParentNotice>>((ref) {
  final items = watchRepositoryFuture(
    ref,
    ref.watch(parentNoticesFutureProvider),
    manualLoading: ref.watch(parentNoticesLoadingProvider),
    manualError: ref.watch(parentNoticesErrorProvider),
    manualEmpty: ref.watch(parentNoticesEmptyProvider),
  );
  return items ?? ref.watch(parentNoticesFutureProvider).value ?? const [];
});

/// Filtered notices list for PA-07.
final parentNoticesItemsProvider = Provider<List<ParentNotice>>((ref) {
  if (ref.watch(parentNoticesEmptyProvider)) {
    return const [];
  }

  final filter = ref.watch(parentNoticeCategoryProvider);
  final items = ref.watch(_parentNoticesBaseProvider);

  return switch (filter) {
    NoticeCategory.all => items,
    NoticeCategory.urgent =>
      items.where((item) => item.isUrgent).toList(growable: false),
    NoticeCategory.general => items
        .where((item) => item.category == NoticeCategory.general)
        .toList(growable: false),
    NoticeCategory.academic => items
        .where((item) => item.category == NoticeCategory.academic)
        .toList(growable: false),
    NoticeCategory.transport => items
        .where((item) => item.category == NoticeCategory.transport)
        .toList(growable: false),
  };
});

/// Screen payload with filtered notices.
final parentNoticesProvider = Provider<ParentNoticesData>((ref) {
  final items = ref.watch(parentNoticesItemsProvider);

  return ParentNoticesData(
    childName: 'Ravi Kumar',
    childClass: '8-A',
    unreadNotifications: 2,
    notices: items,
  );
});
