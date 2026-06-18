import 'package:akshara_erp/core/exams/exam_administration_persistence.dart';
import 'package:akshara_erp/core/exams/exam_administration_store.dart';
import 'package:akshara_erp/core/repositories/mock/mock_exam_administration_repository.dart';
import 'package:akshara_erp/core/repositories/repository_query.dart';
import 'package:akshara_erp/core/exams/exam_administration_requests.dart';
import 'package:akshara_erp/features/education/education_models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// P0-EXAM-004 — restart-safe exam lifecycle via repository + persistence.
void main() {
  const query = RepositoryQuery.demo;

  group('Exam persistence restart integration', () {
    test('repository writes survive simulated app restart', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final store = ExamAdministrationStore.instance;
      store.reset();
      store.attachPersistence(ExamAdministrationPersistence(prefs));

      final repo = MockExamAdministrationRepository(store: store);
      final created = await repo.createExam(
        query: query,
        request: const CreateExamAdministrationRequest(
          title: 'Restart Test Mathematics',
          subject: 'Mathematics',
          grade: '8',
          section: 'C',
          termLabel: 'Term 2',
          dateLabel: '22 Jun 2026',
          timeLabel: '10:00 AM',
          venueLabel: 'Room 8C',
          syllabusLabel: 'Geometry',
          maxMarks: 40,
          examType: EduExamType.unitTest,
        ),
      );
      await repo.scheduleExam(query: query, examId: created.id);
      await repo.openMarksEntry(query: query, examId: created.id);
      final marks = await repo.listMarks(query: query, examId: created.id);
      for (final mark in marks) {
        await repo.updateMark(
          query: query,
          request: UpdateExamMarkRequest(
            markEntryId: mark.id,
            marksObtained: 32,
          ),
        );
      }
      await repo.processResults(query: query, examId: created.id);
      store.markCoordinatorVerified(created.id, verifiedBy: 'Coordinator');

      final reloadedStore = ExamAdministrationStore.instance;
      reloadedStore.reset(clearPersistence: false);
      reloadedStore.attachPersistence(ExamAdministrationPersistence(prefs));
      final reloadedRepo = MockExamAdministrationRepository(store: reloadedStore);

      final exam = await reloadedRepo.getExam(query: query, examId: created.id);
      expect(exam?.phase, ExamLifecyclePhase.processed);
      expect(reloadedStore.isCoordinatorVerified(created.id), isTrue);
      final reloadedMarks =
          await reloadedRepo.listMarks(query: query, examId: created.id);
      expect(reloadedMarks.every((m) => m.marksObtained == 32), isTrue);
    });
  });
}
