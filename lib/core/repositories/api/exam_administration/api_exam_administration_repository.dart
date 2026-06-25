import '../../../exams/exam_administration_requests.dart';
import '../../../exams/exam_administration_store.dart';
import '../../interfaces/exam_administration_repository.dart';
import '../../repository_query.dart';
import 'remote/exam_remote_datasource.dart';

/// API implementation of [ExamAdministrationRepository] — enabled via [examApiEnabledProvider].
class ApiExamAdministrationRepository implements ExamAdministrationRepository {
  ApiExamAdministrationRepository({
    required ExamRemoteDataSource remote,
  }) : _remote = remote;

  final ExamRemoteDataSource _remote;

  @override
  Future<List<ExamSession>> listExams({required RepositoryQuery query}) =>
      _remote.fetchExams(query: query);

  @override
  Future<ExamSession?> getExam({
    required RepositoryQuery query,
    required String examId,
  }) =>
      _remote.fetchExam(query: query, examId: examId);

  @override
  Future<ExamSession> createExam({
    required RepositoryQuery query,
    required CreateExamAdministrationRequest request,
  }) =>
      _remote.createExam(query: query, request: request);

  @override
  Future<ExamSession> scheduleExam({
    required RepositoryQuery query,
    required String examId,
  }) =>
      _remote.scheduleExam(query: query, examId: examId);

  @override
  Future<ExamSession> openMarksEntry({
    required RepositoryQuery query,
    required String examId,
  }) =>
      _remote.openMarksEntry(query: query, examId: examId);

  @override
  Future<ExamSession> processResults({
    required RepositoryQuery query,
    required String examId,
  }) =>
      _remote.processResults(query: query, examId: examId);

  @override
  Future<void> verifyCoordinatorResults({
    required RepositoryQuery query,
    required String examId,
    required String verifiedBy,
  }) async {
    await _remote.verifyCoordinatorResults(
      query: query,
      examId: examId,
      verifiedBy: verifiedBy,
    );
  }

  @override
  Future<int> publishResults({
    required RepositoryQuery query,
    required String examId,
  }) =>
      _remote.publishResults(
        query: query,
        examId: examId,
        requireApproval: false,
      );

  @override
  Future<List<ExamMarkRecord>> listMarks({
    required RepositoryQuery query,
    required String examId,
  }) =>
      _remote.fetchMarks(query: query, examId: examId);

  @override
  Future<ExamMarkRecord> updateMark({
    required RepositoryQuery query,
    required UpdateExamMarkRequest request,
  }) =>
      _remote.updateMark(query: query, request: request);

  @override
  Future<List<PublishedExamResult>> listPublishedResultsForStudent({
    required RepositoryQuery query,
    required String sisStudentId,
  }) =>
      _remote.fetchPublishedResultsForStudent(
        query: query,
        sisStudentId: sisStudentId,
      );
}
