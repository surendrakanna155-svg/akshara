import '../repositories/mock/mock_canonical_student_registry.dart';
import '../../features/parent/homework/homework_models.dart';
import '../../features/student_app/homework/homework_models.dart';
import '../../features/teacher/homework/homework_models.dart';

/// Canonical homework assignment authored by a teacher — shared across personas.
class SchoolHomeworkRecord {
  const SchoolHomeworkRecord({
    required this.id,
    required this.grade,
    required this.section,
    required this.subject,
    required this.title,
    required this.dueLabel,
    required this.teacherName,
    required this.createdAt,
    this.targetSisStudentIds = const [],
    this.status = SchoolHomeworkStatus.pending,
  });

  final String id;
  final String grade;
  final String section;
  final String subject;
  final String title;
  final String dueLabel;
  final String teacherName;
  final DateTime createdAt;
  final List<String> targetSisStudentIds;
  final SchoolHomeworkStatus status;

  String get classLabel => '$grade-$section';

  bool appliesToStudent(CanonicalStudentRecord student) {
    if (student.grade != grade || student.section != section) return false;
    if (targetSisStudentIds.isEmpty) return true;
    return targetSisStudentIds.contains(student.sisStudentId);
  }

  SchoolHomeworkRecord copyWith({SchoolHomeworkStatus? status}) {
    return SchoolHomeworkRecord(
      id: id,
      grade: grade,
      section: section,
      subject: subject,
      title: title,
      dueLabel: dueLabel,
      teacherName: teacherName,
      createdAt: createdAt,
      targetSisStudentIds: targetSisStudentIds,
      status: status ?? this.status,
    );
  }
}

enum SchoolHomeworkStatus { pending, submitted, overdue }

/// In-memory store for teacher-created homework visible to parent/student apps.
final class SchoolHomeworkStore {
  SchoolHomeworkStore._();

  static final SchoolHomeworkStore instance = SchoolHomeworkStore._();

  final List<SchoolHomeworkRecord> _records = [];
  int _idSeq = 0;

  void reset() {
    _records.clear();
    _reviews.clear();
    _idSeq = 0;
  }

  List<SchoolHomeworkRecord> allRecords() => List.unmodifiable(_records);

  List<SchoolHomeworkRecord> forStudent(String sisStudentId) {
    final student = MockCanonicalStudentRegistry.byId(sisStudentId);
    if (student == null) return const [];
    return _records.where((r) => r.appliesToStudent(student)).toList(growable: false);
  }

  List<SchoolHomeworkRecord> forClass(String grade, String section) {
    return _records
        .where((r) => r.grade == grade && r.section == section)
        .toList(growable: false);
  }

  SchoolHomeworkRecord create({
    required String grade,
    required String section,
    required String subject,
    required String title,
    required String dueLabel,
    required String teacherName,
    List<String> targetSisStudentIds = const [],
  }) {
    final record = SchoolHomeworkRecord(
      id: 'hw_store_${++_idSeq}',
      grade: grade,
      section: section,
      subject: subject,
      title: title,
      dueLabel: dueLabel,
      teacherName: teacherName,
      createdAt: DateTime.now(),
      targetSisStudentIds: targetSisStudentIds,
    );
    _records.insert(0, record);
    return record;
  }

  void markSubmitted(String homeworkId) {
    final index = _records.indexWhere((r) => r.id == homeworkId);
    if (index < 0) return;
    _records[index] = _records[index].copyWith(
      status: SchoolHomeworkStatus.submitted,
    );
  }

  // --- Teacher review/grade per (homework, student), shared to parent/student ---

  final Map<String, ({String grade, String? comment})> _reviews = {};

  String _reviewKey(String homeworkId, String sisStudentId) =>
      '$homeworkId|$sisStudentId';

  void recordReview({
    required String homeworkId,
    required String sisStudentId,
    required String grade,
    String? comment,
  }) {
    _reviews[_reviewKey(homeworkId, sisStudentId)] =
        (grade: grade, comment: comment);
  }

