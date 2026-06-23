import 'package:akshara_erp/features/parent/homework/homework_models.dart'
    as parent;
import 'package:akshara_erp/features/student_app/homework/homework_models.dart'
    as student;
import 'package:flutter_test/flutter_test.dart';

/// Locks the per-student "reviewed" lifecycle semantics (carry-over from the
/// homework loop): `reviewed` is a first-class terminal status that still counts
/// as submitted for KPIs and the Submitted filter.
void main() {
  group('student homework status lifecycle', () {
    test('reviewed is a labelled, submitted terminal state', () {
      expect(student.StudentHomeworkStatus.reviewed.label, 'Reviewed');
      expect(student.StudentHomeworkStatus.reviewed.isSubmitted, isTrue);
      expect(student.StudentHomeworkStatus.submitted.isSubmitted, isTrue);
      expect(student.StudentHomeworkStatus.pending.isSubmitted, isFalse);
      expect(student.StudentHomeworkStatus.overdue.isSubmitted, isFalse);
    });

    test('submittedCount includes reviewed; reviewedCount counts only reviewed',
        () {
      final data = student.StudentHomeworkData(
        studentName: 'Ravi',
        classLabel: '8-A',
        items: const [
          student.StudentHomeworkItem(
            id: 'a',
            subject: 'Math',
            title: 't',
            dueLabel: 'due',
            status: student.StudentHomeworkStatus.submitted,
          ),
          student.StudentHomeworkItem(
            id: 'b',
            subject: 'Sci',
            title: 't',
            dueLabel: 'due',
            status: student.StudentHomeworkStatus.reviewed,
            reviewGrade: 'A',
          ),
          student.StudentHomeworkItem(
            id: 'c',
            subject: 'Eng',
            title: 't',
            dueLabel: 'due',
            status: student.StudentHomeworkStatus.pending,
          ),
        ],
      );

      expect(data.submittedCount, 2, reason: 'submitted + reviewed');
      expect(data.reviewedCount, 1);
      expect(data.pendingCount, 1);
    });
  });

  group('parent homework status lifecycle', () {
    test('reviewed is a labelled, submitted terminal state', () {
      expect(parent.ParentHomeworkStatus.reviewed.label, 'Reviewed');
      expect(parent.ParentHomeworkStatus.reviewed.isSubmitted, isTrue);
      expect(parent.ParentHomeworkStatus.submitted.isSubmitted, isTrue);
      expect(parent.ParentHomeworkStatus.pending.isSubmitted, isFalse);
    });

    test('submittedCount includes reviewed; reviewedCount counts only reviewed',
        () {
      final data = parent.ParentHomeworkData(
        childName: 'Ravi',
        childClass: '8-A',
        insightMessage: '',
        insightActionLabel: '',
        items: const [
          parent.ParentHomeworkItem(
            id: 'a',
            subject: 'Math',
            title: 't',
            dueLabel: 'due',
            status: parent.ParentHomeworkStatus.submitted,
          ),
          parent.ParentHomeworkItem(
            id: 'b',
            subject: 'Sci',
            title: 't',
            dueLabel: 'due',
            status: parent.ParentHomeworkStatus.reviewed,
            reviewGrade: 'A',
          ),
        ],
      );

      expect(data.submittedCount, 2);
      expect(data.reviewedCount, 1);
    });
  });
}
