import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'homework_models.dart';

final teacherHomeworkAssignmentProvider = StateProvider<String>(
  (ref) => 'hw_8a_1',
);

final teacherHomeworkLoadingProvider = StateProvider<bool>((ref) => false);
final teacherHomeworkErrorProvider = StateProvider<bool>((ref) => false);
final teacherHomeworkEmptyProvider = StateProvider<bool>((ref) => false);

final _teacherHomeworkSubmissionsProvider =
    StateProvider<Map<String, List<HomeworkSubmission>>>(
  (ref) => _mockSubmissions(),
);

final teacherHomeworkAssignmentsProvider = Provider<List<TeacherHomeworkAssignment>>((ref) {
  final map = ref.watch(_teacherHomeworkSubmissionsProvider);
  if (ref.watch(teacherHomeworkEmptyProvider)) return const [];

  return [
    TeacherHomeworkAssignment(
      id: 'hw_8a_1',
      title: 'Exercise 5.2 — Linear equations',
      classLabel: '8-A',
      dueLabel: 'Due 8 Jun 2026',
      submissions: map['hw_8a_1'] ?? const [],
    ),
    TeacherHomeworkAssignment(
      id: 'hw_9b_1',
      title: 'Chapter 4 problem set',
      classLabel: '9-B',
      dueLabel: 'Due 10 Jun 2026',
      submissions: map['hw_9b_1'] ?? const [],
    ),
  ];
});

final teacherHomeworkProvider = Provider<TeacherHomeworkAssignment?>((ref) {
  final id = ref.watch(teacherHomeworkAssignmentProvider);
  final assignments = ref.watch(teacherHomeworkAssignmentsProvider);
  for (final item in assignments) {
    if (item.id == id) return item;
  }
  return assignments.isEmpty ? null : assignments.first;
});

Map<String, List<HomeworkSubmission>> _mockSubmissions() {
  return {
    'hw_8a_1': const [
      HomeworkSubmission(
        id: 'sub_1',
        studentName: 'Ravi Kumar',
        classLabel: '8-A',
        title: 'Exercise 5.2',
        submittedLabel: 'Submitted 5 Jun · 6:40 PM',
        status: HomeworkReviewStatus.pending,
      ),
      HomeworkSubmission(
        id: 'sub_2',
        studentName: 'Ananya Rao',
        classLabel: '8-A',
        title: 'Exercise 5.2',
        submittedLabel: 'Submitted 5 Jun · 7:10 PM',
        status: HomeworkReviewStatus.pending,
      ),
      HomeworkSubmission(
        id: 'sub_3',
        studentName: 'Karthik Menon',
        classLabel: '8-A',
        title: 'Exercise 5.2',
        submittedLabel: 'Submitted 4 Jun',
        status: HomeworkReviewStatus.reviewed,
        grade: 'A',
        comment: 'Excellent steps shown.',
      ),
    ],
    'hw_9b_1': const [
      HomeworkSubmission(
        id: 'sub_4',
        studentName: 'Dev Patel',
        classLabel: '9-B',
        title: 'Chapter 4 problem set',
        submittedLabel: 'Submitted 5 Jun',
        status: HomeworkReviewStatus.pending,
      ),
    ],
  };
}

void reviewSubmission(
  WidgetRef ref, {
  required String assignmentId,
  required String submissionId,
  required String grade,
  required String comment,
}) {
  final map = Map<String, List<HomeworkSubmission>>.from(
    ref.read(_teacherHomeworkSubmissionsProvider),
  );
  final list = map[assignmentId];
  if (list == null) return;
  map[assignmentId] = [
    for (final item in list)
      item.id == submissionId
          ? item.copyWith(
              status: HomeworkReviewStatus.reviewed,
              grade: grade,
              comment: comment,
            )
          : item,
  ];
  ref.read(_teacherHomeworkSubmissionsProvider.notifier).state = map;
}
