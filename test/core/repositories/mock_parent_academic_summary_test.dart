import 'package:akshara_erp/core/exams/exam_administration_store.dart';
import 'package:akshara_erp/core/repositories/mock/mock_attendance_sync_store.dart';
import 'package:akshara_erp/core/repositories/mock/mock_canonical_student_registry.dart';
import 'package:akshara_erp/core/repositories/mock/mock_parent_repository.dart';
import 'package:akshara_erp/core/repositories/repository_query.dart';
import 'package:flutter_test/flutter_test.dart';

const _query = RepositoryQuery(tenantId: 'tenant_demo', schoolId: 'school_demo');

void main() {
  group('P1-PAR-001 parent academic summary', () {
    final repo = MockParentRepository();
    final studentId = MockCanonicalStudentRegistry.primaryMobileStudentId;

    setUp(() {
      MockAttendanceSyncStore.instance.reset();
      ExamAdministrationStore.instance.reset();
      ExamAdministrationStore.instance.ensureSeeded();
    });

    test('uses teacher attendance sync when submitted', () async {
      MockAttendanceSyncStore.instance.recordTeacherSubmit(
        present: 20,
        absent: 2,
        late: 3,
      );

      final summary = await repo.getAcademicSummary(
        query: _query,
        studentId: studentId,
      );

      expect(summary.attendanceSummary['ratePercent'], 80);
      expect(summary.attendanceSummary['presentDays'], 20);
      expect(summary.attendanceSummary['totalDays'], 25);
    });

    test('reflects published exam results in performance summary', () async {
      final store = ExamAdministrationStore.instance..ensureSeeded();
      for (final student in MockCanonicalStudentRegistry.class8A()) {
        final markId = 'exam_math_8a_${student.rollNo}';
        if (store.markById(markId)?.marksObtained == null) {
          store.recordMark(markEntryId: markId, marksObtained: 40);
        }
      }
      store.processResults('exam_math_8a');
      store.publishExamResults('exam_math_8a');

      final summary = await repo.getAcademicSummary(
        query: _query,
        studentId: studentId,
      );

      expect(summary.performanceSummary['overallGrade'], isNot('—'));
      expect(
        summary.examReadiness['recommendation'],
        contains('published'),
      );
    });
  });
}
