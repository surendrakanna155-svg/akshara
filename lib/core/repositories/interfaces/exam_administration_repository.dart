import '../../exams/exam_administration_requests.dart';
import '../../exams/exam_administration_store.dart';
import '../../exams/exam_remark.dart';
import '../../exams/exam_reports.dart';
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

  /// EXM-1 — fast bulk marks save for one exam. Applied per row (published rows
  /// skipped + reported, never overwritten); partial success. Returns the
  /// persisted rows and the per-row failures.
  Future<BulkExamMarkSaveResult> bulkUpdateMarks({
    required RepositoryQuery query,
    required BulkUpdateExamMarksRequest request,
  });

  /// EXM-2 — marks-entry progress board: one row per exam currently in the
  /// marks_entry phase with entered/total counts, so a coordinator sees who
  /// still owes marks before processing/publishing.
  Future<List<MarksEntryProgress>> listMarksEntryProgress({
    required RepositoryQuery query,
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

  // ── EXM-3/4/5/7 — read-only exam reports (all gated on viewExams) ─────────
  // 🔴 Non-present (AB/ML/DB) rows are EXCLUDED from every statistic and only
  // ever displayed via their status code — enforced in the backend queries and
  // in ExamReportsBuilder for the mock.

  /// EXM-3 — tabulation register: students × subjects grid for [classLabel] over
  /// [term] (per-student total, percent, present-only rank).
  Future<TabulationRegister> tabulation({
    required RepositoryQuery query,
    required String classLabel,
    required String term,
  });

  /// EXM-4a — top-[limit] students by marks for one exam (present rows only).
  Future<List<ExamTopper>> examToppers({
    required RepositoryQuery query,
    required String examId,
    int limit,
  });

  /// EXM-4b — merit list for [classLabel] over [term] (ranked by term total %,
  /// present-only).
  Future<List<MeritEntry>> meritList({
    required RepositoryQuery query,
    required String classLabel,
    required String term,
  });

  /// EXM-5 — pass/fail split + grade distribution for one exam (present-only).
  Future<ExamGradeDistribution> examDistribution({
    required RepositoryQuery query,
    required String examId,
  });

  /// EXM-7 — datesheet (exam schedule) for [classLabel] over [term].
  Future<List<DatesheetRow>> datesheet({
    required RepositoryQuery query,
    required String classLabel,
    required String term,
  });

  // ── EXM-D1/D2/D4/D5 — final exams slice ───────────────────────────────────

  /// EXM-D1 — batch report-card data for [classLabel] over [term] (published
  /// results only). One card per student; the client renders/prints the bundle.
  Future<List<ReportCardData>> reportCards({
    required RepositoryQuery query,
    required String classLabel,
    required String term,
  });

  /// EXM-D2 — records a grace / moderation adjustment (a signed [delta] with a
  /// mandatory [reason]) for one (exam, student). The ORIGINAL mark is preserved;
  /// returns the record + the resulting effective mark. Coordinator-only; allowed
  /// only before publish.
  Future<GraceMarkResult> recordGraceMark({
    required RepositoryQuery query,
    required String examId,
    required String sisStudentId,
    required int delta,
    required String reason,
  });

  /// EXM-D2 — the grace / moderation breakdown for an exam (coordinator-only —
  /// NEVER shown to parents/students).
  Future<List<ExamMarkAdjustment>> listAdjustments({
    required RepositoryQuery query,
    required String examId,
  });

  /// EXM-D4 — per-student hall tickets (admit cards) for one exam.
  Future<List<HallTicket>> hallTickets({
    required RepositoryQuery query,
    required String examId,
  });

  /// EXM-D5 — (re)generates the seating plan for an exam (mixed-class default;
  /// configurable room [capacity]). Returns the generated plan.
  Future<SeatingPlan> generateSeating({
    required RepositoryQuery query,
    required String examId,
    int capacity,
  });

  /// EXM-D5 — the current seating plan for an exam (grouped by room).
  Future<SeatingPlan> seating({
    required RepositoryQuery query,
    required String examId,
  });
}
