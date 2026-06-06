import 'package:flutter_riverpod/flutter_riverpod.dart';

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
  (ref) => const [
    FeeStructureOption(
      id: 'fee_std',
      label: 'Standard CBSE',
      annualAmount: '₹1,85,000',
      installments: 3,
    ),
    FeeStructureOption(
      id: 'fee_premium',
      label: 'Premium + Transport',
      annualAmount: '₹2,15,000',
      installments: 3,
    ),
    FeeStructureOption(
      id: 'fee_hostel',
      label: 'Boarding Package',
      annualAmount: '₹3,40,000',
      installments: 4,
    ),
  ],
);

final admissionsApprovedHandoffsProvider =
    Provider<List<ApprovedStudentHandoff>>((ref) {
  if (ref.watch(admissionsFeeHandoffLoadingProvider)) return const [];
  if (ref.watch(admissionsFeeHandoffErrorProvider)) return const [];
  if (ref.watch(admissionsFeeHandoffEmptyProvider)) return const [];
  final overrides = ref.watch(feeHandoffStatusOverridesProvider);
  return _mockHandoffs()
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

List<ApprovedStudentHandoff> _mockHandoffs() {
  return const [
    ApprovedStudentHandoff(
      id: 'handoff_1',
      studentName: 'Arjun Patel',
      classLabel: '10',
      applicationId: 'APP-2188',
      admissionNumber: 'ADM-2026-0138',
      needsTransport: false,
      needsHostel: false,
      selectedFeeStructureId: 'fee_std',
      handoffStatus: FeeHandoffStatus.sentToFinance,
      previewStudentId: 'SIS-STU-10421',
      sisHandoffLabel: 'Queued for Student SIS',
    ),
    ApprovedStudentHandoff(
      id: 'handoff_2',
      studentName: 'Ananya Reddy',
      classLabel: '5',
      applicationId: 'APP-2208',
      admissionNumber: 'ADM-2026-0142',
      needsTransport: true,
      needsHostel: false,
      selectedFeeStructureId: 'fee_premium',
      handoffStatus: FeeHandoffStatus.pending,
      previewStudentId: 'SIS-STU-10422',
      sisHandoffLabel: 'Pending finance confirmation',
    ),
    ApprovedStudentHandoff(
      id: 'handoff_3',
      studentName: 'Emma Thomas',
      classLabel: '7',
      applicationId: 'APP-2175',
      admissionNumber: 'ADM-2026-0135',
      needsTransport: true,
      needsHostel: true,
      selectedFeeStructureId: 'fee_hostel',
      handoffStatus: FeeHandoffStatus.completed,
      previewStudentId: 'SIS-STU-10418',
      sisHandoffLabel: 'Active in Student SIS',
    ),
  ];
}
