import '../../exams/exam_administration_requests.dart';
import '../../exams/exam_administration_store.dart';
import '../../exams/exam_remark.dart';
import '../../exams/exam_reports.dart';
import '../interfaces/exam_administration_repository.dart';
import '../repository_query.dart';

/// Mock implementation delegating to [ExamAdministrationStore].
class MockExamAdministrationRepository implements ExamAdministrationRepository {
  MockExamAdministrationRepository({ExamAdministrationStore? store})
      : _store = store ?? ExamAdministrationStore.instance;

  final ExamAdministrationStore _store;

  @override
  Future<List<ExamSession>> listExams({required RepositoryQuery query}) async {
    return _store.allExams().map(_enrichSession).toList(growable: false);
  }

  @override
  Future<ExamSession?> getExam({
    required RepositoryQuery query,
    required String examId,
  }) async {
    final exam = _store.examById(examId);
    return exam == null ? null : _enrichSession(exam);
  }

  ExamSession _enrichSession(ExamSession exam) {
    return exam.copyWith(
      coordinatorVerified: _store.isCoordinatorVerified(exam.id),
      rejectionComment: _store.rejectionCommentFor(exam.id),
    );
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
      marksEntryDeadline: request.marksEntryDeadline,
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
      status: request.status,
    );
  }

  @override
  Future<BulkExamMarkSaveResult> bulkUpdateMarks({
    required RepositoryQuery query,
    required BulkUpdateExamMarksRequest request,
  }) async {
    final exam = _store.examById(request.examId);
    return _store.recordMarksBulk(
      entries: request.entries,
      maxMarks: exam?.maxMarks,
    );
  }

  @override
  Future<List<MarksEntryProgress>> listMarksEntryProgress({
    required RepositoryQuery query,
  }) async {
    return _store.marksEntryProgress();
  }

  @override
  Future<int> remindPendingMarks({required RepositoryQuery query}) async {
    // EXM-6: overdue = deadline in the past AND marks still pending (mirrors
    // the backend `listOverdueMarksEntry` filter). No money/side effect here.
    final now = DateTime.now();
    return _store.marksEntryProgress().where((p) {
      final deadline = p.marksEntryDeadline;
      return deadline != null && p.pending > 0 && deadline.isBefore(now);
    }).length;
  }

  @override
  Future<List<PublishedExamResult>> listPublishedResultsForStudent({
    required RepositoryQuery query,
    required String sisStudentId,
  }) async {
    return _store.resultsForStudent(sisStudentId);
  }

  @override
  Future<ExamRemark> upsertRemark({
    required RepositoryQuery query,
    required String examId,
    required String sisStudentId,
    required String text,
    required String authorName,
    required ExamRemarkAuthorRole authorRole,
  }) async {
    return _store.upsertRemark(
      examId: examId,
      sisStudentId: sisStudentId,
      text: text,
      authorId: authorName,
      authorName: authorName,
      authorRole: authorRole,
    );
  }

  @override
  Future<List<ExamRemark>> listRemarks({
    required RepositoryQuery query,
    required String examId,
  }) async {
    return _store.remarksForExam(examId);
  }

  @override
  Future<TabulationRegister> tabulation({
    required RepositoryQuery query,
    required String classLabel,
    required String term,
  }) async {
    return ExamReportsBuilder.tabulation(
      _store,
      classLabel: classLabel,
      term: term,
    );
  }

  @override
  Future<List<ExamTopper>> examToppers({
    required RepositoryQuery query,
    required String examId,
    int limit = 5,
  }) async {
    return ExamReportsBuilder.toppers(_store, examId: examId, limit: limit);
  }

  @override
  Future<List<MeritEntry>> meritList({
    required RepositoryQuery query,
    required String classLabel,
    required String term,
  }) async {
    return ExamReportsBuilder.merit(_store, classLabel: classLabel, term: term);
  }

  @override
  Future<ExamGradeDistribution> examDistribution({
    required RepositoryQuery query,
    required String examId,
  }) async {
    return ExamReportsBuilder.distribution(_store, examId: examId);
  }

  @override
  Future<List<DatesheetRow>> datesheet({
    required RepositoryQuery query,
    required String classLabel,
    required String term,
  }) async {
    return ExamReportsBuilder.datesheet(
      _store,
      classLabel: classLabel,
      term: term,
    );
  }

  // ── EXM-D1/D2/D4/D5 — final exams slice ────────────────────────────────────

  @override
  Future<List<ReportCardData>> reportCards({
    required RepositoryQuery query,
    required String classLabel,
    required String term,
  }) async {
    return _store.reportCards(classLabel: classLabel, term: term);
  }

  @override
  Future<GraceMarkResult> recordGraceMark({
    required RepositoryQuery query,
    required String examId,
    required String sisStudentId,
    required int delta,
    required String reason,
  }) async {
    return _store.recordGraceAdjustment(
      examId: examId,
      sisStudentId: sisStudentId,
      delta: delta,
      reason: reason,
    );
  }

  @override
  Future<List<ExamMarkAdjustment>> listAdjustments({
    required RepositoryQuery query,
    required String examId,
  }) async {
    return _store.adjustmentsForExam(examId);
  }

  @override
  Future<List<HallTicket>> hallTickets({
    required RepositoryQuery query,
    required String examId,
  }) async {
    return _store.hallTickets(examId);
  }

  @override
  Future<SeatingPlan> generateSeating({
    required RepositoryQuery query,
    required String examId,
    int capacity = kDefaultSeatingRoomCapacity,
  }) async {
    return _store.generateSeating(examId, capacity: capacity);
  }

  @override
  Future<SeatingPlan> seating({
    required RepositoryQuery query,
    required String examId,
  }) async {
    return _store.seatingFor(examId);
  }
}
