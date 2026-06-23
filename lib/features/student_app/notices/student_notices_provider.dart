import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/repository_future.dart';
import '../../../core/repositories/repository_providers.dart';
import '../../../core/tenant/tenant_provider.dart';
import 'notices_models.dart';

final studentNoticeScopeProvider = StateProvider<StudentNoticeScope>(
  (ref) => StudentNoticeScope.all,
);

final studentNoticesLoadingProvider = StateProvider<bool>((ref) => false);
final studentNoticesErrorProvider = StateProvider<bool>((ref) => false);
final studentNoticesEmptyProvider = StateProvider<bool>((ref) => false);

final studentNoticesFutureProvider = FutureProvider<List<StudentNotice>>((ref) async {
  return ref.read(studentRepositoryProvider).getNotices(query: ref.watch(repositoryQueryProvider));
});

final _studentNoticesBaseProvider = Provider<List<StudentNotice>>((ref) {
  final items = watchRepositoryFuture(
    ref,
    ref.watch(studentNoticesFutureProvider),
    manualLoading: ref.watch(studentNoticesLoadingProvider),
    manualError: ref.watch(studentNoticesErrorProvider),
    manualEmpty: ref.watch(studentNoticesEmptyProvider),
  );
  return items ?? ref.watch(studentNoticesFutureProvider).value ?? const [];
});

final studentNoticesItemsProvider = Provider<List<StudentNotice>>((ref) {
  if (ref.watch(studentNoticesEmptyProvider)) return const [];

  final scope = ref.watch(studentNoticeScopeProvider);
  final items = ref.watch(_studentNoticesBaseProvider);

  return switch (scope) {
    StudentNoticeScope.all => items,
    StudentNoticeScope.school => items
        .where((n) => n.scope == StudentNoticeScope.school)
        .toList(growable: false),
    StudentNoticeScope.classNotice => items
        .where((n) => n.scope == StudentNoticeScope.classNotice)
        .toList(growable: false),
  };
});

final studentNoticesProvider = Provider<StudentNoticesData>((ref) {
  return StudentNoticesData(
    studentName: 'Ravi Kumar',
    classLabel: '8-A',
    unreadNotifications: 2,
    notices: ref.watch(studentNoticesItemsProvider),
  );
});
