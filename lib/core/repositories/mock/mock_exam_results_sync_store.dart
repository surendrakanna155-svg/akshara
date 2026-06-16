import '../../exams/exam_administration_store.dart';

export '../../exams/exam_administration_store.dart' show PublishedExamResult;

/// Backward-compatible facade over [ExamAdministrationStore].
@Deprecated('Use ExamAdministrationStore.instance directly')
final class MockExamResultsSyncStore {
  MockExamResultsSyncStore._();

  static final MockExamResultsSyncStore instance = MockExamResultsSyncStore._();

  ExamAdministrationStore get _store => ExamAdministrationStore.instance;

  bool get hasPublishedResults => _store.hasPublishedResults;

  void publishMark({
    required String markEntryId,
    required String sisStudentId,
    required String studentName,
    required String examId,
    required String examTitle,
    required int scoreObtained,
    required int maxScore,
    String termLabel = 'Term 2',
    String dateLabel = '12 Jun 2026',
    String subject = 'Mathematics',
  }) {
    _store.ensureSeeded();
    final exam = _store.examById(examId);
    if (exam == null) {
      throw StateError('Exam not found: $examId');
    }
    var mark = _store.markById(markEntryId);
    if (mark == null) {
      _store.openMarksEntry(examId);
      mark = _store.markById(markEntryId);
    }
    if (mark != null) {
      _store.recordMark(markEntryId: markEntryId, marksObtained: scoreObtained);
    }
    _store.publishExamResults(examId);
  }

  List<PublishedExamResult> resultsForStudent(String sisStudentId) =>
      _store.resultsForStudent(sisStudentId);

  PublishedExamResult? resultForMarkEntry(String markEntryId) =>
      _store.resultForMarkEntry(markEntryId);

  void reset() => _store.reset();
}
