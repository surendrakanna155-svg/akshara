import '../../exams/exam_administration_requests.dart';
import '../../exams/exam_administration_store.dart';
import '../../exams/exam_remark.dart';
import '../repository_query.dart';

/// Persistence contract for ERP exam administration (scheduling → publish).
abstract class ExamAdministrationRepository {
  Future<List<ExamSession>> listExams({required RepositoryQuery query});

  Future<ExamSession?> getExam({
    required RepositoryQuery query,
    required String examId,
  });

  Future<ExamSession> createExam({
    required RepositoryQuery query,
    required CreateExamAdministrationRequest request,
  });

  Future<ExamSession> scheduleExam({
    required RepositoryQuery query,
    required String examId,
  });

  Future<ExamSession> openMarksEntry({
    required RepositoryQuery query,
    required String examId,
  });

  Future<ExamSession> processResults({
    required RepositoryQuery query,
    required String examId,
  });

  Future<void> verifyCoordinatorResults({
    required RepositoryQuery query,
    required String examId,
    required String verifiedBy,
  });

  Future<int> publishResults({
    required RepositoryQuery query,
    required String examId,
  });

  Future<List<ExamMarkRecord>> listMarks({
    required RepositoryQuery query,
    required String examId,
  });

  Future<ExamMarkRecord> updateMark({
    required RepositoryQuery query,
    required UpdateExamMarkRequest request,
  });

  Future<List<PublishedExamResult>> listPublishedResultsForStudent({
    required RepositoryQuery query,
    required String sisStudentId,
  });

  /// Creates or edits a (student, exam) remark and persists it to the backend
  /// (class-teacher and leadership remarks are independent slots). Returns the
  /// canonical stored remark (with its appended audit trail).
  Future<ExamRemark> upsertRemark({
    required RepositoryQuery query,
    required String examId,
    required String sisStudentId,
    required String text,
    required String authorName,
    required ExamRemarkAuthorRole authorRole,
  });

  /// Lists all remarks (both slots) for an exam so the local store can be
  /// hydrated from the backend.
  Future<List<ExamRemark>> listRemarks({
    required RepositoryQuery query,
    required String examId,
  });
}
