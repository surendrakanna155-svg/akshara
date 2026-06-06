import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'homework_models.dart';

final studentHomeworkFilterProvider = StateProvider<StudentHomeworkFilter>(
  (ref) => StudentHomeworkFilter.all,
);

final studentHomeworkLoadingProvider = StateProvider<bool>((ref) => false);
final studentHomeworkErrorProvider = StateProvider<bool>((ref) => false);
final studentHomeworkEmptyProvider = StateProvider<bool>((ref) => false);

final _studentHomeworkItemsProvider = Provider<List<StudentHomeworkItem>>(
  (ref) => _mockItems(),
);

final studentHomeworkItemsProvider = Provider<List<StudentHomeworkItem>>((ref) {
  if (ref.watch(studentHomeworkEmptyProvider)) return const [];

  final filter = ref.watch(studentHomeworkFilterProvider);
  final items = ref.watch(_studentHomeworkItemsProvider);

  return switch (filter) {
    StudentHomeworkFilter.all => items,
    StudentHomeworkFilter.pending => items
        .where(
          (i) =>
              i.status == StudentHomeworkStatus.pending ||
              i.status == StudentHomeworkStatus.overdue,
        )
        .toList(growable: false),
    StudentHomeworkFilter.submitted => items
        .where((i) => i.status == StudentHomeworkStatus.submitted)
        .toList(growable: false),
  };
});

final studentHomeworkProvider = Provider<StudentHomeworkData>((ref) {
  return StudentHomeworkData(
    studentName: 'Ravi Kumar',
    classLabel: '8-A',
    unreadNotifications: 2,
    items: ref.watch(studentHomeworkItemsProvider),
  );
});

List<StudentHomeworkItem> _mockItems() {
  return const [
    StudentHomeworkItem(
      id: 'hw-1',
      subject: 'Mathematics',
      title: 'Algebra worksheet — Exercise 5.2',
      dueLabel: 'Due tomorrow · 8 Jun',
      status: StudentHomeworkStatus.pending,
      attachmentLabel: 'worksheet_5_2.pdf',
    ),
    StudentHomeworkItem(
      id: 'hw-2',
      subject: 'Science',
      title: 'Photosynthesis lab report',
      dueLabel: 'Due today · Overdue',
      status: StudentHomeworkStatus.overdue,
      attachmentLabel: 'lab_template.docx',
    ),
    StudentHomeworkItem(
      id: 'hw-3',
      subject: 'English',
      title: 'Essay — My favourite book',
      dueLabel: 'Submitted 4 Jun',
      status: StudentHomeworkStatus.submitted,
      submittedLabel: 'Submitted 4 Jun · 7:20 PM',
      attachmentLabel: 'essay_draft.pdf',
    ),
    StudentHomeworkItem(
      id: 'hw-4',
      subject: 'Hindi',
      title: 'Poem memorisation recording',
      dueLabel: 'Submitted 2 Jun',
      status: StudentHomeworkStatus.submitted,
      submittedLabel: 'Submitted 2 Jun · 6:10 PM',
    ),
  ];
}
