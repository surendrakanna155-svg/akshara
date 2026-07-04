import '../../features/education/education_models.dart';
import '../repositories/mock/mock_canonical_student_registry.dart';
import 'exam_administration_persistence.dart';
import 'exam_administration_requests.dart';
import 'exam_grading.dart';
import 'exam_remark.dart';

/// Lifecycle phases for the exam administration chain.
enum ExamLifecyclePhase {
  draft,
  scheduled,
  marksEntry,
  processed,
  published,
}

/// EXM-D6 — a student's attendance status for an exam. A non-[present] status
/// has NO marks (null) and is shown as a display code (AB/ML/DB); it is EXCLUDED
/// from totals, averages, percentages, class rank, pass/fail and the grade
/// distribution.
enum ExamMarkStatus {
  present,
  absent,
  medicalLeave,
  debarred;

  /// Wire value shared with the backend (`exam_mark_entries.status`).
  String get wire => switch (this) {
        ExamMarkStatus.present => 'present',
        ExamMarkStatus.absent => 'absent',
        ExamMarkStatus.medicalLeave => 'medical_leave',
        ExamMarkStatus.debarred => 'debarred',
      };

  /// Report-card / cell display code for a non-present status, else null (a
  /// present student shows their actual marks + computed grade).
  String? get displayCode => switch (this) {
        ExamMarkStatus.present => null,
        ExamMarkStatus.absent => 'AB',
        ExamMarkStatus.medicalLeave => 'ML',
        ExamMarkStatus.debarred => 'DB',
      };

  /// Short human label for the status selector.
  String get label => switch (this) {
        ExamMarkStatus.present => 'Present',
        ExamMarkStatus.absent => 'Absent (AB)',
        ExamMarkStatus.medicalLeave => 'Medical leave (ML)',
        ExamMarkStatus.debarred => 'Debarred (DB)',
      };

  bool get isPresent => this == ExamMarkStatus.present;

  static ExamMarkStatus fromWire(String? value) => switch (value) {
        'absent' => ExamMarkStatus.absent,
        'medical_leave' => ExamMarkStatus.medicalLeave,
        'debarred' => ExamMarkStatus.debarred,
        _ => ExamMarkStatus.present,
      };
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
    this.marksEntryDeadline,
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

  /// EXM-6 — optional soft deadline (UTC) by which subject teachers must enter
  /// marks. Null when unset. Surfaced as a banner on the marks-entry screen; the
  /// automated reminder rides a future reminder-rule engine (XCT-2), not here.
  final DateTime? marksEntryDeadline;

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
    DateTime? marksEntryDeadline,
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
      marksEntryDeadline: marksEntryDeadline ?? this.marksEntryDeadline,
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
    this.status = ExamMarkStatus.present,
    this.rowVersion,
  });

  final String id;
  final String examId;
  final String sisStudentId;
  final String studentName;
  final String rollNo;

  /// Null for a non-present student (they have no meaningful score) or when a
  /// present student's mark has not yet been entered.
  final int? marksObtained;
  final bool published;

  /// EXM-D6 — attendance status. A non-present status has null [marksObtained]
  /// and is shown via [ExamMarkStatus.displayCode].
  final ExamMarkStatus status;

  /// REL-5 — the persisted optimistic-concurrency version this row was read at.
  /// Carried into an edit as `expectedVersion` so the FIRST write (not only a
  /// post-conflict retry) engages the server's lost-update guard. Null when the
  /// read model predates versioning (backend then applies unconditionally).
  final int? rowVersion;

  /// Display code (AB/ML/DB) for a non-present student, else null.
  String? get statusCode => status.displayCode;

  ExamMarkRecord copyWith({
    int? marksObtained,
    bool clearMarks = false,
    bool? published,
    ExamMarkStatus? status,
    int? rowVersion,
  }) {
    return ExamMarkRecord(
      id: id,
      examId: examId,
      sisStudentId: sisStudentId,
      studentName: studentName,
      rollNo: rollNo,
      marksObtained: clearMarks ? null : (marksObtained ?? this.marksObtained),
      published: published ?? this.published,
      status: status ?? this.status,
      rowVersion: rowVersion ?? this.rowVersion,
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
    this.status = ExamMarkStatus.present,
  });

  final String markEntryId;
  final String sisStudentId;
  final String studentName;
  final String examId;
  final String examTitle;
  final String termLabel;
  final String dateLabel;

  /// Raw marks. For a non-present student this is 0 and MUST NOT be read as a
  /// score — [status] is not [ExamMarkStatus.present], so the row is excluded
  /// from all aggregation. Use [statusCode] to render AB/ML/DB in the cell.
  final int scoreObtained;
  final int maxScore;
  final String grade;
  final String subject;

  /// EXM-D6 — attendance status. A non-present result is EXCLUDED from totals,
  /// averages, percent, rank, pass/fail and grade distribution.
  final ExamMarkStatus status;

  /// Whether this result counts toward totals/average/rank (a present student).
  bool get countsTowardStats => status.isPresent;

  /// Display code (AB/ML/DB) for a non-present student, else null.
  String? get statusCode => status.displayCode;
}

