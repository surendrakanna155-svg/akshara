import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../finance_models.dart';

final financeFeeStructuresLoadingProvider = StateProvider<bool>((ref) => false);
final financeFeeStructuresErrorProvider = StateProvider<bool>((ref) => false);
final financeFeeStructuresEmptyProvider = StateProvider<bool>((ref) => false);
final financeAcademicYearProvider = StateProvider<String>((ref) => '2026-27');

final financeFeeStructuresProvider = Provider<List<FinanceFeeStructure>>((ref) {
  if (ref.watch(financeFeeStructuresLoadingProvider)) return const [];
  if (ref.watch(financeFeeStructuresErrorProvider)) return const [];
  if (ref.watch(financeFeeStructuresEmptyProvider)) return const [];
  final year = ref.watch(financeAcademicYearProvider);
  return _mockStructures(year);
});

final financeAcademicYearsProvider = Provider<List<String>>(
  (ref) => const ['2026-27', '2025-26', '2024-25'],
);

List<FinanceFeeStructure> _mockStructures(String year) {
  return [
    FinanceFeeStructure(
      id: 'fee_std',
      name: 'Standard CBSE',
      academicYear: year,
      totalAnnual: '₹1,85,000',
      classRange: 'Nursery – 12',
      status: FeeStructureStatus.active,
      installmentOptions: const [3, 4],
      categories: const [
        FeeCategoryLine(
          category: FeeStructureCategory.tuition,
          label: 'Tuition',
          amount: '₹1,45,000',
        ),
        FeeCategoryLine(
          category: FeeStructureCategory.activity,
          label: 'Activity & Labs',
          amount: '₹40,000',
        ),
      ],
    ),
    FinanceFeeStructure(
      id: 'fee_premium',
      name: 'Premium + Transport',
      academicYear: year,
      totalAnnual: '₹2,15,000',
      classRange: '1 – 12',
      status: FeeStructureStatus.active,
      installmentOptions: const [3, 4],
      categories: const [
        FeeCategoryLine(
          category: FeeStructureCategory.tuition,
          label: 'Tuition',
          amount: '₹1,55,000',
        ),
        FeeCategoryLine(
          category: FeeStructureCategory.transport,
          label: 'Transport',
          amount: '₹30,000',
        ),
        FeeCategoryLine(
          category: FeeStructureCategory.activity,
          label: 'Activity',
          amount: '₹30,000',
        ),
      ],
    ),
    FinanceFeeStructure(
      id: 'fee_hostel',
      name: 'Boarding Package',
      academicYear: year,
      totalAnnual: '₹3,40,000',
      classRange: '5 – 12',
      status: FeeStructureStatus.active,
      installmentOptions: const [4, 6],
      categories: const [
        FeeCategoryLine(
          category: FeeStructureCategory.tuition,
          label: 'Tuition',
          amount: '₹1,80,000',
        ),
        FeeCategoryLine(
          category: FeeStructureCategory.hostel,
          label: 'Hostel',
          amount: '₹1,20,000',
        ),
        FeeCategoryLine(
          category: FeeStructureCategory.transport,
          label: 'Transport',
          amount: '₹25,000',
        ),
        FeeCategoryLine(
          category: FeeStructureCategory.activity,
          label: 'Activity',
          amount: '₹15,000',
        ),
      ],
    ),
    const FinanceFeeStructure(
      id: 'fee_legacy',
      name: 'Legacy 2024 Plan',
      academicYear: '2024-25',
      totalAnnual: '₹1,65,000',
      classRange: 'Nursery – 12',
      status: FeeStructureStatus.inactive,
      installmentOptions: [3],
      categories: [
        FeeCategoryLine(
          category: FeeStructureCategory.tuition,
          label: 'Tuition',
          amount: '₹1,65,000',
        ),
      ],
    ),
  ].where((s) => s.academicYear == year || s.status == FeeStructureStatus.inactive).toList();
}
