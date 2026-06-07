import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/repository_future.dart';
import '../../../core/repositories/paginated_result.dart';
import '../../../core/repositories/repository_query.dart';
import '../../../core/repositories/repository_providers.dart';
import '../../../core/tenant/tenant_provider.dart';
import '../sis_async_state.dart';
import '../sis_models.dart';

final sisRegistryLoadingProvider = StateProvider<bool>((ref) => false);
final sisRegistryErrorProvider = StateProvider<bool>((ref) => false);
final sisRegistryEmptyProvider = StateProvider<bool>((ref) => false);
final sisRegistrySearchProvider = StateProvider<String>((ref) => '');
final sisRegistryFilterProvider = StateProvider<int>((ref) => 0);
final sisRegistryPageProvider = StateProvider<int>((ref) => 1);

final sisStudentsQueryProvider = Provider<RepositoryQuery>((ref) {
  final baseQuery = ref.watch(repositoryQueryProvider);
  final page = ref.watch(sisRegistryPageProvider);
  return baseQuery.withPage(page);
});

final sisStudentsFutureProvider =
    FutureProvider<PaginatedResult<SisStudent>>((ref) async {
  return ref.read(sisRepositoryProvider).getStudents(
        query: ref.watch(sisStudentsQueryProvider),
      );
});

final sisStudentsPageResultProvider =
    Provider<PaginatedResult<SisStudent>?>((ref) {
  return watchRepositoryFuture(
        ref,
        ref.watch(sisStudentsFutureProvider),
        manualLoading: false,
        manualError: false,
        manualEmpty: false,
      );
});

final sisStudentsProvider = Provider<List<SisStudent>>((ref) {
  return ref.watch(sisStudentsPageResultProvider)?.items ?? const [];
});

final sisRegistryViewStateProvider =
    Provider<SisViewState<PaginatedResult<SisStudent>>>((ref) {
  return resolveSisAsync(
    ref.watch(sisStudentsFutureProvider),
    forceLoading: ref.watch(sisRegistryLoadingProvider),
    forceError: ref.watch(sisRegistryErrorProvider),
    forceEmpty: ref.watch(sisRegistryEmptyProvider),
    isDataEmpty: (result) => result.items.isEmpty,
  );
});

final sisFilteredStudentsProvider = Provider<List<SisStudent>>((ref) {
  final students = ref.watch(sisStudentsProvider);
  final query = ref.watch(sisRegistrySearchProvider).trim().toLowerCase();
  final filterIndex = ref.watch(sisRegistryFilterProvider);

  var filtered = students;
  filtered = switch (filterIndex) {
    1 => filtered
        .where((s) => s.status == SisStudentStatus.active)
        .toList(),
    2 => filtered
        .where((s) => s.status == SisStudentStatus.prospect)
        .toList(),
    3 => filtered.where((s) => s.classLabel == '10').toList(),
    _ => filtered,
  };

  if (query.isNotEmpty) {
    filtered = filtered
        .where(
          (s) =>
              s.studentName.toLowerCase().contains(query) ||
              s.admissionNumber.toLowerCase().contains(query),
        )
        .toList();
  }

  return filtered;
});
