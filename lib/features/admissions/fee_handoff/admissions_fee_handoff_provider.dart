import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/repositories/repository_providers.dart';
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

final admissionsFeeStructuresProvider = Provider<List<FeeStructureOption>>(
  (ref) => ref.read(admissionsRepositoryProvider).getFeeStructureOptions(),
);

final admissionsApprovedHandoffsProvider =
    Provider<List<ApprovedStudentHandoff>>((ref) {
  if (ref.watch(admissionsFeeHandoffLoadingProvider)) return const [];
  if (ref.watch(admissionsFeeHandoffErrorProvider)) return const [];
  if (ref.watch(admissionsFeeHandoffEmptyProvider)) return const [];
  final overrides = ref.watch(feeHandoffStatusOverridesProvider);
  return ref
      .read(admissionsRepositoryProvider)
      .getApprovedHandoffs()
      .map(
        (handoff) => overrides.containsKey(handoff.id)
            ? _withHandoffStatus(handoff, overrides[handoff.id]!)
            : handoff,
      )
      .toList(growable: false);
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
