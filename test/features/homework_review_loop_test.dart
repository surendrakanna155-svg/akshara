import 'package:akshara_erp/core/homework/school_homework_store.dart';
import 'package:akshara_erp/core/repositories/mock/mock_canonical_student_registry.dart';
import 'package:akshara_erp/core/repositories/mock/mock_parent_repository.dart';
import 'package:akshara_erp/core/repositories/mock/mock_student_repository.dart';
import 'package:akshara_erp/core/repositories/mock/mock_teacher_repository.dart';
import 'package:akshara_erp/core/repositories/repository_query.dart';
import 'package:akshara_erp/features/parent/homework/homework_models.dart';
import 'package:akshara_erp/features/student_app/homework/homework_models.dart';
import 'package:akshara_erp/features/teacher/teacher_requests.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const query = RepositoryQuery.demo;
  final ravi = MockCanonicalStudentRegistry.primaryMobileStudentId; // 8-A

  setUp(() => SchoolHomeworkStore.instance.reset());

  test("teacher's review (grade + comment) reaches the student and parent",
      () async {
    // Teacher assigns homework to class 8-A.
    final record = SchoolHomeworkStore.instance.create(
      grade: '8',
      section: 'A',
      subject: 'Mathematics',
      title: 'Algebra worksheet',
      dueLabel: 'Due tomorrow',
      teacherName: 'Priya Sharma',
    );

    // Teacher reviews this student's submission.
    await MockTeacherRepository().reviewHomeworkSubmission(
      query: query,
      request: TeacherHomeworkReviewRequest(
        submissionId: '${record.id}_$ravi',
        grade: 'A',
        comment: 'Well done',
      ),
    );

    // Student sees the grade + comment, and the lifecycle status advances to the
    // terminal "Reviewed" stage (not just an additive grade line).
    final studentItems =
        await MockStudentRepository().getHomeworkItems(query: query);
    final si = studentItems.firstWhere((i) => i.id == record.id);
    expect(si.isReviewed, isTrue);
    expect(si.status, StudentHomeworkStatus.reviewed);
    expect(si.status.isSubmitted, isTrue,
        reason: 'reviewed work still counts as submitted');
    expect(si.reviewGrade, 'A');
    expect(si.reviewComment, 'Well done');

    // Parent sees the same terminal "Reviewed" status.
    final parent = await MockParentRepository().getHomework(query: query);
    final pi = parent.items.firstWhere((i) => i.id == record.id);
    expect(pi.status, ParentHomeworkStatus.reviewed);
    expect(pi.reviewGrade, 'A');
  });

  test('reviewed lifecycle is per-student — classmates do not flip', () {
    final store = SchoolHomeworkStore.instance;
    final record = store.create(
      grade: '8',
      section: 'A',
      subject: 'Mathematics',
      title: 'Algebra worksheet',
      dueLabel: 'Due tomorrow',
      teacherName: 'Priya Sharma',
    );
    // Find a second 8-A student to act as the unreviewed classmate.
    final classmate = MockCanonicalStudentRegistry.forClass('8', 'A')
        .map((s) => s.sisStudentId)
        .firstWhere((id) => id != ravi);

    store.recordReview(homeworkId: record.id, sisStudentId: ravi, grade: 'A');

    // Reviewed student → terminal "Reviewed"; classmate stays at the class-level
    // status (pending by default) — proving the status is keyed per student.
    final reviewed = store.toStudentItem(record, record.title, sisStudentId: ravi);
    final other =
        store.toStudentItem(record, record.title, sisStudentId: classmate);
    expect(reviewed.status, StudentHomeworkStatus.reviewed);
    expect(other.status, isNot(StudentHomeworkStatus.reviewed));
    expect(other.status, StudentHomeworkStatus.pending);
  });

  test('homework with no review shows no grade', () async {
    final record = SchoolHomeworkStore.instance.create(
      grade: '8',
      section: 'A',
      subject: 'Science',
      title: 'Cell diagram',
      dueLabel: 'Due Friday',
      teacherName: 'Mr. Patel',
    );
    final studentItems =
        await MockStudentRepository().getHomeworkItems(query: query);
    final si = studentItems.firstWhere((i) => i.id == record.id);
    expect(si.isReviewed, isFalse);
  });
}