/// EXM-2 — marks-entry progress for one exam in the `marks_entry` phase: how
/// many students already have a decision ([enteredCount]) versus the whole
/// roster ([totalCount]). A coordinator uses [pending] to see who still owes
/// marks before processing/publishing. "Entered" includes non-present (AB/ML/DB)
/// rows — they are decided, not pending.
class MarksEntryProgress {
  const MarksEntryProgress({
    required this.examId,
    required this.title,
    required this.subject,
    required this.grade,
    required this.sectionName,
    required this.enteredCount,
    required this.totalCount,
    this.marksEntryDeadline,
  });

  final String examId;
  final String title;
  final String subject;
  final String grade;
  final String sectionName;
  final int enteredCount;
  final int totalCount;

  /// EXM-6 — the exam's marks-entry deadline (null when unset), so the progress
  /// board can flag exams approaching / past their deadline.
  final DateTime? marksEntryDeadline;

  /// Students who still owe a decision (0 when the roster is complete).
  int get pending => (totalCount - enteredCount).clamp(0, totalCount);

  /// Fraction complete in [0, 1] for the progress bar (1 when empty roster).
  double get fraction =>
      totalCount == 0 ? 1.0 : (enteredCount / totalCount).clamp(0.0, 1.0);

  String get classLabel => '$grade-$sectionName';
}

/// EXM-1 — outcome of a bulk marks save: the persisted rows and the per-row
/// failures (published/immutable, out of bounds, conflict, not found, …).
class BulkExamMarkSaveResult {
  const BulkExamMarkSaveResult({required this.updated, required this.failed});

  final List<ExamMarkRecord> updated;
  final List<BulkExamMarkFailure> failed;

  int get savedCount => updated.length;
  int get failedCount => failed.length;
}

/// EXM-1 — a single rejected row in a bulk save (with a human reason).
class BulkExamMarkFailure {
  const BulkExamMarkFailure({required this.markEntryId, required this.reason});

  final String markEntryId;
  final String reason;
}

/// EXM-D2 — one recorded grace / moderation adjustment for a (exam, student).
/// The ORIGINAL entered mark is never overwritten; this is a separate audited
/// record. The breakdown is coordinator/principal-only (never shown to parents).
class ExamMarkAdjustment {
  const ExamMarkAdjustment({
    required this.id,
    required this.examId,
    required this.sisStudentId,
    required this.delta,
    required this.reason,
    this.adjustedBy,
    this.createdAt,
  });

  final String id;
  final String examId;
  final String sisStudentId;

  /// Signed delta (grace is usually positive; a downward moderation is allowed).
  final int delta;
  final String reason;
  final String? adjustedBy;
  final DateTime? createdAt;
}

/// EXM-D2 — the outcome of recording a grace adjustment: the stored record plus
/// the resulting EFFECTIVE mark (original + Σdeltas, bounds-capped). The original
/// is preserved; the client reflects the effective in totals.
class GraceMarkResult {
  const GraceMarkResult({
    required this.adjustment,
    required this.effectiveMark,
    required this.maxMarks,
  });

  final ExamMarkAdjustment adjustment;
  final int? effectiveMark;
  final int maxMarks;
}

/// EXM-D1 — one subject line on a batch report card (published, effective mark).
class ReportCardSubject {
  const ReportCardSubject({
    required this.subject,
    required this.examTitle,
    required this.score,
    required this.maxScore,
    required this.grade,
    required this.statusCode,
  });

  final String subject;
  final String examTitle;

  /// Effective (grace-applied) marks, or null for a non-present (AB/ML/DB) line.
  final int? score;
  final int maxScore;
  final String grade;
  final String? statusCode;
}

/// EXM-D1 — a per-student report card for a class + term (published results).
class ReportCardData {
  const ReportCardData({
    required this.sisStudentId,
    required this.studentName,
    required this.classLabel,
    required this.termLabel,
    required this.subjects,
    required this.totalScore,
    required this.totalMax,
    required this.overallPercent,
    required this.overallGrade,
    required this.rank,
    required this.classSize,
  });

