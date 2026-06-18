import '../../exams/exam_administration_requests.dart';
import '../../exams/exam_administration_store.dart';
import '../interfaces/exam_administration_repository.dart';
import '../repository_query.dart';

/// Mock implementation delegating to [ExamAdministrationStore].
class MockExamAdministrationRepository implements ExamAdministrationRepository {
  MockExamAdministrationRepository({ExamAdministrationStore? store})
      : _store = store ?? ExamAdministrationStore.instance;

  final ExamAdministrationStore _store;

  @override
  Future<List<ExamSession>> listExams({required RepositoryQuery query}) async {
    return _store.allExams();
  }

  @override
  Future<ExamSession?> getExam({
    required RepositoryQuery query,
    required String examId,
  }) async {
    return _store.examById(examId);
  }

  @override
  Future<ExamSession> createExam({
    required RepositoryQuery query,
    required CreateExamAdministrationRequest request,
  }) async {
    return _store.createExam(
      title: request.title,
      subject: request.subject,
      grade: request.grade,
      section: request.section,
      termLabel: request.termLabel,
      dateLabel: request.dateLabel,
      timeLabel: request.timeLabel,
      venueLabel: request.venueLabel,
      syllabusLabel: request.syllabusLabel,
      maxMarks: request.maxMarks,
      examType: request.examType,
    );
  }

  @override
  Future<ExamSession> scheduleExam({
    required RepositoryQuery query,
    required String examId,
  }) async {
    return _store.scheduleExam(examId);
  }

  @override
  Future<ExamSession> openMarksEntry({
    required RepositoryQuery query,
    required String examId,
  }) async {
    return _store.openMarksEntry(examId);
  }

  @override
  Future<ExamSession> processResults({
    required RepositoryQuery query,
    required String examId,
  }) async {
    return _store.processResults(examId);
  }

  @override
  Future<void> verifyCoordinatorResults({
    required RepositoryQuery query,
    required String examId,
    required String verifiedBy,
  }) async {
    _store.markCoordinatorVerified(examId, verifiedBy: verifiedBy);
  }

  @override
  Future<int> publishResults({
    required RepositoryQuery query,
    required String examId,
  }) async {
    return _store.publishExamResults(examId);
  }

  @override
  Future<List<ExamMarkRecord>> listMarks({
    required RepositoryQuery query,
    required String examId,
  }) async {
    return _store.marksForExam(examId);
  }

  @override
  Future<ExamMarkRecord> updateMark({
    required RepositoryQuery query,
    required UpdateExamMarkRequest request,
  }) async {
    return _store.recordMark(
      markEntryId: request.markEntryId,
      marksObtained: request.marksObtained,
    );
  }

  @override
  Future<List<PublishedExamResult>> listPublishedResultsForStudent({
    required RepositoryQuery query,
    required String sisStudentId,
  }) async {
    return _store.resultsForStudent(sisStudentId);
  }
}
