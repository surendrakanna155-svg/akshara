import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/repositories/repository_providers.dart';
import '../sis_models.dart';

final sisRegistryLoadingProvider = StateProvider<bool>((ref) => false);
final sisRegistryErrorProvider = StateProvider<bool>((ref) => false);
final sisRegistryEmptyProvider = StateProvider<bool>((ref) => false);
final sisRegistrySearchProvider = StateProvider<String>((ref) => '');
final sisRegistryFilterProvider = StateProvider<int>((ref) => 0);

final sisStudentsProvider = Provider<List<SisStudent>>((ref) {
  if (ref.watch(sisRegistryLoadingProvider)) return const [];
  if (ref.watch(sisRegistryErrorProvider)) return const [];
  if (ref.watch(sisRegistryEmptyProvider)) return const [];
  return ref.read(sisRepositoryProvider).getStudents();
});

final sisFilteredStudentsProvider = Provider<List<SisStudent>>((ref) {
  final students = ref.watch(sisStudentsProvider);
  final query = ref.watch(sisRegistrySearchProvider).trim().toLowerCase();
  final filterIndex = ref.watch(sisRegistryFilterProvider);

  var filtered = students;
  filtered = switch (filterIndex) {
    1 => filtered
        .where((s) => s.status == SisStudentStatus.active)
        .toList(),
    2 => filtered
        .where((s) => s.status == SisStudentStatus.prospect)
        .toList(),
    3 => filtered.where((s) => s.classLabel == '10').toList(),
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
