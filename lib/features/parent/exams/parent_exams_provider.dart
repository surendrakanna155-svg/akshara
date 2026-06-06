import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'exam_models.dart';

/// Active section in segmented control.
final parentExamSectionProvider = StateProvider<ExamSection>(
  (ref) => ExamSection.upcoming,
);

/// Loading flag reserved for API integration.
final parentExamsLoadingProvider = StateProvider<bool>((ref) => false);

/// Recoverable provider error message.
final parentExamsErrorProvider = StateProvider<String?>((ref) => null);

/// Empty-state toggle for API fallback checks.
final parentExamsEmptyProvider = StateProvider<bool>((ref) => false);

/// Mock parent exams payload.
final parentExamsProvider = Provider<ParentExamsData>((ref) {
  final empty = ref.watch(parentExamsEmptyProvider);
  final data = ParentExamsData.mock();
  if (!empty) {
    return data;
  }
  return data.copyWith(
    upcomingExams: const [],
    examResults: const [],
  );
});
