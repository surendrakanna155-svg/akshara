import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/repository_future.dart';
import '../../../core/repositories/repository_providers.dart';
import '../../../core/tenant/tenant_provider.dart';
import '../../../core/repositories/paginated_result.dart';
import '../registry/sis_registry_provider.dart';
import '../sis_async_state.dart';
import '../sis_models.dart';

final sisAcademicAssignmentLoadingProvider =
    StateProvider<bool>((ref) => false);
final sisAcademicAssignmentErrorProvider = StateProvider<bool>((ref) => false);
final sisSelectedAssignmentStudentIdProvider = StateProvider<String?>(
  (ref) => null,
);

final sisAcademicAssignmentFutureProvider =
    FutureProvider<SisAcademicAssignmentData>((ref) async {
  return ref.read(sisRepositoryProvider).getAcademicAssignment(
        query: ref.watch(repositoryQueryProvider),
      );
});

final sisAcademicAssignmentViewStateProvider =
    Provider<SisViewState<SisAcademicAssignmentData>>((ref) {
  return resolveSisAsync(
    ref.watch(sisAcademicAssignmentFutureProvider),
    forceLoading: ref.watch(sisAcademicAssignmentLoadingProvider),
    forceError: ref.watch(sisAcademicAssignmentErrorProvider),
  );
});

final sisClassOptionsFutureProvider = FutureProvider<List<String>>((ref) async {
  final data = await ref.watch(sisAcademicAssignmentFutureProvider.future);
  return data.classOptions;
});

final sisClassOptionsProvider = Provider<List<String>>(
  (ref) =>
      watchRepositoryFuture(
        ref,
        ref.watch(sisClassOptionsFutureProvider),
        manualLoading: false,
        manualError: false,
        manualEmpty: false,
      ) ??
      ref.watch(sisAcademicAssignmentViewStateProvider).data?.classOptions ??
      const [],
);

final sisSectionOptionsFutureProvider =
    FutureProvider<List<String>>((ref) async {
  final data = await ref.watch(sisAcademicAssignmentFutureProvider.future);
  return data.sectionOptions;
});

final sisSectionOptionsProvider = Provider<List<String>>(
  (ref) =>
      watchRepositoryFuture(
        ref,
        ref.watch(sisSectionOptionsFutureProvider),
        manualLoading: false,
        manualError: false,
        manualEmpty: false,
      ) ??
      ref.watch(sisAcademicAssignmentViewStateProvider).data?.sectionOptions ??
      const [],
);

final sisAcademicYearOptionsFutureProvider =
    FutureProvider<List<String>>((ref) async {
  final data = await ref.watch(sisAcademicAssignmentFutureProvider.future);
  return data.academicYearOptions;
});

final sisAcademicYearOptionsProvider = Provider<List<String>>(
  (ref) =>
      watchRepositoryFuture(
        ref,
        ref.watch(sisAcademicYearOptionsFutureProvider),
        manualLoading: false,
        manualError: false,
        manualEmpty: false,
      ) ??
      ref
          .watch(sisAcademicAssignmentViewStateProvider)
          .data
          ?.academicYearOptions ??
      const [],
);

final sisAssignmentDraftProvider = StateProvider<SisAcademicAssignmentDraft?>(
  (ref) => null,
);

final sisSelectedAssignmentStudentProvider = Provider<SisStudent?>((ref) {
  final students = ref.watch(sisStudentsProvider);
  final selectedId = ref.watch(sisSelectedAssignmentStudentIdProvider);
  if (selectedId == null) return students.isEmpty ? null : students.first;
  for (final student in students) {
    if (student.id == selectedId) return student;
  }
  return null;
});

final sisAcademicAssignmentScreenViewStateProvider =
    Provider<SisViewState<PaginatedResult<SisStudent>>>((ref) {
  return resolveSisAsync(
    ref.watch(sisStudentsFutureProvider),
    forceLoading: ref.watch(sisAcademicAssignmentLoadingProvider) ||
        ref.watch(sisAcademicAssignmentViewStateProvider).isLoading,
    forceError: ref.watch(sisAcademicAssignmentErrorProvider) ||
        ref.watch(sisAcademicAssignmentViewStateProvider).hasError ||
        ref.watch(sisRegistryViewStateProvider).hasError,
    isDataEmpty: (result) => result.items.isEmpty,
  );
});
