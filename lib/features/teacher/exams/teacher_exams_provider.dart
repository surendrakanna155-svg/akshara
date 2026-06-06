import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'exam_models.dart';

final teacherExamSectionProvider = StateProvider<TeacherExamSection>(
  (ref) => TeacherExamSection.upcoming,
);

final teacherExamsLoadingProvider = StateProvider<bool>((ref) => false);
final teacherExamsErrorProvider = StateProvider<bool>((ref) => false);
final teacherExamsEmptyProvider = StateProvider<bool>((ref) => false);

final _teacherExamMarksProvider = StateProvider<List<ExamMarkEntry>>(
  (ref) => _mockMarks(),
);

final teacherExamsProvider = Provider<TeacherExamsData>((ref) {
  if (ref.watch(teacherExamsEmptyProvider)) {
    return const TeacherExamsData(
      upcomingExams: [],
      markEntries: [],
      classAveragePercent: 0,
      unreadNotifications: 1,
    );
  }

  final marks = ref.watch(_teacherExamMarksProvider);
  final scored = marks.where((m) => m.marksObtained != null).toList();
  final avg = scored.isEmpty
      ? 0
      : (scored
              .map((m) => m.percent ?? 0)
              .fold<int>(0, (a, b) => a + b) /
          scored.length)
          .round();

  return TeacherExamsData(
    upcomingExams: const [
      TeacherUpcomingExam(
        id: 'ex_1',
        title: 'Unit Test — Mathematics',
        classLabel: '8-A',
        dateLabel: '12 Jun 2026',
        maxMarks: 50,
      ),
      TeacherUpcomingExam(
        id: 'ex_2',
        title: 'Term 2 Assessment',
        classLabel: '9-B',
        dateLabel: '20 Jun 2026',
        maxMarks: 80,
      ),
    ],
    markEntries: marks,
    classAveragePercent: avg,
    unreadNotifications: 1,
  );
});

List<ExamMarkEntry> _mockMarks() {
  return const [
    ExamMarkEntry(id: 'm1', studentName: 'Ravi Kumar', rollNo: '01', marksObtained: 42, maxMarks: 50),
    ExamMarkEntry(id: 'm2', studentName: 'Ananya Rao', rollNo: '02', marksObtained: 45, maxMarks: 50),
    ExamMarkEntry(id: 'm3', studentName: 'Karthik Menon', rollNo: '03', marksObtained: null, maxMarks: 50),
    ExamMarkEntry(id: 'm4', studentName: 'Priya Nair', rollNo: '04', marksObtained: 38, maxMarks: 50),
  ];
}

void updateExamMark(WidgetRef ref, String entryId, int marks) {
  ref.read(_teacherExamMarksProvider.notifier).state = [
    for (final entry in ref.read(_teacherExamMarksProvider))
      entry.id == entryId ? entry.copyWith(marksObtained: marks) : entry,
  ];
}
