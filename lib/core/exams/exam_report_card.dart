import '../repositories/mock/mock_canonical_student_registry.dart';
import 'exam_administration_store.dart';
import 'exam_grading.dart';
import 'exam_remark.dart';

/// One subject line on a report card.
class ReportCardSubjectLine {
  const ReportCardSubjectLine({
    required this.subject,
    required this.examTitle,
    required this.score,
    required this.maxScore,
    required this.grade,
    this.status = ExamMarkStatus.present,
  });

  final String subject;
  final String examTitle;
  final int score;
  final int maxScore;
  final String grade;

  /// EXM-D6 — attendance status. A non-present subject line shows a display code
  /// (AB/ML/DB) instead of marks and is EXCLUDED from totals, average and rank.
  final ExamMarkStatus status;

  /// Whether this line counts toward the report-card total/average.
  bool get countsTowardStats => status.isPresent;

  /// Display code (AB/ML/DB) for a non-present line, else null.
  String? get statusCode => status.displayCode;

  int get percent =>
      maxScore == 0 ? 0 : ((score / maxScore) * 100).round();
}

/// Per-student, per-term report card built from published exam results.
///
/// Rank is **always computed** (class position by term total %), but
/// [rankShown] reflects the school's `showRankToParents` setting — the UI must
/// only surface [rank] to parents/students when [rankShown] is true.
class ExamReportCard {
  const ExamReportCard({
    required this.sisStudentId,
    required this.studentName,
    required this.classLabel,
    required this.termLabel,
    required this.subjects,
    required this.totalScore,
    required this.totalMax,
    required this.overallGrade,
    required this.rank,
    required this.classSize,
    required this.rankShown,
    this.attendancePercent,
    this.remark,
    this.remarkAuthorName,
    this.remarkAuthorRole,
    this.leadershipRemark,
    this.leadershipRemarkAuthorName,
    this.leadershipRemarkAuthorRole,
  });

  final String sisStudentId;
  final String studentName;
  final String classLabel;
  final String termLabel;
  final List<ReportCardSubjectLine> subjects;
  final int totalScore;
  final int totalMax;
  final String overallGrade;

  /// 1-based class rank by term total percentage (computed from PRESENT results
  /// only). EXM-D6 — 0 when the student is NOT ranked (no present results this
  /// term, e.g. fully absent); see [isRanked].
  final int rank;

  /// Whether this student is ranked this term (has at least one present result).
  bool get isRanked => rank > 0;

  /// Number of ranked classmates (present-result holders) this term.
  final int classSize;

  /// Whether [rank] may be shown to parents/students (per school setting).
  final bool rankShown;

  /// Term attendance %, supplied by the caller (kept out of core to avoid
  /// coupling the exam engine to the attendance domain). Null when unavailable.
  final int? attendancePercent;

  /// Class-teacher remark for this report card (from the term's exam session).
  final String? remark;
  final String? remarkAuthorName;
  final ExamRemarkAuthorRole? remarkAuthorRole;

  /// Leadership (principal / vice-principal) remark — a separate slot from the
  /// class-teacher remark, so a report card may carry both.
  final String? leadershipRemark;
  final String? leadershipRemarkAuthorName;
  final ExamRemarkAuthorRole? leadershipRemarkAuthorRole;

  int get overallPercent =>
      totalMax == 0 ? 0 : ((totalScore / totalMax) * 100).round();
}

/// PRA-P0-06 / PRA-P1-32 (S4) — one PUBLISHED subject result as delivered by the
/// server-backed exams feed (`getExams`). Feeds
/// [ExamReportCardBuilder.fromPublishedResults] so the parent & student report
/// cards can be built from the same server-backed published-results source the
/// exams screen already uses, instead of a local in-memory store.
class PublishedResultLine {
  const PublishedResultLine({
    required this.subject,
    required this.examTitle,
    required this.termLabel,
    required this.score,
    required this.maxScore,
    required this.grade,
  });

