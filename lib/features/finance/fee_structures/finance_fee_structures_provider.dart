import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/repositories/repository_providers.dart';
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
  return ref.read(financeRepositoryProvider).getFeeStructures(year);
});

final financeAcademicYearsProvider = Provider<List<String>>(
  (ref) => ref.read(financeRepositoryProvider).getAcademicYears(),
);