  ({String grade, String? comment})? reviewFor(
    String homeworkId,
    String sisStudentId,
  ) =>
      _reviews[_reviewKey(homeworkId, sisStudentId)];

  int completionPercentForStudent(String sisStudentId) {
    final items = forStudent(sisStudentId);
    if (items.isEmpty) return -1;
    final submitted =
        items.where((i) => i.status == SchoolHomeworkStatus.submitted).length;
    return ((submitted / items.length) * 100).round();
  }

  TeacherHomeworkAssignment toTeacherAssignment(SchoolHomeworkRecord record) {
    final students = record.targetSisStudentIds.isEmpty
        ? MockCanonicalStudentRegistry.forClass(record.grade, record.section)
        : [
            for (final id in record.targetSisStudentIds)
              if (MockCanonicalStudentRegistry.byId(id) != null)
                MockCanonicalStudentRegistry.byId(id)!,
          ];
    return TeacherHomeworkAssignment(
      id: record.id,
      title: record.title,
      classLabel: record.classLabel,
      dueLabel: record.dueLabel,
      submissions: [
        for (final student in students)
          HomeworkSubmission(
            id: '${record.id}_${student.sisStudentId}',
            studentName: student.studentName,
            classLabel: record.classLabel,
            title: record.title,
            submittedLabel: record.status == SchoolHomeworkStatus.submitted
                ? 'Submitted'
                : 'Not submitted',
            status: record.status == SchoolHomeworkStatus.submitted
                ? HomeworkReviewStatus.reviewed
                : HomeworkReviewStatus.pending,
          ),
      ],
    );
  }

  ParentHomeworkItem toParentItem(
    SchoolHomeworkRecord record,
    String localizedTitle, {
    String? sisStudentId,
  }) {
    final review =
        sisStudentId == null ? null : reviewFor(record.id, sisStudentId);
    return ParentHomeworkItem(
      id: record.id,
      subject: record.subject,
      title: localizedTitle,
      dueLabel: record.dueLabel,
      // A per-student review is the terminal lifecycle state: once the teacher
      // grades this child's work it reads "Reviewed", regardless of the coarse
      // class-level submission status. Only the reviewed student flips.
      status: review != null
          ? ParentHomeworkStatus.reviewed
          : switch (record.status) {
              SchoolHomeworkStatus.submitted => ParentHomeworkStatus.submitted,
              SchoolHomeworkStatus.overdue => ParentHomeworkStatus.overdue,
              SchoolHomeworkStatus.pending => ParentHomeworkStatus.pending,
            },
      reviewGrade: review?.grade,
      reviewComment: review?.comment,
    );
  }

  StudentHomeworkItem toStudentItem(
    SchoolHomeworkRecord record,
    String localizedTitle, {
    String? sisStudentId,
  }) {
    final review =
        sisStudentId == null ? null : reviewFor(record.id, sisStudentId);
    return StudentHomeworkItem(
      id: record.id,
      subject: record.subject,
      title: localizedTitle,
      dueLabel: record.dueLabel,
      // Terminal "Reviewed" state once the teacher grades this student's work
      // (per-student, so classmates stay at submitted/pending until graded).
      status: review != null
          ? StudentHomeworkStatus.reviewed
          : switch (record.status) {
              SchoolHomeworkStatus.submitted => StudentHomeworkStatus.submitted,
              SchoolHomeworkStatus.overdue => StudentHomeworkStatus.overdue,
              SchoolHomeworkStatus.pending => StudentHomeworkStatus.pending,
            },
      attachmentLabel: null,
      reviewGrade: review?.grade,
      reviewComment: review?.comment,
    );
  }

  static ({String grade, String section}) parseClassLabel(String classLabel) {
    final parts = classLabel.split('-');
    if (parts.length >= 2) {
      return (grade: parts[0].trim(), section: parts[1].trim());
    }
    return (grade: classLabel.trim(), section: 'A');
  }
}