  final String subject;
  final String examTitle;
  final String termLabel;
  final int score;
  final int maxScore;
  final String grade;
}

/// Builds [ExamReportCard]s from the published results in the store.
abstract final class ExamReportCardBuilder {
  /// PRA-P0-06 / PRA-P1-32 (S4) — builds a report card straight from a student's
  /// PUBLISHED exam results as returned by the SERVER-BACKED exams feed
  /// (`getExams`), so the parent & student report-card providers read the SAME
  /// published-results source the exams screen uses instead of a local
  /// in-memory [ExamAdministrationStore] scoped to a hardcoded student id.
  ///
  /// The exams feed carries per-subject marks + grade only; it does NOT carry the
  /// school grading scale, class rank, or teacher/leadership remarks, so those are
  /// omitted here (rank hidden, no remarks) and the OVERALL grade is derived from
  /// the server-supplied percentage using the standard scale. Returns null when
  /// there are no published results (report card not yet available), preserving
  /// the prior "null until published" contract. Results are scoped to the most
  /// recently published [termLabel] (mirrors [build]).
  static ExamReportCard? fromPublishedResults({
    required String studentName,
    required String classLabel,
    required List<PublishedResultLine> results,
    String sisStudentId = '',
    int? attendancePercent,
  }) {
    if (results.isEmpty) return null;
    final term = results.last.termLabel;
    final mine = results.where((r) => r.termLabel == term).toList();
    if (mine.isEmpty) return null;

    final subjects = [
      for (final r in mine)
        ReportCardSubjectLine(
          subject: r.subject,
          examTitle: r.examTitle,
          score: r.score,
          maxScore: r.maxScore,
          grade: r.grade,
        ),
    ];
    final totalScore = mine.fold<int>(0, (sum, r) => sum + r.score);
    final totalMax = mine.fold<int>(0, (sum, r) => sum + r.maxScore);
    final overallPercent = totalMax == 0 ? 0.0 : (totalScore / totalMax) * 100.0;

    return ExamReportCard(
      sisStudentId: sisStudentId,
      studentName: studentName,
      classLabel: classLabel,
      termLabel: term,
      subjects: subjects,
      totalScore: totalScore,
      totalMax: totalMax,
      overallGrade:
          totalMax == 0 ? '' : ExamGradingScale.standard.gradeFor(overallPercent),
      // Rank and remarks are not carried by the exams feed — hidden, not faked.
      rank: 0,
      classSize: 0,
      rankShown: false,
      attendancePercent: attendancePercent,
    );
  }

