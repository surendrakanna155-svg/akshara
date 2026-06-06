import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/repositories/repository_providers.dart';
import '../registry/sis_registry_provider.dart';
import '../sis_models.dart';

final sisAcademicAssignmentLoadingProvider = StateProvider<bool>((ref) => false);
final sisAcademicAssignmentErrorProvider = StateProvider<bool>((ref) => false);
final sisSelectedAssignmentStudentIdProvider = StateProvider<String?>(
  (ref) => null,
);

final sisClassOptionsProvider = Provider<List<String>>(
  (ref) => ref.read(sisRepositoryProvider).getClassOptions(),
);

final sisSectionOptionsProvider = Provider<List<String>>(
  (ref) => ref.read(sisRepositoryProvider).getSectionOptions(),
);

final sisAcademicYearOptionsProvider = Provider<List<String>>(
  (ref) => ref.read(sisRepositoryProvider).getAcademicYearOptions(),
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
