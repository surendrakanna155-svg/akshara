import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/tenant/tenant_provider.dart';
import '../../../core/providers/repository_future.dart';
import '../../../core/repositories/paginated_result.dart';
import '../../../core/repositories/repository_providers.dart';
import '../finance_async_state.dart';
import '../finance_models.dart';

final financeFeeStructuresLoadingProvider = StateProvider<bool>((ref) => false);
final financeFeeStructuresErrorProvider = StateProvider<bool>((ref) => false);
final financeFeeStructuresEmptyProvider = StateProvider<bool>((ref) => false);
final financeAcademicYearProvider = StateProvider<String>((ref) => '2026-27');

final financeFeeStructuresFutureProvider =
    FutureProvider<PaginatedResult<FinanceFeeStructure>>((ref) async {
  final year = ref.watch(financeAcademicYearProvider);
  return ref.read(financeRepositoryProvider).getFeeStructures(
        query: ref.watch(repositoryQueryProvider),
        academicYear: year,
      );
});

final financeFeeStructuresProvider = Provider<List<FinanceFeeStructure>>((ref) {
  return watchRepositoryFuture(
        ref,
        ref.watch(financeFeeStructuresFutureProvider),
        manualLoading: ref.watch(financeFeeStructuresLoadingProvider),
        manualError: ref.watch(financeFeeStructuresErrorProvider),
        manualEmpty: ref.watch(financeFeeStructuresEmptyProvider),
      )?.items ??
      const [];
});

final financeAcademicYearsFutureProvider =
    FutureProvider<PaginatedResult<String>>((ref) async {
  return ref
      .read(financeRepositoryProvider)
      .getAcademicYears(query: ref.watch(repositoryQueryProvider));
});

final financeAcademicYearsProvider = Provider<List<String>>(
  (ref) =>
      watchRepositoryFuture(
        ref,
        ref.watch(financeAcademicYearsFutureProvider),
        manualLoading: false,
        manualError: false,
        manualEmpty: false,
      )?.items ??
      const [],
);

final financeFeeStructuresViewStateProvider =
    Provider<FinanceViewState<PaginatedResult<FinanceFeeStructure>>>((ref) {
  return resolveFinanceAsync(
    ref.watch(financeFeeStructuresFutureProvider),
    forceLoading: ref.watch(financeFeeStructuresLoadingProvider),
    forceError: ref.watch(financeFeeStructuresErrorProvider),
    forceEmpty: ref.watch(financeFeeStructuresEmptyProvider),
    isDataEmpty: (result) => result.items.isEmpty,
  );
});
