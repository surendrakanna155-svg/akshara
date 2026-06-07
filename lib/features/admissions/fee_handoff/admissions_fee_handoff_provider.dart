import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/tenant/tenant_provider.dart';
import '../../../core/providers/repository_future.dart';
import '../../../core/repositories/paginated_result.dart';
import '../../../core/repositories/repository_providers.dart';
import '../admissions_async_state.dart';
import '../admissions_models.dart';

final admissionsFeeHandoffLoadingProvider = StateProvider<bool>((ref) => false);
final admissionsFeeHandoffErrorProvider = StateProvider<bool>((ref) => false);
final admissionsFeeHandoffEmptyProvider = StateProvider<bool>((ref) => false);

final admissionsSelectedHandoffIdProvider = StateProvider<String?>(
  (ref) => null,
);

/// Shared handoff status overrides (updated by Finance fee assignment).
final feeHandoffStatusOverridesProvider =
    StateProvider<Map<String, FeeHandoffStatus>>((ref) => {});

final admissionsFeeStructuresFutureProvider =
    FutureProvider<PaginatedResult<FeeStructureOption>>((ref) async {
  return ref
      .read(admissionsRepositoryProvider)
      .getFeeStructureOptions(query: ref.watch(repositoryQueryProvider));
});

final admissionsFeeStructuresProvider = Provider<List<FeeStructureOption>>(
  (ref) =>
      watchRepositoryFuture(
        ref,
        ref.watch(admissionsFeeStructuresFutureProvider),
        manualLoading: false,
        manualError: false,
        manualEmpty: false,
      )?.items ??
      const [],
);

final admissionsApprovedHandoffsRawFutureProvider =
    FutureProvider<PaginatedResult<ApprovedStudentHandoff>>((ref) async {
  return ref
      .read(admissionsRepositoryProvider)
      .getApprovedHandoffs(query: ref.watch(repositoryQueryProvider));
});

/// Applies fee-handoff status overrides without refetching the async source.
final admissionsApprovedHandoffsFutureProvider =
    Provider<AsyncValue<PaginatedResult<ApprovedStudentHandoff>>>((ref) {
  final raw = ref.watch(admissionsApprovedHandoffsRawFutureProvider);
  final overrides = ref.watch(feeHandoffStatusOverridesProvider);
  return raw.whenData(
    (page) => PaginatedResult(
      items: page.items
          .map(
            (handoff) => overrides.containsKey(handoff.id)
                ? _withHandoffStatus(handoff, overrides[handoff.id]!)
                : handoff,
          )
          .toList(growable: false),
      page: page.page,
      pageSize: page.pageSize,
      total: page.total,
      hasMore: page.hasMore,
    ),
  );
});

final admissionsApprovedHandoffsProvider =
    Provider<List<ApprovedStudentHandoff>>((ref) {
  final asyncPage = ref.watch(admissionsApprovedHandoffsFutureProvider);
  if (ref.watch(admissionsFeeHandoffLoadingProvider)) return const [];
  if (ref.watch(admissionsFeeHandoffErrorProvider)) return const [];
  if (ref.watch(admissionsFeeHandoffEmptyProvider)) return const [];
  return asyncPage.valueOrNull?.items ?? const [];
});

final admissionsFeeHandoffViewStateProvider =
    Provider<AdmissionsViewState<PaginatedResult<ApprovedStudentHandoff>>>(
        (ref) {
  return resolveAdmissionsAsync(
    ref.watch(admissionsApprovedHandoffsFutureProvider),
    forceLoading: ref.watch(admissionsFeeHandoffLoadingProvider),
    forceError: ref.watch(admissionsFeeHandoffErrorProvider),
    forceEmpty: ref.watch(admissionsFeeHandoffEmptyProvider),
    isDataEmpty: (result) => result.items.isEmpty,
  );
});

ApprovedStudentHandoff _withHandoffStatus(
  ApprovedStudentHandoff handoff,
  FeeHandoffStatus status,
) {
  return ApprovedStudentHandoff(
    id: handoff.id,
    studentName: handoff.studentName,
    classLabel: handoff.classLabel,
    applicationId: handoff.applicationId,
    admissionNumber: handoff.admissionNumber,
    needsTransport: handoff.needsTransport,
    needsHostel: handoff.needsHostel,
    selectedFeeStructureId: handoff.selectedFeeStructureId,
    handoffStatus: status,
    previewStudentId: handoff.previewStudentId,
    sisHandoffLabel: handoff.sisHandoffLabel,
  );
}
