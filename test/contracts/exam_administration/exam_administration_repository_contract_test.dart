import 'package:akshara_erp/core/exams/exam_administration_store.dart';
import 'package:akshara_erp/core/repositories/mock/mock_exam_administration_repository.dart';
import 'package:akshara_erp/core/repositories/repository_query.dart';
import 'package:akshara_erp/features/education/education_models.dart';
import 'package:akshara_erp/core/exams/exam_administration_requests.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const query = RepositoryQuery.demo;

  setUp(() {
    ExamAdministrationStore.instance.reset();
  });

  group('Exam administration repository contract', () {
    final repo = MockExamAdministrationRepository();

    test('listExams returns seeded sessions after ensure', () async {
      final exams = await repo.listExams(query: query);
      expect(exams, isNotEmpty);
      expect(exams.any((e) => e.id == 'exam_math_8a'), isTrue);
    });

    test('create → schedule → open marks → update mark → process → publish', () async {
      final created = await repo.createExam(
        query: query,
        request: const CreateExamAdministrationRequest(
          title: 'Half-Yearly Mathematics',
          subject: 'Mathematics',
          grade: '8',
          section: 'B',
          termLabel: 'Term 2',
          dateLabel: '20 Jun 2026',
          timeLabel: '9:00 AM',
          venueLabel: 'Room 8B',
          syllabusLabel: 'Algebra',
          maxMarks: 80,
          examType: EduExamType.halfYearly,
        ),
      );
      expect(created.phase, ExamLifecyclePhase.draft);
      expect(created.examType, EduExamType.halfYearly);

      final scheduled = await repo.scheduleExam(
        query: query,
        examId: created.id,
      );
      expect(scheduled.phase, ExamLifecyclePhase.scheduled);

      final marksOpen = await repo.openMarksEntry(
        query: query,
        examId: created.id,
      );
      expect(marksOpen.phase, ExamLifecyclePhase.marksEntry);

      final marks = await repo.listMarks(query: query, examId: created.id);
      expect(marks, isNotEmpty);

      for (final mark in marks) {
        await repo.updateMark(
          query: query,
          request: UpdateExamMarkRequest(
            markEntryId: mark.id,
            marksObtained: 40,
          ),
        );
      }

      final processed = await repo.processResults(
        query: query,
        examId: created.id,
      );
      expect(processed.phase, ExamLifecyclePhase.processed);

      final publishedCount = await repo.publishResults(
        query: query,
        examId: created.id,
      );
      expect(publishedCount, marks.length);

      final studentId = marks.first.sisStudentId;
      final published = await repo.listPublishedResultsForStudent(
        query: query,
        sisStudentId: studentId,
      );
      expect(published.any((r) => r.examId == created.id), isTrue);
    });

    test('getExam returns null for unknown id', () async {
      final exam = await repo.getExam(query: query, examId: 'missing');
      expect(exam, isNull);
    });
  });
}
