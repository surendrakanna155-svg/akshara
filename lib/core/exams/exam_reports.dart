import 'exam_administration_store.dart';

/// EXM-3 / EXM-4 / EXM-5 / EXM-7 — read-only exam report models + the pure
/// computation that builds them.
///
/// 🔴 CRITICAL correctness rule (frozen): a result whose status is NOT
/// [ExamMarkStatus.present] (marks_obtained null; codes AB/ML/DB) is EXCLUDED
/// from every statistic — totals, averages, percent, ranking, pass/fail and the
/// grade distribution — and is only ever DISPLAYED via its status code, never
/// counted. This reuses the same semantics as
/// [PublishedExamResult.countsTowardStats] and the report-card
/// `_classRank`/`countsTowardStats` reference in exam_report_card.dart.

/// Default pass threshold (%) when no school setting exists (mirrors the
/// backend `DEFAULT_PASS_MARK_PERCENT`). See [ExamGradeDistribution.passMarkSource].
const int kDefaultPassMarkPercent = 40;

// ── EXM-3 — Tabulation register ──────────────────────────────────────────────

/// One subject cell for a student in the tabulation register. A non-present cell
/// carries [statusCode] (AB/ML/DB) and null [marks]; it never counts.
class TabulationCell {
  const TabulationCell({
    required this.subject,
    required this.marks,
    required this.maxMarks,
    required this.statusCode,
  });

  final String subject;

  /// Present marks, or null for a non-present (AB/ML/DB) cell.
  final int? marks;
  final int maxMarks;

  /// Display code (AB/ML/DB) for a non-present cell, else null.
  final String? statusCode;

  /// What the cell renders: the numeric mark for a present student, else the
  /// status code (AB/ML/DB), else an em-dash when there is no result at all.
  String get display => marks != null ? '$marks' : (statusCode ?? '—');
}

/// One student row in the tabulation register.
class TabulationStudentRow {
  const TabulationStudentRow({
    required this.studentId,
    required this.sisStudentId,
    required this.studentName,
    required this.rollNo,
    required this.cellsBySubject,
    required this.total,
    required this.totalMax,
    required this.percent,
    required this.rank,
  });

  final String studentId;
  final String sisStudentId;
  final String studentName;
  final String? rollNo;

  /// Per-subject cells keyed by subject name.
  final Map<String, TabulationCell> cellsBySubject;

  /// Total over PRESENT subjects only.
  final int total;
  final int totalMax;
  final double percent;

  /// 1-based rank by present-only total %, or null when NOT ranked (no present
  /// result this term — a fully-non-present student is not in the pool).
  final int? rank;
}

/// EXM-3 — students × subjects grid for a class over a term.
class TabulationRegister {
  const TabulationRegister({
    required this.classLabel,
    required this.term,
    required this.subjects,
    required this.students,
  });

  final String classLabel;
  final String term;

  /// Subject columns in a stable order.
  final List<String> subjects;
  final List<TabulationStudentRow> students;
}

// ── EXM-4 — Subject toppers + Merit list ─────────────────────────────────────

/// EXM-4a — a subject topper for one exam (present students only).
class ExamTopper {
  const ExamTopper({
    required this.sisStudentId,
    required this.studentName,
    required this.rollNo,
    required this.marks,
    required this.maxMarks,
    required this.percent,
    required this.rank,
  });

  final String sisStudentId;
  final String studentName;
  final String? rollNo;
  final int marks;
  final int maxMarks;
  final double percent;
  final int rank;
}

/// EXM-4b — a merit-list entry (ranked by term total %, present-only).
class MeritEntry {
  const MeritEntry({
    required this.sisStudentId,
    required this.studentName,
    required this.rollNo,
    required this.total,
    required this.totalMax,
    required this.percent,
    required this.rank,
  });

  final String sisStudentId;
  final String studentName;
  final String? rollNo;
  final int total;
  final int totalMax;
  final double percent;
  final int rank;
}

// ── EXM-5 — Pass/fail + grade distribution ───────────────────────────────────

/// One grade bucket in the distribution.
class GradeBucket {
  const GradeBucket({required this.grade, required this.count});
  final String grade;
  final int count;
}

