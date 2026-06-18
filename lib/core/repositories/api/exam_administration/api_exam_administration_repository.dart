import '../../../exams/exam_administration_requests.dart';
import '../../../exams/exam_administration_store.dart';
import '../api_exception.dart';
import '../../interfaces/exam_administration_repository.dart';
import '../../repository_query.dart';

/// API stub — throws until backend exam administration endpoints ship.
class ApiExamAdministrationRepository implements ExamAdministrationRepository {
  Never _notConnected(String method) {
    throw ApiNotConnectedException('ExamAdministrationRepository', method);
  }

  @override
  Future<List<ExamSession>> listExams({required RepositoryQuery query}) =>
      _notConnected('listExams');

  @override
  Future<ExamSession?> getExam({
    required RepositoryQuery query,
    required String examId,
  }) =>
      _notConnected('getExam');

  @override
  Future<ExamSession> createExam({
    required RepositoryQuery query,
    required CreateExamAdministrationRequest request,
  }) =>
      _notConnected('createExam');

  @override
  Future<ExamSession> scheduleExam({
    required RepositoryQuery query,
    required String examId,
  }) =>
      _notConnected('scheduleExam');

  @override
  Future<ExamSession> openMarksEntry({
    required RepositoryQuery query,
    required String examId,
  }) =>
      _notConnected('openMarksEntry');

  @override
  Future<ExamSession> processResults({
    required RepositoryQuery query,
    required String examId,
  }) =>
      _notConnected('processResults');

  @override
  Future<void> verifyCoordinatorResults({
    required RepositoryQuery query,
    required String examId,
    required String verifiedBy,
  }) =>
      _notConnected('verifyCoordinatorResults');

  @override
  Future<int> publishResults({
    required RepositoryQuery query,
    required String examId,
  }) =>
      _notConnected('publishResults');

  @override
  Future<List<ExamMarkRecord>> listMarks({
    required RepositoryQuery query,
    required String examId,
  }) =>
      _notConnected('listMarks');

  @override
  Future<ExamMarkRecord> updateMark({
    required RepositoryQuery query,
    required UpdateExamMarkRequest request,
  }) =>
      _notConnected('updateMark');

  @override
  Future<List<PublishedExamResult>> listPublishedResultsForStudent({
    required RepositoryQuery query,
    required String sisStudentId,
  }) =>
      _notConnected('listPublishedResultsForStudent');
}
