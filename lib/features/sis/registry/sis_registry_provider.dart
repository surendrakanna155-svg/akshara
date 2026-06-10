import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/repository_future.dart';
import '../../../core/repositories/academic/academic_catalog_provider.dart';
import '../../../core/repositories/paginated_result.dart';
import '../../../core/repositories/repository_config.dart';
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

/// Base filters: All, Active, Prospect — class filters are appended dynamically.
const sisRegistryBaseFilterCount = 3;

final sisRegistryClassFilterOptionsProvider = classOptionsProvider;

final sisRegistryFilterLabelsProvider = Provider<List<String>>((ref) {
  final classes = ref.watch(sisRegistryClassFilterOptionsProvider);
  return [
    'All',
    'Active',
    'Prospect',
    for (final className in classes) 'Class $className',
  ];
});

/// Clamps stale chip indices when the catalog shrinks (e.g. zero classes).
final sisRegistryEffectiveFilterIndexProvider = Provider<int>((ref) {
  final index = ref.watch(sisRegistryFilterProvider);
  final labelCount = ref.watch(sisRegistryFilterLabelsProvider).length;
  if (labelCount == 0) return 0;
  return index.clamp(0, labelCount - 1);
});

final sisStudentsQueryProvider = Provider<RepositoryQuery>((ref) {
  final baseQuery = ref.watch(repositoryQueryProvider);
  final page = ref.watch(sisRegistryPageProvider);
  var query = baseQuery.withPage(page);

  if (!isModuleApiEnabled(ref, sisApiEnabledProvider)) {
    return query;
  }

  final params = <String, String>{};
  final search = ref.watch(sisRegistrySearchProvider).trim();
  if (search.isNotEmpty) {
    params['search'] = search;
  }

  final filterIndex = ref.watch(sisRegistryEffectiveFilterIndexProvider);
  switch (filterIndex) {
    case 1:
      params['status'] = 'active';
    case 2:
      params['status'] = 'inactive';
    default:
      if (filterIndex >= sisRegistryBaseFilterCount) {
        final classes = ref.watch(sisRegistryClassFilterOptionsProvider);
        final classIndex = filterIndex - sisRegistryBaseFilterCount;
        if (classIndex >= 0 && classIndex < classes.length) {
          params['className'] = classes[classIndex];
        }
      }
  }

  return query.withAdditionalParams(params);
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
  if (isModuleApiEnabled(ref, sisApiEnabledProvider)) {
    return ref.watch(sisStudentsProvider);
  }

  final students = ref.watch(sisStudentsProvider);
  final query = ref.watch(sisRegistrySearchProvider).trim().toLowerCase();
  final filterIndex = ref.watch(sisRegistryEffectiveFilterIndexProvider);
  final classes = ref.watch(sisRegistryClassFilterOptionsProvider);

  var filtered = students;
  filtered = switch (filterIndex) {
    1 => filtered
        .where((s) => s.status == SisStudentStatus.active)
        .toList(),
    2 => filtered
        .where((s) => s.status == SisStudentStatus.prospect)
        .toList(),
    _ when filterIndex >= sisRegistryBaseFilterCount =>
      filtered.where((s) {
        final classIndex = filterIndex - sisRegistryBaseFilterCount;
        if (classIndex < 0 || classIndex >= classes.length) return true;
        return s.classLabel == classes[classIndex];
      }).toList(),
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
