import 'package:akshara_erp/core/homework/school_homework_store.dart';
import 'package:akshara_erp/core/repositories/mock/mock_canonical_student_registry.dart';
import 'package:akshara_erp/core/repositories/mock/mock_parent_repository.dart';
import 'package:akshara_erp/core/repositories/mock/mock_student_repository.dart';
import 'package:akshara_erp/core/repositories/mock/mock_teacher_repository.dart';
import 'package:akshara_erp/core/repositories/repository_query.dart';
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

    // Student sees the grade + comment.
    final studentItems =
        await MockStudentRepository().getHomeworkItems(query: query);
    final si = studentItems.firstWhere((i) => i.id == record.id);
    expect(si.isReviewed, isTrue);
    expect(si.reviewGrade, 'A');
    expect(si.reviewComment, 'Well done');

    // Parent sees it too.
    final parent = await MockParentRepository().getHomework(query: query);
    final pi = parent.items.firstWhere((i) => i.id == record.id);
    expect(pi.reviewGrade, 'A');
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