/// EXM-5 — pass/fail split + grade-letter distribution for one exam, over PRESENT
/// rows only. Non-present rows are counted in [excludedCount] for transparency
/// but never in pass/fail or a grade bucket.
class ExamGradeDistribution {
  const ExamGradeDistribution({
    required this.examId,
    required this.passMarkPercent,
    required this.passMarkSource,
    required this.passCount,
    required this.failCount,
    required this.gradeBreakdown,
    required this.presentCount,
    required this.excludedCount,
  });

  final String examId;
  final int passMarkPercent;

  /// Where the pass threshold came from ('default' when no setting exists).
  final String passMarkSource;
  final int passCount;
  final int failCount;
  final List<GradeBucket> gradeBreakdown;

  /// Number of PRESENT rows the split was computed over.
  final int presentCount;

  /// Non-present rows excluded from every count (shown for context only).
  final int excludedCount;

  int get totalEvaluated => passCount + failCount;
  double get passRate => totalEvaluated == 0 ? 0 : passCount / totalEvaluated;
}

// ── EXM-7 — Datesheet ────────────────────────────────────────────────────────

/// EXM-7 — one scheduled exam row in a class's datesheet.
class DatesheetRow {
  const DatesheetRow({
    required this.examId,
    required this.subject,
    required this.dateLabel,
    required this.timeLabel,
    required this.venueLabel,
    required this.maxMarks,
  });

  final String examId;
  final String subject;
  final String dateLabel;
  final String timeLabel;
  final String venueLabel;
  final int maxMarks;
}

// ── Pure computation (used by the mock repository) ───────────────────────────

/// Builds the read-only reports from the [ExamAdministrationStore]'s published
/// results + sessions, applying the frozen present-only exclusion everywhere.
abstract final class ExamReportsBuilder {
  /// EXM-3 — tabulation register for [classLabel] over [term]. `classLabel` is
  /// `grade-section` (e.g. "8-A"); a bare grade matches all sections.
  static TabulationRegister tabulation(
    ExamAdministrationStore store, {
    required String classLabel,
    required String term,
  }) {
    final results = _classTermResults(store, classLabel, term);

    final subjects = <String>[];
    final byStudent = <String, _StudentAgg>{};
    for (final r in results) {
      if (!subjects.contains(r.subject)) subjects.add(r.subject);
      final agg = byStudent.putIfAbsent(
        r.sisStudentId,
        () => _StudentAgg(
          sisStudentId: r.sisStudentId,
          studentName: r.studentName,
        ),
      );
      final present = r.countsTowardStats;
      agg.cells[r.subject] = TabulationCell(
        subject: r.subject,
        marks: present ? r.scoreObtained : null,
        maxMarks: r.maxScore,
        statusCode: present ? null : r.statusCode,
      );
      // 🔴 EXCLUSION — only a present result contributes to totals.
      if (present) {
        agg.total += r.scoreObtained;
        agg.totalMax += r.maxScore;
      }
    }

    final aggs = byStudent.values.toList();
    for (final a in aggs) {
      a.percent = a.totalMax == 0 ? 0 : (a.total / a.totalMax) * 100;
    }
    // Rank by present-only percent; a student with no present result (totalMax
    // == 0) is NOT ranked and never shifts another student's rank.
    final ranked = aggs.where((a) => a.totalMax > 0).toList();
    for (final a in ranked) {
      a.rank = ranked.where((o) => o.percent > a.percent + 1e-9).length + 1;
    }

    final students = [
      for (final a in aggs)
        TabulationStudentRow(
          studentId: a.sisStudentId,
          sisStudentId: a.sisStudentId,
          studentName: a.studentName,
          rollNo: null,
          cellsBySubject: a.cells,
          total: a.total,
          totalMax: a.totalMax,
          percent: a.percent,
          rank: a.rank,
        ),
    ];
    return TabulationRegister(
      classLabel: classLabel,
      term: term,
      subjects: subjects,
      students: students,
    );
  }

  /// EXM-4a — top-[limit] students by marks for one exam (present rows only).
  static List<ExamTopper> toppers(
    ExamAdministrationStore store, {
    required String examId,
    int limit = 5,
  }) {
    final published = store
        .allPublishedResults()
        .where((r) => r.examId == examId && r.countsTowardStats)
        .toList()
      ..sort((a, b) => b.scoreObtained.compareTo(a.scoreObtained));
    final top = published.take(limit).toList();
    return [
      for (var i = 0; i < top.length; i++)
        ExamTopper(
          sisStudentId: top[i].sisStudentId,
          studentName: top[i].studentName,
          rollNo: null,
          marks: top[i].scoreObtained,
          maxMarks: top[i].maxScore,
          percent: top[i].maxScore == 0
              ? 0
              : (top[i].scoreObtained / top[i].maxScore) * 100,
          rank: i + 1,
        ),
    ];
  }

