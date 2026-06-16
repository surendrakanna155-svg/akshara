import '../repositories/mock/mock_canonical_student_registry.dart';

/// Lifecycle phases for the exam administration chain.
enum ExamLifecyclePhase {
  draft,
  scheduled,
  marksEntry,
  processed,
  published,
}

/// Canonical exam session — single source of truth for scheduling.
class ExamSession {
  const ExamSession({
    required this.id,
    required this.title,
    required this.subject,
    required this.grade,
    required this.section,
    required this.termLabel,
    required this.dateLabel,
    required this.timeLabel,
    required this.venueLabel,
    required this.syllabusLabel,
    required this.maxMarks,
    required this.phase,
  });

  final String id;
  final String title;
  final String subject;
  final String grade;
  final String section;
  final String termLabel;
  final String dateLabel;
  final String timeLabel;
  final String venueLabel;
  final String syllabusLabel;
  final int maxMarks;
  final ExamLifecyclePhase phase;

  String get classLabel => '$grade-$section';

  bool get isUpcoming =>
      phase == ExamLifecyclePhase.scheduled ||
      phase == ExamLifecyclePhase.marksEntry ||
      phase == ExamLifecyclePhase.processed;

  ExamSession copyWith({ExamLifecyclePhase? phase}) {
    return ExamSession(
      id: id,
      title: title,
      subject: subject,
      grade: grade,
      section: section,
      termLabel: termLabel,
      dateLabel: dateLabel,
      timeLabel: timeLabel,
      venueLabel: venueLabel,
      syllabusLabel: syllabusLabel,
      maxMarks: maxMarks,
      phase: phase ?? this.phase,
    );
  }
}

/// Teacher marks entry row bound to an exam session.
class ExamMarkRecord {
  const ExamMarkRecord({
    required this.id,
    required this.examId,
    required this.sisStudentId,
    required this.studentName,
    required this.rollNo,
    this.marksObtained,
    this.published = false,
  });

  final String id;
  final String examId;
  final String sisStudentId;
  final String studentName;
  final String rollNo;
  final int? marksObtained;
  final bool published;

  ExamMarkRecord copyWith({int? marksObtained, bool? published}) {
    return ExamMarkRecord(
      id: id,
      examId: examId,
      sisStudentId: sisStudentId,
      studentName: studentName,
      rollNo: rollNo,
      marksObtained: marksObtained ?? this.marksObtained,
      published: published ?? this.published,
    );
  }
}

/// Published result visible to student and parent apps.
class PublishedExamResult {
  const PublishedExamResult({
    required this.markEntryId,
    required this.sisStudentId,
    required this.studentName,
    required this.examId,
    required this.examTitle,
    required this.termLabel,
    required this.dateLabel,
    required this.scoreObtained,
    required this.maxScore,
    required this.grade,
    required this.subject,
  });

  final String markEntryId;
  final String sisStudentId;
  final String studentName;
  final String examId;
  final String examTitle;
  final String termLabel;
  final String dateLabel;
  final int scoreObtained;
  final int maxScore;
  final String grade;
  final String subject;
}

/// Single source of truth for exam creation → publish chain.
final class ExamAdministrationStore {
  ExamAdministrationStore._();

  static final ExamAdministrationStore instance = ExamAdministrationStore._();

  final Map<String, ExamSession> _exams = {};
  final Map<String, ExamMarkRecord> _marks = {};
  final Map<String, PublishedExamResult> _publishedByMarkId = {};
  bool _seeded = false;

  void ensureSeeded() {
    if (_seeded) return;
    _seeded = true;
    _seedDefaultExams();
  }

  void reset() {
    _exams.clear();
    _marks.clear();
    _publishedByMarkId.clear();
    _seeded = false;
  }

  bool get hasPublishedResults => _publishedByMarkId.isNotEmpty;

  /// Active exam used for teacher marks entry (first open session).
  String? get activeMarksExamId {
    ensureSeeded();
    for (final exam in _exams.values) {
      if (exam.phase == ExamLifecyclePhase.marksEntry ||
          exam.phase == ExamLifecyclePhase.processed) {
        return exam.id;
      }
    }
    return null;
  }