  final String sisStudentId;
  final String studentName;
  final String classLabel;
  final String termLabel;
  final List<ReportCardSubject> subjects;
  final int totalScore;
  final int totalMax;
  final double overallPercent;
  final String overallGrade;

  /// 1-based class rank (present-only), or null when the student is not ranked.
  final int? rank;
  final int classSize;
}

/// EXM-D4 — a per-student hall ticket (admit card) for one exam.
class HallTicket {
  const HallTicket({
    required this.sisStudentId,
    required this.studentName,
    required this.rollNo,
    required this.classLabel,
    required this.subject,
    required this.examTitle,
    required this.dateLabel,
    required this.timeLabel,
    required this.venueLabel,
    required this.maxMarks,
    required this.instructions,
  });

  final String sisStudentId;
  final String studentName;
  final String? rollNo;
  final String classLabel;
  final String subject;
  final String examTitle;
  final String dateLabel;
  final String timeLabel;
  final String venueLabel;
  final int maxMarks;
  final List<String> instructions;
}

/// EXM-D5 — one seat in a room's seating plan.
class SeatingSeat {
  const SeatingSeat({
    required this.seatNo,
    required this.sisStudentId,
    required this.studentName,
    required this.rollNo,
    required this.classLabel,
  });

  final int seatNo;
  final String sisStudentId;
  final String studentName;
  final String? rollNo;
  final String classLabel;
}

/// EXM-D5 — one room in the seating plan, seats ordered by seat number.
class SeatingRoom {
  const SeatingRoom({required this.roomLabel, required this.seats});

  final String roomLabel;
  final List<SeatingSeat> seats;
}

/// EXM-D5 — the full seating plan for an exam (rooms of a configurable capacity).
class SeatingPlan {
  const SeatingPlan({
    required this.examId,
    required this.roomCapacity,
    required this.rooms,
  });

  final String examId;
  final int roomCapacity;
  final List<SeatingRoom> rooms;

  int get totalSeats => rooms.fold<int>(0, (sum, r) => sum + r.seats.length);
}

/// Standard admit-card instructions (adopted default; mirrors the backend).
const List<String> kHallTicketInstructions = [
  'Carry this hall ticket to the examination hall.',
  'Reach the venue at least 15 minutes before the start time.',
  'Electronic devices and unauthorised materials are prohibited.',
  'Follow all instructions given by the invigilator.',
];

/// Default seating room capacity (adopted default; mirrors the backend).
const int kDefaultSeatingRoomCapacity = 30;

/// EXM-D5 — a student who sits an exam, fed to the seating planner.
class SeatingCandidate {
  const SeatingCandidate({
    required this.sisStudentId,
    required this.studentName,
    required this.rollNo,
    required this.classLabel,
  });

  final String sisStudentId;
  final String studentName;
  final String? rollNo;
  final String classLabel;
}

