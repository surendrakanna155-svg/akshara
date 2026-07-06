import '../../../exams/exam_administration_requests.dart';
import '../../../exams/exam_administration_store.dart';
import '../../../exams/exam_remark.dart';
import '../../../exams/exam_reports.dart';
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
  Future<BulkExamMarkSaveResult> bulkUpdateMarks({
    required RepositoryQuery query,
    required BulkUpdateExamMarksRequest request,
  }) =>
      _remote.bulkUpdateMarks(query: query, request: request);

  @override
  Future<List<MarksEntryProgress>> listMarksEntryProgress({
    required RepositoryQuery query,
  }) =>
      _remote.fetchMarksEntryProgress(query: query);

  @override
  Future<int> remindPendingMarks({required RepositoryQuery query}) =>
      _remote.remindPendingMarks(query: query);

  @override
  Future<List<PublishedExamResult>> listPublishedResultsForStudent({
    required RepositoryQuery query,
    required String sisStudentId,
  }) =>
      _remote.fetchPublishedResultsForStudent(
        query: query,
        sisStudentId: sisStudentId,
      );

  @override
  Future<ExamRemark> upsertRemark({
    required RepositoryQuery query,
    required String examId,
    required String sisStudentId,
    required String text,
    required String authorName,
    required ExamRemarkAuthorRole authorRole,
  }) =>
      _remote.upsertRemark(
        query: query,
        examId: examId,
        sisStudentId: sisStudentId,
        text: text,
        authorName: authorName,
        authorRole: authorRole,
      );

  @override
  Future<List<ExamRemark>> listRemarks({
    required RepositoryQuery query,
    required String examId,
  }) =>
      _remote.fetchRemarks(query: query, examId: examId);

  @override
  Future<TabulationRegister> tabulation({
    required RepositoryQuery query,
    required String classLabel,
    required String term,
  }) =>
      _remote.fetchTabulation(
        query: query,
        classLabel: classLabel,
        term: term,
      );

  @override
  Future<List<ExamTopper>> examToppers({
    required RepositoryQuery query,
    required String examId,
    int limit = 5,
  }) =>
      _remote.fetchToppers(query: query, examId: examId, limit: limit);

  @override
  Future<List<MeritEntry>> meritList({
    required RepositoryQuery query,
    required String classLabel,
    required String term,
  }) =>
      _remote.fetchMerit(query: query, classLabel: classLabel, term: term);

  @override
  Future<ExamGradeDistribution> examDistribution({
    required RepositoryQuery query,
    required String examId,
  }) =>
      _remote.fetchDistribution(query: query, examId: examId);

  @override
  Future<List<DatesheetRow>> datesheet({
    required RepositoryQuery query,
    required String classLabel,
    required String term,
  }) =>
      _remote.fetchDatesheet(query: query, classLabel: classLabel, term: term);

  // ── EXM-D1/D2/D4/D5 — final exams slice ────────────────────────────────────

  @override
  Future<List<ReportCardData>> reportCards({
    required RepositoryQuery query,
    required String classLabel,
    required String term,
  }) =>
      _remote.fetchReportCards(
        query: query,
        classLabel: classLabel,
        term: term,
      );

  @override
  Future<GraceMarkResult> recordGraceMark({
    required RepositoryQuery query,
    required String examId,
    required String sisStudentId,
    required int delta,
    required String reason,
  }) =>
      _remote.recordGraceMark(
        query: query,
        examId: examId,
        sisStudentId: sisStudentId,
        delta: delta,
        reason: reason,
      );

  @override
  Future<List<ExamMarkAdjustment>> listAdjustments({
    required RepositoryQuery query,
    required String examId,
  }) =>
      _remote.fetchAdjustments(query: query, examId: examId);

  @override
  Future<List<HallTicket>> hallTickets({
    required RepositoryQuery query,
    required String examId,
  }) =>
      _remote.fetchHallTickets(query: query, examId: examId);

  @override
  Future<SeatingPlan> generateSeating({
    required RepositoryQuery query,
    required String examId,
    int capacity = kDefaultSeatingRoomCapacity,
  }) =>
      _remote.generateSeating(
        query: query,
        examId: examId,
        capacity: capacity,
      );

  @override
  Future<SeatingPlan> seating({
    required RepositoryQuery query,
    required String examId,
  }) =>
      _remote.fetchSeating(query: query, examId: examId);
}
