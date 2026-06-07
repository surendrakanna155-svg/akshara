import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/tenant/tenant_provider.dart';
import '../../../core/providers/repository_future.dart';
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
    FutureProvider<List<FeeStructureOption>>((ref) async {
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
      ) ??
      const [],
);

final admissionsApprovedHandoffsFutureProvider =
    FutureProvider<List<ApprovedStudentHandoff>>((ref) async {
  final overrides = ref.watch(feeHandoffStatusOverridesProvider);
  final handoffs = await ref
      .read(admissionsRepositoryProvider)
      .getApprovedHandoffs(query: ref.watch(repositoryQueryProvider));
  return handoffs
      .map(
        (handoff) => overrides.containsKey(handoff.id)
            ? _withHandoffStatus(handoff, overrides[handoff.id]!)
            : handoff,
      )
      .toList(growable: false);
});

final admissionsApprovedHandoffsProvider =
    Provider<List<ApprovedStudentHandoff>>((ref) {
  return watchRepositoryFuture(
        ref,
        ref.watch(admissionsApprovedHandoffsFutureProvider),
        manualLoading: ref.watch(admissionsFeeHandoffLoadingProvider),
        manualError: ref.watch(admissionsFeeHandoffErrorProvider),
        manualEmpty: ref.watch(admissionsFeeHandoffEmptyProvider),
      ) ??
      const [];
});

final admissionsFeeHandoffViewStateProvider =
    Provider<AdmissionsViewState<List<ApprovedStudentHandoff>>>((ref) {
  return resolveAdmissionsAsync(
    ref.watch(admissionsApprovedHandoffsFutureProvider),
    forceLoading: ref.watch(admissionsFeeHandoffLoadingProvider),
    forceError: ref.watch(admissionsFeeHandoffErrorProvider),
    forceEmpty: ref.watch(admissionsFeeHandoffEmptyProvider),
    isDataEmpty: (handoffs) => handoffs.isEmpty,
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