  /// Returns the report card for [sisStudentId] in [termLabel], or null when the
  /// student has no published results for that term.
  static ExamReportCard? build(
    ExamAdministrationStore store, {
    required String sisStudentId,
    required String termLabel,
    int? attendancePercent,
  }) {
    final mine = store
        .resultsForStudent(sisStudentId)
        .where((r) => r.termLabel == termLabel)
        .toList();
    if (mine.isEmpty) return null;

    final student = MockCanonicalStudentRegistry.byId(sisStudentId);
    final classLabel = student?.classLabel ?? '';
    final studentName =
        student?.studentName ?? mine.first.studentName;
    final settings = store.reportSettings;

    final subjects = [
      for (final r in mine)
        ReportCardSubjectLine(
          subject: r.subject,
          examTitle: r.examTitle,
          score: r.scoreObtained,
          maxScore: r.maxScore,
          grade: r.grade,
          status: r.status,
        ),
    ];
    // EXM-D6 — totals, average, percent and overall grade come from PRESENT
    // subjects only. A non-present line (AB/ML/DB) is shown on the card but
    // excluded from every statistic.
    final counted = mine.where((r) => r.countsTowardStats).toList();
    final totalScore = counted.fold<int>(0, (sum, r) => sum + r.scoreObtained);
    final totalMax = counted.fold<int>(0, (sum, r) => sum + r.maxScore);
    final overallPercent =
        totalMax == 0 ? 0.0 : (totalScore / totalMax) * 100.0;
    final overallGrade = settings.gradingScale.gradeFor(overallPercent);

    final (rank, classSize) =
        _classRank(store, sisStudentId, classLabel, termLabel, overallPercent);

    // Remarks for this report card: the most recently updated remark in each
    // slot across the term's exam sessions. The class-teacher and leadership
    // (principal/VP) slots are tracked independently so both can be shown.
    ExamRemark? termRemark;
    ExamRemark? leadershipRemark;
    for (final r in mine) {
      final teacherRem = store.remarkFor(r.examId, sisStudentId);
      if (teacherRem != null &&
          (termRemark == null ||
              teacherRem.updatedAt.compareTo(termRemark.updatedAt) > 0)) {
        termRemark = teacherRem;
      }
      final leadRem = store.remarkFor(r.examId, sisStudentId, leadership: true);
      if (leadRem != null &&
          (leadershipRemark == null ||
              leadRem.updatedAt.compareTo(leadershipRemark.updatedAt) > 0)) {
        leadershipRemark = leadRem;
      }
    }

    return ExamReportCard(
      sisStudentId: sisStudentId,
      studentName: studentName,
      classLabel: classLabel,
      termLabel: termLabel,
      subjects: subjects,
      totalScore: totalScore,
      totalMax: totalMax,
      overallGrade: overallGrade,
      rank: rank,
      classSize: classSize,
      rankShown: settings.showRankToParents,
      attendancePercent: attendancePercent,
      remark: termRemark?.text,
      remarkAuthorName: termRemark?.authorName,
      remarkAuthorRole: termRemark?.authorRole,
      leadershipRemark: leadershipRemark?.text,
      leadershipRemarkAuthorName: leadershipRemark?.authorName,
      leadershipRemarkAuthorRole: leadershipRemark?.authorRole,
    );
  }

  /// 1-based rank within the student's class by term total %, plus the ranked
  /// class size.
  ///
  /// EXM-D6 — a non-present result (AB/ML/DB) is excluded from a student's
  /// total, and a student with NO present results this term is NOT ranked (not in
  /// the pool at all), so absent students never shift another student's rank.
  static (int, int) _classRank(
    ExamAdministrationStore store,
    String sisStudentId,
    String classLabel,
    String termLabel,
    double myPercent,
  ) {
    final scoreByStudent = <String, int>{};
    final maxByStudent = <String, int>{};
    for (final r in store.allPublishedResults()) {
      if (r.termLabel != termLabel) continue;
      // Skip non-present results — they contribute nothing to any student's
      // ranked total.
      if (!r.countsTowardStats) continue;
      final s = MockCanonicalStudentRegistry.byId(r.sisStudentId);
      if ((s?.classLabel ?? '') != classLabel) continue;
      scoreByStudent[r.sisStudentId] =
          (scoreByStudent[r.sisStudentId] ?? 0) + r.scoreObtained;
      maxByStudent[r.sisStudentId] =
          (maxByStudent[r.sisStudentId] ?? 0) + r.maxScore;
    }

    if (scoreByStudent.isEmpty) return (1, 1);

    final percents = <String, double>{
      for (final id in scoreByStudent.keys)
        id: (maxByStudent[id] ?? 0) == 0
            ? 0.0
            : (scoreByStudent[id]! / maxByStudent[id]!) * 100.0,
    };

    // A fully-absent student (no present results this term) is not ranked:
    // report rank 0, and don't count them in the ranked class size.
    if (!percents.containsKey(sisStudentId)) {
      return (0, percents.length);
    }

    final myPct = percents[sisStudentId] ?? myPercent;
    // Rank = 1 + number of classmates strictly ahead (ties share the better rank).
    final ahead =
        percents.values.where((p) => p > myPct + 1e-9).length;
    return (ahead + 1, percents.length);
  }
}