  ExamSession? examById(String examId) {
    ensureSeeded();
    return _exams[examId];
  }

  List<ExamSession> allExams() {
    ensureSeeded();
    return _exams.values.toList(growable: false);
  }

  List<ExamSession> upcomingExams({String? classLabel}) {
    ensureSeeded();
    return _exams.values
        .where((exam) {
          if (!exam.isUpcoming) return false;
          if (classLabel != null && exam.classLabel != classLabel) return false;
          return true;
        })
        .toList(growable: false);
  }

  List<ExamMarkRecord> marksForExam(String examId) {
    ensureSeeded();
    return _marks.values
        .where((mark) => mark.examId == examId)
        .toList(growable: false);
  }

  List<ExamMarkRecord> activeMarkEntries() {
    ensureSeeded();
    final examId = activeMarksExamId;
    if (examId == null) return const [];
    return marksForExam(examId);
  }

  ExamMarkRecord? markById(String markEntryId) {
    ensureSeeded();
    return _marks[markEntryId];
  }

  ExamSession createExam({
    required String title,
    required String subject,
    required String grade,
    required String section,
    required String termLabel,
    required String dateLabel,
    required String timeLabel,
    required String venueLabel,
    required String syllabusLabel,
    required int maxMarks,
  }) {
    ensureSeeded();
    final id = 'exam_${_exams.length + 1}';
    final exam = ExamSession(
      id: id,
      title: title,
      subject: subject,
      grade: grade,
      section: section,
      termLabel: termLabel,
      dateLabel: dateLabel,
      timeLabel: timeLabel,
      venueLabel: venueLabel,
      syllabusLabel: syllabusLabel,
      maxMarks: maxMarks,
      phase: ExamLifecyclePhase.draft,
    );
    _exams[id] = exam;
    return exam;
  }

  ExamSession scheduleExam(String examId) {
    ensureSeeded();
    final exam = _exams[examId];
    if (exam == null) {
      throw StateError('Exam not found: $examId');
    }
    final scheduled = exam.copyWith(phase: ExamLifecyclePhase.scheduled);
    _exams[examId] = scheduled;
    _provisionMarkSlots(scheduled);
    return scheduled;
  }

  ExamSession openMarksEntry(String examId) {
    ensureSeeded();
    final exam = _exams[examId];
    if (exam == null) {
      throw StateError('Exam not found: $examId');
    }
    final open = exam.copyWith(phase: ExamLifecyclePhase.marksEntry);
    _exams[examId] = open;
    _provisionMarkSlots(open);
    return open;
  }

  ExamMarkRecord recordMark({
    required String markEntryId,
    required int marksObtained,
  }) {
    ensureSeeded();
    final existing = _marks[markEntryId];
    if (existing == null) {
      throw StateError('Mark entry not found: $markEntryId');
    }
    if (existing.published) {
      throw StateError('Cannot edit published mark: $markEntryId');
    }
    final updated = existing.copyWith(marksObtained: marksObtained);
    _marks[markEntryId] = updated;
    return updated;
  }

  ExamSession processResults(String examId) {
    ensureSeeded();
    final exam = _exams[examId];
    if (exam == null) {
      throw StateError('Exam not found: $examId');
    }
    final marks = marksForExam(examId);
    final pending = marks.where((m) => m.marksObtained == null).toList();
    if (pending.isNotEmpty) {
      throw StateError(
        'Marks incomplete: ${pending.length} students pending for $examId',
      );
    }
    final processed = exam.copyWith(phase: ExamLifecyclePhase.processed);
    _exams[examId] = processed;
    return processed;
  }

