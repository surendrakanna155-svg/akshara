import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/repositories/academic/academic_catalog_provider.dart';
import '../../../core/repositories/academic/academic_models.dart';
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

final sisAcademicAssignmentViewStateProvider =
    Provider<SisViewState<AcademicCatalogData>>((ref) {
  return resolveSisAsync(
    ref.watch(academicCatalogFutureProvider),
    forceLoading: ref.watch(sisAcademicAssignmentLoadingProvider) ||
        ref.watch(academicCatalogLoadingProvider),
    forceError: ref.watch(sisAcademicAssignmentErrorProvider) ||
        ref.watch(academicCatalogErrorProvider),
  );
});

final sisClassOptionsProvider = classOptionsProvider;

final sisSectionOptionsProvider = sectionOptionsProvider;

final sisAcademicYearOptionsProvider = yearOptionsProvider;

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
        ref.watch(academicCatalogViewStateProvider).isLoading,
    forceError: ref.watch(sisAcademicAssignmentErrorProvider) ||
        ref.watch(academicCatalogViewStateProvider).hasError ||
        ref.watch(sisRegistryViewStateProvider).hasError,
    isDataEmpty: (result) => result.items.isEmpty,
  );
});