/// EXM-D5 — pure seating planner (mirrors the backend `planSeating`). Interleaves
/// classes so no two ADJACENT seats share a class when multiple classes sit; a
/// single class seats sequentially by roll. Rooms fill to [capacity] then a new
/// room opens. Room labels are "Room 1", "Room 2", …; seatNo is 1-based per room.
abstract final class ExamSeatingPlanner {
  static SeatingPlan plan({
    required String examId,
    required List<SeatingCandidate> candidates,
    required int capacity,
  }) {
    final cap = capacity > 0 ? capacity : kDefaultSeatingRoomCapacity;

    // Group by class, each ordered by roll (nulls last) then id.
    final byClass = <String, List<SeatingCandidate>>{};
    for (final c in candidates) {
      (byClass[c.classLabel] ??= <SeatingCandidate>[]).add(c);
    }
    for (final list in byClass.values) {
      list.sort((a, b) {
        final ra = a.rollNo ?? '￿';
        final rb = b.rollNo ?? '￿';
        if (ra != rb) return ra.compareTo(rb);
        return a.sisStudentId.compareTo(b.sisStudentId);
      });
    }

    final classKeys = byClass.keys.toList();
    final order = <SeatingCandidate>[];
    if (classKeys.length <= 1) {
      for (final list in byClass.values) {
        order.addAll(list);
      }
    } else {
      // Round-robin greedy: never place the same class as the previous pick;
      // among eligible classes pick the largest remaining group.
      final queues = <String, List<SeatingCandidate>>{
        for (final e in byClass.entries) e.key: List.of(e.value),
      };
      String? lastClass;
      var remaining = candidates.length;
      while (remaining > 0) {
        String? pickKey;
        var pickLen = -1;
        for (final k in classKeys) {
          final q = queues[k]!;
          if (q.isEmpty || k == lastClass) continue;
          if (q.length > pickLen) {
            pickLen = q.length;
            pickKey = k;
          }
        }
        // Only the last-placed class has students left → unavoidable repeat.
        pickKey ??= classKeys.firstWhere((k) => queues[k]!.isNotEmpty);
        order.add(queues[pickKey]!.removeAt(0));
        lastClass = pickKey;
        remaining--;
      }
    }

    // Chunk into rooms of `cap`.
    final rooms = <SeatingRoom>[];
    List<SeatingSeat>? currentSeats;
    for (var i = 0; i < order.length; i++) {
      final roomIndex = i ~/ cap;
      final seatNo = (i % cap) + 1;
      if (seatNo == 1) {
        currentSeats = <SeatingSeat>[];
        rooms.add(SeatingRoom(
          roomLabel: 'Room ${roomIndex + 1}',
          seats: currentSeats,
        ));
      }
      final c = order[i];
      currentSeats!.add(SeatingSeat(
        seatNo: seatNo,
        sisStudentId: c.sisStudentId,
        studentName: c.studentName,
        rollNo: c.rollNo,
        classLabel: c.classLabel,
      ));
    }
    return SeatingPlan(examId: examId, roomCapacity: cap, rooms: rooms);
  }
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
  final Map<String, ExamRemark> _remarksByKey = {};
  // EXM-D2 — grace / moderation adjustments, keyed by exam id. Each is a separate
  // audited record; the ORIGINAL mark on the ExamMarkRecord is NEVER overwritten.
  final Map<String, List<ExamMarkAdjustment>> _adjustmentsByExam = {};
  // EXM-D5 — generated seating plans, keyed by exam id (mock only).
  final Map<String, SeatingPlan> _seatingByExam = {};
  int _adjustmentSeq = 0;
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
    ensureSeeded();
    _reportSettings = settings;
    _persist();
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
    _remarksByKey.clear();
    _adjustmentsByExam.clear();
    _seatingByExam.clear();
    _adjustmentSeq = 0;
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
      'reportSettings': _reportSettingsToJson(_reportSettings),
      'remarks': [for (final r in _remarksByKey.values) r.toJson()],
    };
  }

  void _importSnapshot(Map<String, dynamic> snapshot) {
    _exams.clear();
    _marks.clear();
    _publishedByMarkId.clear();
    _rejectionCommentsByExamId.clear();
    _coordinatorVerifiedByExamId.clear();
    _remarksByKey.clear();

    final remarks = snapshot['remarks'];
    if (remarks is List) {
      for (final raw in remarks) {
        if (raw is Map) {
          final remark = ExamRemark.fromJson(Map<String, dynamic>.from(raw));
          _remarksByKey[_remarkKey(
            remark.examId,
            remark.sisStudentId,
            leadership: remark.authorRole.isLeadership,
          )] = remark;
        }
      }
    }

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

    final reportSettings = snapshot['reportSettings'];
    _reportSettings = reportSettings is Map
        ? _reportSettingsFromJson(Map<String, dynamic>.from(reportSettings))
        : ExamReportSettings.standard();
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

  /// EXM-2 — marks-entry progress for every exam currently in the marks_entry
  /// phase. "Entered" = a present student with a mark OR a non-present (AB/ML/DB)
  /// student, mirroring the backend's `marks_entered = true` semantics.
  List<MarksEntryProgress> marksEntryProgress() {
    ensureSeeded();
    final result = <MarksEntryProgress>[];
    for (final exam in _exams.values) {
      if (exam.phase != ExamLifecyclePhase.marksEntry) continue;
      final marks = marksForExam(exam.id);
      final entered = marks
          .where((m) => !m.status.isPresent || m.marksObtained != null)
          .length;
      result.add(
        MarksEntryProgress(
          examId: exam.id,
          title: exam.title,
          subject: exam.subject,
          grade: exam.grade,
          sectionName: exam.section,
          enteredCount: entered,
          totalCount: marks.length,
          marksEntryDeadline: exam.marksEntryDeadline,
        ),
      );
    }
    return result;
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
    DateTime? marksEntryDeadline,
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
      marksEntryDeadline: marksEntryDeadline,
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
    ExamMarkStatus status = ExamMarkStatus.present,
  }) {
    ensureSeeded();
    final existing = _marks[markEntryId];
    if (existing == null) {
      throw StateError('Mark entry not found: $markEntryId');
    }
    if (existing.published) {
      throw StateError('Cannot edit published mark: $markEntryId');
    }
    // EXM-D6 — a non-present student has NO score: clear marks. A present student
    // keeps their entered marks.
    final updated = status.isPresent
        ? existing.copyWith(marksObtained: marksObtained, status: status)
        : existing.copyWith(clearMarks: true, status: status);
    _marks[markEntryId] = updated;
    clearCoordinatorVerification(existing.examId);
    _persist();
    return updated;
  }

  /// EXM-1 — applies a fast bulk marks save, per row, with partial success. A
  /// published (immutable) row, a missing row, or an out-of-bounds present mark
  /// is reported in `failed` and never overwritten; the rest persist. Mirrors the
  /// backend's guarded per-row apply.
  BulkExamMarkSaveResult recordMarksBulk({
    required List<BulkExamMarkEntry> entries,
    int? maxMarks,
  }) {
    ensureSeeded();
    final updated = <ExamMarkRecord>[];
    final failed = <BulkExamMarkFailure>[];
    for (final entry in entries) {
      final existing = _marks[entry.markEntryId];
      if (existing == null) {
        failed.add(BulkExamMarkFailure(
          markEntryId: entry.markEntryId,
          reason: 'mark entry not found or already published',
        ));
        continue;
      }
      if (existing.published) {
        // Published rows are immutable — never overwritten.
        failed.add(BulkExamMarkFailure(
          markEntryId: entry.markEntryId,
          reason: 'mark entry not found or already published',
        ));
        continue;
      }
      if (entry.status.isPresent) {
        final marks = entry.marksObtained;
        if (marks == null || marks < 0 ||
            (maxMarks != null && marks > maxMarks)) {
          failed.add(BulkExamMarkFailure(
            markEntryId: entry.markEntryId,
            reason: maxMarks != null
                ? 'marks must be between 0 and $maxMarks'
                : 'marks required for a present student',
          ));
          continue;
        }
        final row = existing.copyWith(
          marksObtained: marks,
          status: ExamMarkStatus.present,
        );
        _marks[entry.markEntryId] = row;
        clearCoordinatorVerification(existing.examId);
        updated.add(row);
      } else {
        // Non-present: force null marks.
        final row = existing.copyWith(clearMarks: true, status: entry.status);
        _marks[entry.markEntryId] = row;
        clearCoordinatorVerification(existing.examId);
        updated.add(row);
      }
    }
    _persist();
    return BulkExamMarkSaveResult(updated: updated, failed: failed);
  }

  ExamSession processResults(String examId) {
    ensureSeeded();
    final exam = _exams[examId];
    if (exam == null) {
      throw StateError('Exam not found: $examId');
    }
    final marks = marksForExam(examId);
    // EXM-D6 — a non-present student (AB/ML/DB) is decided, not pending: only a
    // present student with no marks entered blocks processing.
    final pending =
        marks.where((m) => m.status.isPresent && m.marksObtained == null).toList();
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
    // EXM-D6 — a row is publishable when a present student has marks OR the
    // student is non-present (decided AB/ML/DB, no marks needed).
    final enterable = marks
        .where((m) => !m.status.isPresent || m.marksObtained != null)
        .toList();
    if (enterable.isEmpty) {
      throw StateError('No marks entered for exam: $examId');
    }

    var publishedCount = 0;
    for (final mark in enterable) {
      final isPresent = mark.status.isPresent;
      // 🔴 EXM-D2 — a present student's published score is the EFFECTIVE mark
      // (original + Σgrace, bounds-capped). The ORIGINAL mark on the record is
      // never overwritten; parents/students see only the effective value, never
      // the grace breakdown. A non-present student has no score (0, excluded).
      final score = isPresent
          ? clampEffectiveMark(
              mark.marksObtained! + adjustmentTotalFor(exam.id, mark.sisStudentId),
              exam.maxMarks,
            )
          : 0;
      final percent = (!isPresent || exam.maxMarks == 0)
          ? 0.0
          : (score / exam.maxMarks) * 100.0;
      // A non-present student publishes with their display code (AB/ML/DB), not a
      // computed letter grade.
      final grade = isPresent
          ? _reportSettings.gradingScale.gradeFor(percent)
          : (mark.status.displayCode ?? '');
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
        grade: grade,
        subject: exam.subject,
        status: mark.status,
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

  /// All published results across students — used to compute class rank for the
  /// report card (Slice 6).
  List<PublishedExamResult> allPublishedResults() {
    ensureSeeded();
    return _publishedByMarkId.values.toList(growable: false);
  }

  PublishedExamResult? resultForMarkEntry(String markEntryId) {
    ensureSeeded();
    return _publishedByMarkId[markEntryId];
  }

  // ── EXM-D2 — grace / moderation ─────────────────────────────────────────────
  // 🔴 A grace adjustment is a SEPARATE record; the ORIGINAL mark on the
  // ExamMarkRecord is NEVER overwritten. The effective mark = clamp(original +
  // Σdeltas, 0, max). Allowed only before publish (processed phase).

  /// Clamps an effective mark into [0, max].
  static int clampEffectiveMark(int value, int maxMarks) {
    if (value < 0) return 0;
    if (value > maxMarks) return maxMarks;
    return value;
  }

  /// Sum of all grace deltas for a (exam, student). 0 when none.
  int adjustmentTotalFor(String examId, String sisStudentId) {
    ensureSeeded();
    final list = _adjustmentsByExam[examId];
    if (list == null) return 0;
    return list
        .where((a) => a.sisStudentId == sisStudentId)
        .fold<int>(0, (sum, a) => sum + a.delta);
  }

  /// The effective (original + grace) mark for a present student's mark entry,
  /// bounds-capped; null for a non-present student or an entry with no marks yet.
  int? effectiveMarkFor(String markEntryId) {
    ensureSeeded();
    final mark = _marks[markEntryId];
    if (mark == null || !mark.status.isPresent || mark.marksObtained == null) {
      return null;
    }
    final exam = _exams[mark.examId];
    final max = exam?.maxMarks ?? mark.marksObtained!;
    final total = adjustmentTotalFor(mark.examId, mark.sisStudentId);
    return clampEffectiveMark(mark.marksObtained! + total, max);
  }

  /// All grace adjustments for an exam (coordinator-only breakdown).
  List<ExamMarkAdjustment> adjustmentsForExam(String examId) {
    ensureSeeded();
    return List.unmodifiable(_adjustmentsByExam[examId] ?? const []);
  }

  /// EXM-D2 — records a grace / moderation delta for a (exam, student). Preserves
  /// the ORIGINAL mark. Allowed only while the exam is processed (before publish).
  /// Returns the record + the resulting effective mark.
  GraceMarkResult recordGraceAdjustment({
    required String examId,
    required String sisStudentId,
    required int delta,
    required String reason,
    String? adjustedBy,
  }) {
    ensureSeeded();
    final exam = _exams[examId];
    if (exam == null) {
      throw StateError('Exam not found: $examId');
    }
    if (exam.phase != ExamLifecyclePhase.processed) {
      throw StateError(
        'Grace / moderation is only allowed before publish (current phase: '
        '${exam.phase.name}).',
      );
    }
    if (reason.trim().isEmpty) {
      throw StateError('reason is required for a grace / moderation adjustment');
    }
    // The student's present mark entry for this exam.
    final mark = marksForExam(examId).where((m) => m.sisStudentId == sisStudentId).cast<ExamMarkRecord?>().firstWhere(
          (m) => true,
          orElse: () => null,
        );
    if (mark == null) {
      throw StateError('Mark entry not found for student: $sisStudentId');
    }
    if (!mark.status.isPresent || mark.marksObtained == null) {
      throw StateError(
        'Cannot apply grace to a non-present student (absent / medical / debarred).',
      );
    }
    final adjustment = ExamMarkAdjustment(
      id: 'adj_${++_adjustmentSeq}',
      examId: examId,
      sisStudentId: sisStudentId,
      delta: delta,
      reason: reason.trim(),
      adjustedBy: adjustedBy,
      createdAt: DateTime.now().toUtc(),
    );
    (_adjustmentsByExam[examId] ??= <ExamMarkAdjustment>[]).add(adjustment);
    final effective = clampEffectiveMark(
      mark.marksObtained! + adjustmentTotalFor(examId, sisStudentId),
      exam.maxMarks,
    );
    _persist();
    return GraceMarkResult(
      adjustment: adjustment,
      effectiveMark: effective,
      maxMarks: exam.maxMarks,
    );
  }

  // ── EXM-D1 — batch report cards (published; effective marks) ─────────────────

  /// EXM-D1 — per-student report cards for [classLabel] over [term], from
  /// PUBLISHED results only. Subject scores use the EFFECTIVE (grace-applied)
  /// mark; non-present lines show their code and are excluded from totals/rank.
  List<ReportCardData> reportCards({
    required String classLabel,
    required String term,
  }) {
    ensureSeeded();
    // Group published results for this class + term by student.
    final byStudent = <String, List<PublishedExamResult>>{};
    for (final r in _publishedByMarkId.values) {
      if (r.termLabel != term) continue;
      final exam = _exams[r.examId];
      if (exam == null) continue;
      if (exam.classLabel != classLabel && exam.grade != classLabel) continue;
      (byStudent[r.sisStudentId] ??= <PublishedExamResult>[]).add(r);
    }

    final cards = <ReportCardData>[];
    for (final entry in byStudent.entries) {
      final results = entry.value;
      var total = 0;
      var totalMax = 0;
      final subjects = <ReportCardSubject>[];
      for (final r in results) {
        final present = r.countsTowardStats;
        final score = present ? r.scoreObtained : null;
        subjects.add(ReportCardSubject(
          subject: r.subject,
          examTitle: r.examTitle,
          score: score,
          maxScore: r.maxScore,
          grade: r.grade,
          statusCode: present ? null : r.statusCode,
        ));
        if (present && score != null) {
          total += score;
          totalMax += r.maxScore;
        }
      }
      final percent = totalMax == 0 ? 0.0 : (total / totalMax) * 100.0;
      cards.add(ReportCardData(
        sisStudentId: entry.key,
        studentName: results.first.studentName,
        classLabel: classLabel,
        termLabel: term,
        subjects: subjects,
        totalScore: total,
        totalMax: totalMax,
        overallPercent: (percent * 100).round() / 100,
        overallGrade:
            totalMax == 0 ? '' : _reportSettings.gradingScale.gradeFor(percent),
        rank: null,
        classSize: 0,
      ));
    }

    // Present-only rank across the class.
    final ranked = cards.where((c) => c.totalMax > 0).toList();
    final withRank = <ReportCardData>[];
    for (final c in cards) {
      if (c.totalMax == 0) {
        withRank.add(c);
        continue;
      }
      final ahead =
          ranked.where((o) => o.overallPercent > c.overallPercent + 1e-9).length;
      withRank.add(ReportCardData(
        sisStudentId: c.sisStudentId,
        studentName: c.studentName,
        classLabel: c.classLabel,
        termLabel: c.termLabel,
        subjects: c.subjects,
        totalScore: c.totalScore,
        totalMax: c.totalMax,
        overallPercent: c.overallPercent,
        overallGrade: c.overallGrade,
        rank: ahead + 1,
        classSize: ranked.length,
      ));
    }
    return withRank;
  }

  // ── EXM-D4 — hall tickets (admit cards) ─────────────────────────────────────

  /// EXM-D4 — per-student hall tickets for one exam (its mark-entry roster).
  List<HallTicket> hallTickets(String examId) {
    ensureSeeded();
    final exam = _exams[examId];
    if (exam == null) {
      throw StateError('Exam not found: $examId');
    }
    return [
      for (final m in marksForExam(examId))
        HallTicket(
          sisStudentId: m.sisStudentId,
          studentName: m.studentName,
          rollNo: m.rollNo.isEmpty ? null : m.rollNo,
          classLabel: exam.classLabel,
          subject: exam.subject,
          examTitle: exam.title,
          dateLabel: exam.dateLabel,
          timeLabel: exam.timeLabel,
          venueLabel: exam.venueLabel,
          maxMarks: exam.maxMarks,
          instructions: kHallTicketInstructions,
        ),
    ];
  }

  // ── EXM-D5 — seating arrangement ────────────────────────────────────────────

  /// EXM-D5 — (re)generates the seating plan for an exam and stores it.
  SeatingPlan generateSeating(
    String examId, {
    int capacity = kDefaultSeatingRoomCapacity,
  }) {
    ensureSeeded();
    final exam = _exams[examId];
    if (exam == null) {
      throw StateError('Exam not found: $examId');
    }
    final roster = marksForExam(examId);
    if (roster.isEmpty) {
      throw StateError('No students provisioned for exam: $examId');
    }
    final candidates = [
      for (final m in roster)
        SeatingCandidate(
          sisStudentId: m.sisStudentId,
          studentName: m.studentName,
          rollNo: m.rollNo.isEmpty ? null : m.rollNo,
          classLabel: exam.classLabel,
        ),
    ];
    final plan = ExamSeatingPlanner.plan(
      examId: examId,
      candidates: candidates,
      capacity: capacity,
    );
    _seatingByExam[examId] = plan;
    _persist();
    return plan;
  }

  /// EXM-D5 — the current seating plan for an exam (empty when none generated).
  SeatingPlan seatingFor(String examId) {
    ensureSeeded();
    return _seatingByExam[examId] ??
        SeatingPlan(
          examId: examId,
          roomCapacity: kDefaultSeatingRoomCapacity,
          rooms: const [],
        );
  }

  // --- Exam-session remarks ---
  // Two independent slots per (student, exam session): the class-teacher remark
  // and the leadership (principal / vice-principal) remark, so both can be shown
  // on the same report card without overwriting each other.

  String _remarkKey(
    String examId,
    String sisStudentId, {
    bool leadership = false,
  }) =>
      '$examId|$sisStudentId|${leadership ? 'leadership' : 'teacher'}';

  /// The remark for a (student, exam session) in the requested slot. Defaults to
  /// the class-teacher slot; pass [leadership] true for the principal/VP remark.
  ExamRemark? remarkFor(
    String examId,
    String sisStudentId, {
    bool leadership = false,
  }) {
    ensureSeeded();
    return _remarksByKey[_remarkKey(examId, sisStudentId, leadership: leadership)];
  }

  List<ExamRemark> remarksForExam(String examId) {
    ensureSeeded();
    return _remarksByKey.values
        .where((r) => r.examId == examId)
        .toList(growable: false);
  }

  /// Hydrates the local cache with canonical remarks fetched from the backend,
  /// keyed by their slot. Unlike [upsertRemark] this does NOT append a new
  /// audit-trail revision — it stores the remark (and its existing history) as
  /// returned by the server, so synchronous reads reflect cross-device state.
  void cacheRemarks(Iterable<ExamRemark> remarks) {
    ensureSeeded();
    for (final remark in remarks) {
      final key = _remarkKey(
        remark.examId,
        remark.sisStudentId,
        leadership: remark.authorRole.isLeadership,
      );
      _remarksByKey[key] = remark;
    }
    _persist();
  }

  /// Creates or edits the remark for a (student, exam session). Appends to the
  /// audit trail and bumps updatedAt. [timestamp] is injectable for tests.
  ExamRemark upsertRemark({
    required String examId,
    required String sisStudentId,
    required String text,
    required String authorId,
    required String authorName,
    ExamRemarkAuthorRole authorRole = ExamRemarkAuthorRole.classTeacher,
    String? timestamp,
  }) {
    ensureSeeded();
    final now = timestamp ?? DateTime.now().toUtc().toIso8601String();
    final key = _remarkKey(
      examId,
      sisStudentId,
      leadership: authorRole.isLeadership,
    );
    final existing = _remarksByKey[key];
    final revision = ExamRemarkRevision(
      text: text,
      authorId: authorId,
      authorName: authorName,
      authorRole: authorRole,
      timestamp: now,
    );
    final remark = ExamRemark(
      examId: examId,
      sisStudentId: sisStudentId,
      text: text,
      authorId: authorId,
      authorName: authorName,
      authorRole: authorRole,
      createdAt: existing?.createdAt ?? now,
      updatedAt: now,
      history: [...?existing?.history, revision],
    );
    _remarksByKey[key] = remark;
    _persist();
    return remark;
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

  static Map<String, dynamic> _reportSettingsToJson(ExamReportSettings s) => {
        'gradingScale': s.gradingScale.name,
        'showRankToParents': s.showRankToParents,
        'suggestedTerms': s.suggestedTerms,
      };

  static ExamReportSettings _reportSettingsFromJson(Map<String, dynamic> json) {
    final scaleName = json['gradingScale'] as String?;
    final scale = ExamGradingScale.presets.firstWhere(
      (s) => s.name == scaleName,
      orElse: () => ExamGradingScale.standard,
    );
    final terms = (json['suggestedTerms'] as List?)
            ?.map((e) => '$e')
            .toList(growable: false) ??
        const <String>[];
    return ExamReportSettings(
      gradingScale: scale,
      showRankToParents: json['showRankToParents'] as bool? ?? false,
      suggestedTerms: terms,
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
        'marksEntryDeadline': exam.marksEntryDeadline?.toIso8601String(),
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
      marksEntryDeadline: (json['marksEntryDeadline'] as String?) != null
          ? DateTime.tryParse(json['marksEntryDeadline'] as String)
          : null,
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
        'status': mark.status.wire,
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
      status: ExamMarkStatus.fromWire(json['status'] as String?),
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
        'status': result.status.wire,
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
      scoreObtained: json['scoreObtained'] as int? ?? 0,
      maxScore: json['maxScore'] as int,
      grade: json['grade'] as String,
      subject: json['subject'] as String,
      status: ExamMarkStatus.fromWire(json['status'] as String?),
    );
  }
}