  int publishExamResults(String examId) {
    ensureSeeded();
    final exam = _exams[examId];
    if (exam == null) {
      throw StateError('Exam not found: $examId');
    }
    if (exam.phase == ExamLifecyclePhase.published) {
      return marksForExam(examId).where((m) => m.published).length;
    }

    final marks = marksForExam(examId);
    final enterable = marks.where((m) => m.marksObtained != null).toList();
    if (enterable.isEmpty) {
      throw StateError('No marks entered for exam: $examId');
    }

    var publishedCount = 0;
    for (final mark in enterable) {
      final score = mark.marksObtained!;
      final percent = exam.maxMarks == 0 ? 0.0 : (score / exam.maxMarks) * 100.0;
      _marks[mark.id] = mark.copyWith(published: true);
      _publishedByMarkId[mark.id] = PublishedExamResult(
        markEntryId: mark.id,
        sisStudentId: mark.sisStudentId,
        studentName: mark.studentName,
        examId: exam.id,
        examTitle: exam.title,
        termLabel: exam.termLabel,
        dateLabel: exam.dateLabel,
        scoreObtained: score,
        maxScore: exam.maxMarks,
        grade: _gradeForPercent(percent),
        subject: exam.subject,
      );
      publishedCount++;
    }

    _exams[examId] = exam.copyWith(phase: ExamLifecyclePhase.published);
    return publishedCount;
  }

  List<PublishedExamResult> resultsForStudent(String sisStudentId) {
    ensureSeeded();
    return _publishedByMarkId.values
        .where((result) => result.sisStudentId == sisStudentId)
        .toList(growable: false);
  }

  PublishedExamResult? resultForMarkEntry(String markEntryId) {
    ensureSeeded();
    return _publishedByMarkId[markEntryId];
  }

  void _provisionMarkSlots(ExamSession exam) {
    final students = MockCanonicalStudentRegistry.forClass(exam.grade, exam.section);
    for (final student in students) {
      final markId = '${exam.id}_${student.rollNo}';
      if (_marks.containsKey(markId)) continue;
      _marks[markId] = ExamMarkRecord(
        id: markId,
        examId: exam.id,
        sisStudentId: student.sisStudentId,
        studentName: student.studentName,
        rollNo: student.rollNo,
      );
    }
  }

  void _seedDefaultExams() {
    const mathExamId = 'exam_math_8a';
    _exams[mathExamId] = const ExamSession(
      id: mathExamId,
      title: 'Unit Test — Mathematics',
      subject: 'Mathematics',
      grade: '8',
      section: 'A',
      termLabel: 'Term 2',
      dateLabel: '12 Jun 2026',
      timeLabel: '9:00 AM - 10:30 AM',
      venueLabel: 'Room 8A',
      syllabusLabel: 'Algebra, Linear Equations',
      maxMarks: 50,
      phase: ExamLifecyclePhase.marksEntry,
    );
    _provisionMarkSlots(_exams[mathExamId]!);

    // Pre-enter marks for all class 8-A students — not published until teacher publishes.
    // Leave one slot open for teacher marks-entry workflow tests.
    for (final student in MockCanonicalStudentRegistry.class8A()) {
      if (student.rollNo == '06') continue;
      final markId = '${mathExamId}_${student.rollNo}';
      final seedMark = switch (student.rollNo) {
        '01' => 42,
        '02' => 45,
        '03' => 40,
        '04' => 38,
        '06' => 44,
        _ => 36,
      };
      _marks[markId] = _marks[markId]!.copyWith(marksObtained: seedMark);
    }

    const scienceExamId = 'exam_science_8a';
    _exams[scienceExamId] = const ExamSession(
      id: scienceExamId,
      title: 'Unit Test — Science',
      subject: 'Science',
      grade: '8',
      section: 'A',
      termLabel: 'Term 2',
      dateLabel: '14 Jun 2026',
      timeLabel: '11:00 AM - 12:30 PM',
      venueLabel: 'Science Lab 2',
      syllabusLabel: 'Cell Structure, Nutrition',
      maxMarks: 50,
      phase: ExamLifecyclePhase.scheduled,
    );
  }

  static String _gradeForPercent(double percent) {
    if (percent >= 90) return 'A+';
    if (percent >= 80) return 'A';
    if (percent >= 70) return 'B+';
    if (percent >= 60) return 'B';
    if (percent >= 50) return 'C';
    return 'D';
  }
}