  /// EXM-4b — merit list for [classLabel] over [term] (present-only totals).
  static List<MeritEntry> merit(
    ExamAdministrationStore store, {
    required String classLabel,
    required String term,
  }) {
    final register = tabulation(store, classLabel: classLabel, term: term);
    final ranked = register.students.where((s) => s.rank != null).toList()
      ..sort((a, b) => a.rank!.compareTo(b.rank!));
    return [
      for (final s in ranked)
        MeritEntry(
          sisStudentId: s.sisStudentId,
          studentName: s.studentName,
          rollNo: s.rollNo,
          total: s.total,
          totalMax: s.totalMax,
          percent: s.percent,
          rank: s.rank!,
        ),
    ];
  }

  /// EXM-5 — pass/fail + grade distribution for one exam (present rows only).
  static ExamGradeDistribution distribution(
    ExamAdministrationStore store, {
    required String examId,
    int passMarkPercent = kDefaultPassMarkPercent,
  }) {
    final all =
        store.allPublishedResults().where((r) => r.examId == examId).toList();
    var passCount = 0;
    var failCount = 0;
    var presentCount = 0;
    var excludedCount = 0;
    final gradeCounts = <String, int>{};
    for (final r in all) {
      // 🔴 EXCLUSION — a non-present result never enters the stats.
      if (!r.countsTowardStats) {
        excludedCount++;
        continue;
      }
      presentCount++;
      final percent = r.maxScore == 0 ? 0.0 : (r.scoreObtained / r.maxScore) * 100;
      if (percent >= passMarkPercent) {
        passCount++;
      } else {
        failCount++;
      }
      final grade = r.grade.isNotEmpty
          ? r.grade
          : store.reportSettings.gradingScale.gradeFor(percent);
      gradeCounts[grade] = (gradeCounts[grade] ?? 0) + 1;
    }
    final buckets = gradeCounts.entries
        .map((e) => GradeBucket(grade: e.key, count: e.value))
        .toList()
      ..sort((a, b) {
        final byCount = b.count.compareTo(a.count);
        return byCount != 0 ? byCount : a.grade.compareTo(b.grade);
      });
    return ExamGradeDistribution(
      examId: examId,
      passMarkPercent: passMarkPercent,
      passMarkSource: 'default',
      passCount: passCount,
      failCount: failCount,
      gradeBreakdown: buckets,
      presentCount: presentCount,
      excludedCount: excludedCount,
    );
  }

  /// EXM-7 — datesheet for [classLabel] over [term], sorted by date then subject.
  static List<DatesheetRow> datesheet(
    ExamAdministrationStore store, {
    required String classLabel,
    required String term,
  }) {
    final rows = store
        .allExams()
        .where((e) =>
            e.termLabel == term &&
            (e.classLabel == classLabel || e.grade == classLabel))
        .map((e) => DatesheetRow(
              examId: e.id,
              subject: e.subject,
              dateLabel: e.dateLabel,
              timeLabel: e.timeLabel,
              venueLabel: e.venueLabel,
              maxMarks: e.maxMarks,
            ))
        .toList()
      ..sort((a, b) {
        final byDate = a.dateLabel.compareTo(b.dateLabel);
        return byDate != 0 ? byDate : a.subject.compareTo(b.subject);
      });
    return rows;
  }

  static List<PublishedExamResult> _classTermResults(
    ExamAdministrationStore store,
    String classLabel,
    String term,
  ) {
    // Map each published result to its exam session so we can match class + term.
    final results = <PublishedExamResult>[];
    for (final r in store.allPublishedResults()) {
      if (r.termLabel != term) continue;
      final exam = store.examById(r.examId);
      if (exam == null) continue;
      if (exam.classLabel != classLabel && exam.grade != classLabel) continue;
      results.add(r);
    }
    return results;
  }
}

class _StudentAgg {
  _StudentAgg({required this.sisStudentId, required this.studentName});
  final String sisStudentId;
  final String studentName;
  final Map<String, TabulationCell> cells = {};
  int total = 0;
  int totalMax = 0;
  double percent = 0;
  int? rank;
}
