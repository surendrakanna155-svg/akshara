import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../registry/sis_registry_provider.dart';
import '../sis_models.dart';

final sisAcademicAssignmentLoadingProvider = StateProvider<bool>((ref) => false);
final sisAcademicAssignmentErrorProvider = StateProvider<bool>((ref) => false);
final sisSelectedAssignmentStudentIdProvider = StateProvider<String?>(
  (ref) => null,
);

final sisClassOptionsProvider = Provider<List<String>>(
  (ref) => const ['Nursery', '1', '2', '3', '4', '5', '6', '7', '8', '9', '10', '11', '12'],
);

final sisSectionOptionsProvider = Provider<List<String>>(
  (ref) => const ['A', 'B', 'C', 'D'],
);

final sisAcademicYearOptionsProvider = Provider<List<String>>(
  (ref) => const ['2026–27', '2025–26'],
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
