import '../../features/education/education_models.dart';
import '../repositories/mock/mock_canonical_student_registry.dart';
import 'exam_administration_persistence.dart';
import 'exam_grading.dart';

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
    this.examType = EduExamType.unitTest,
    this.coordinatorVerified = false,
    this.rejectionComment,
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
  final EduExamType examType;
  final bool coordinatorVerified;
  final String? rejectionComment;

  String get classLabel => '$grade-$section';

  bool get isUpcoming =>
      phase == ExamLifecyclePhase.scheduled ||
      phase == ExamLifecyclePhase.marksEntry ||
      phase == ExamLifecyclePhase.processed;

  ExamSession copyWith({
    ExamLifecyclePhase? phase,
    EduExamType? examType,
    bool? coordinatorVerified,
    String? rejectionComment,
  }) {
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
      examType: examType ?? this.examType,
      coordinatorVerified: coordinatorVerified ?? this.coordinatorVerified,
      rejectionComment: rejectionComment ?? this.rejectionComment,
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
  final Map<String, String> _rejectionCommentsByExamId = {};
  final Map<String, String> _coordinatorVerifiedByExamId = {};
  bool _seeded = false;
  ExamAdministrationPersistence? _persistence;

  /// Per-school grading & report settings applied at publish time.
  /// Defaults to the standard scale so behaviour is unchanged until a school
  /// configures its board style (see [ExamReportSettings]).
  ExamReportSettings _reportSettings = ExamReportSettings.standard();

  /// Current report settings (grading scale + rank visibility + term hints).
  ExamReportSettings get reportSettings => _reportSettings;

  /// Applies a school's chosen grading scale / rank visibility / term hints.
  void configureReportSettings(ExamReportSettings settings) {
    _reportSettings = settings;
  }

  /// Attaches durable storage (mock pilot persistence — P0-EXAM-004).
  void attachPersistence(ExamAdministrationPersistence persistence) {
    _persistence = persistence;
  }

  void ensureSeeded() {
    if (_seeded) return;
    final snapshot = _persistence?.loadSnapshot();
    if (snapshot != null) {
      _importSnapshot(snapshot);
      _seeded = true;
      return;
    }
    _seeded = true;
    _seedDefaultExams();
    _persist();
  }

  void reset({bool clearPersistence = true}) {
    _exams.clear();
    _marks.clear();
    _publishedByMarkId.clear();
    _rejectionCommentsByExamId.clear();
    _coordinatorVerifiedByExamId.clear();
    _reportSettings = ExamReportSettings.standard();
    _seeded = false;
    if (clearPersistence) {
      _persistence?.clear();
    }
  }

  Map<String, dynamic> exportSnapshot() {
    ensureSeeded();
    return {
      'version': 1,
      'exams': [
        for (final exam in _exams.values) _examToJson(exam),
      ],
      'marks': [
        for (final mark in _marks.values) _markToJson(mark),
      ],
      'published': [
        for (final result in _publishedByMarkId.values) _publishedToJson(result),
      ],
      'rejectionComments': Map<String, String>.from(_rejectionCommentsByExamId),
      'coordinatorVerified': Map<String, String>.from(_coordinatorVerifiedByExamId),
    };
  }

  void _importSnapshot(Map<String, dynamic> snapshot) {
    _exams.clear();
    _marks.clear();
    _publishedByMarkId.clear();
    _rejectionCommentsByExamId.clear();
    _coordinatorVerifiedByExamId.clear();

    final exams = snapshot['exams'];
    if (exams is List) {
      for (final raw in exams) {
        if (raw is Map) {
          final exam = _examFromJson(Map<String, dynamic>.from(raw));
          _exams[exam.id] = exam;
        }
      }
    }

    final marks = snapshot['marks'];
    if (marks is List) {
      for (final raw in marks) {
        if (raw is Map) {
          final mark = _markFromJson(Map<String, dynamic>.from(raw));
          _marks[mark.id] = mark;
        }
      }
    }

    final published = snapshot['published'];
    if (published is List) {
      for (final raw in published) {
        if (raw is Map) {
          final result = _publishedFromJson(Map<String, dynamic>.from(raw));
          _publishedByMarkId[result.markEntryId] = result;
        }
      }
    }

    final rejection = snapshot['rejectionComments'];
    if (rejection is Map) {
      _rejectionCommentsByExamId.addAll(
        rejection.map((k, v) => MapEntry('$k', '$v')),
      );
    }

    final verified = snapshot['coordinatorVerified'];
    if (verified is Map) {
      _coordinatorVerifiedByExamId.addAll(
        verified.map((k, v) => MapEntry('$k', '$v')),
      );
    }
  }

  void _persist() {
    if (_persistence == null || !_seeded) return;
    _persistence!.saveSnapshot(exportSnapshot());
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

  String? rejectionCommentFor(String examId) {
    ensureSeeded();
    return _rejectionCommentsByExamId[examId];
  }

  void recordRejectionComment(String examId, String comment) {
    ensureSeeded();
    _rejectionCommentsByExamId[examId] = comment;
    _persist();
  }

  void clearRejectionComment(String examId) {
    _rejectionCommentsByExamId.remove(examId);
    _persist();
  }

  bool isCoordinatorVerified(String examId) {
    ensureSeeded();
    return _coordinatorVerifiedByExamId.containsKey(examId);
  }

  String? coordinatorVerifierFor(String examId) {
    ensureSeeded();
    return _coordinatorVerifiedByExamId[examId];
  }

  void markCoordinatorVerified(String examId, {required String verifiedBy}) {
    ensureSeeded();
    final exam = _exams[examId];
    if (exam == null) {
      throw StateError('Exam not found: $examId');
    }
    if (exam.phase != ExamLifecyclePhase.processed) {
      throw StateError(
        'Exam must be processed before coordinator verification (current: ${exam.phase.name})',
      );
    }
    _coordinatorVerifiedByExamId[examId] = verifiedBy;
    _persist();
  }

  void clearCoordinatorVerification(String examId) {
    _coordinatorVerifiedByExamId.remove(examId);
    _persist();
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
    EduExamType examType = EduExamType.unitTest,
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
      examType: examType,
    );
    _exams[id] = exam;
    _persist();
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
    _persist();
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
    _persist();
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
    clearCoordinatorVerification(existing.examId);
    _persist();
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
    _persist();
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
        grade: _reportSettings.gradingScale.gradeFor(percent),
        subject: exam.subject,
      );
      publishedCount++;
    }

    _exams[examId] = exam.copyWith(phase: ExamLifecyclePhase.published);
    _persist();
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
      examType: EduExamType.unitTest,
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
      examType: EduExamType.unitTest,
    );
  }

  static Map<String, dynamic> _examToJson(ExamSession exam) => {
        'id': exam.id,
        'title': exam.title,
        'subject': exam.subject,
        'grade': exam.grade,
        'section': exam.section,
        'termLabel': exam.termLabel,
        'dateLabel': exam.dateLabel,
        'timeLabel': exam.timeLabel,
        'venueLabel': exam.venueLabel,
        'syllabusLabel': exam.syllabusLabel,
        'maxMarks': exam.maxMarks,
        'phase': exam.phase.name,
        'examType': exam.examType.name,
      };

  static ExamSession _examFromJson(Map<String, dynamic> json) {
    return ExamSession(
      id: json['id'] as String,
      title: json['title'] as String,
      subject: json['subject'] as String,
      grade: json['grade'] as String,
      section: json['section'] as String,
      termLabel: json['termLabel'] as String,
      dateLabel: json['dateLabel'] as String,
      timeLabel: json['timeLabel'] as String,
      venueLabel: json['venueLabel'] as String,
      syllabusLabel: json['syllabusLabel'] as String,
      maxMarks: json['maxMarks'] as int,
      phase: ExamLifecyclePhase.values.byName(json['phase'] as String),
      examType: EduExamType.values.byName(json['examType'] as String),
    );
  }

  static Map<String, dynamic> _markToJson(ExamMarkRecord mark) => {
        'id': mark.id,
        'examId': mark.examId,
        'sisStudentId': mark.sisStudentId,
        'studentName': mark.studentName,
        'rollNo': mark.rollNo,
        'marksObtained': mark.marksObtained,
        'published': mark.published,
      };

  static ExamMarkRecord _markFromJson(Map<String, dynamic> json) {
    return ExamMarkRecord(
      id: json['id'] as String,
      examId: json['examId'] as String,
      sisStudentId: json['sisStudentId'] as String,
      studentName: json['studentName'] as String,
      rollNo: json['rollNo'] as String,
      marksObtained: json['marksObtained'] as int?,
      published: json['published'] as bool? ?? false,
    );
  }

  static Map<String, dynamic> _publishedToJson(PublishedExamResult result) => {
        'markEntryId': result.markEntryId,
        'sisStudentId': result.sisStudentId,
        'studentName': result.studentName,
        'examId': result.examId,
        'examTitle': result.examTitle,
        'termLabel': result.termLabel,
        'dateLabel': result.dateLabel,
        'scoreObtained': result.scoreObtained,
        'maxScore': result.maxScore,
        'grade': result.grade,
        'subject': result.subject,
      };

  static PublishedExamResult _publishedFromJson(Map<String, dynamic> json) {
    return PublishedExamResult(
      markEntryId: json['markEntryId'] as String,
      sisStudentId: json['sisStudentId'] as String,
      studentName: json['studentName'] as String,
      examId: json['examId'] as String,
      examTitle: json['examTitle'] as String,
      termLabel: json['termLabel'] as String,
      dateLabel: json['dateLabel'] as String,
      scoreObtained: json['scoreObtained'] as int,
      maxScore: json['maxScore'] as int,
      grade: json['grade'] as String,
      subject: json['subject'] as String,
    );
  }
}
