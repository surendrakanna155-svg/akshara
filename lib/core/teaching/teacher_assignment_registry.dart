import '../repositories/mock/mock_canonical_student_registry.dart';
import '../communication/parent_communication_governance.dart';

/// Subject teaching assignment for a grade-section.
class TeacherSubjectAssignment {
  const TeacherSubjectAssignment({
    required this.subject,
    required this.grade,
    required this.section,
  });

  final String subject;
  final String grade;
  final String section;

  String get classLabel => '$grade-$section';
}

/// HR + SIS aligned teacher assignment record.
class TeacherAssignmentRecord {
  const TeacherAssignmentRecord({
    required this.teacherId,
    required this.teacherName,
    this.classTeacherGrade,
    this.classTeacherSection,
    this.subjectAssignments = const [],
  });

  final String teacherId;
  final String teacherName;
  final String? classTeacherGrade;
  final String? classTeacherSection;
  final List<TeacherSubjectAssignment> subjectAssignments;

  bool get isClassTeacher =>
      classTeacherGrade != null && classTeacherSection != null;

  List<String> get teachingClassLabels {
    final labels = <String>{};
    if (isClassTeacher) {
      labels.add('$classTeacherGrade-$classTeacherSection');
    }
    for (final assignment in subjectAssignments) {
      labels.add(assignment.classLabel);
    }
    return labels.toList(growable: false);
  }
}

/// Resolves class-teacher and subject-teacher roles from SIS/HR seed data.
abstract final class TeacherAssignmentRegistry {
  static const String priyaSharmaId = 'HR-EMP-101';
  static const String mrPatelId = 'HR-EMP-103';
  static const String mrsRaoId = 'HR-EMP-102';

  static const List<TeacherAssignmentRecord> assignments = [
    TeacherAssignmentRecord(
      teacherId: priyaSharmaId,
      teacherName: 'Priya Sharma',
      classTeacherGrade: '8',
      classTeacherSection: 'A',
      subjectAssignments: [
        TeacherSubjectAssignment(subject: 'Mathematics', grade: '8', section: 'A'),
        TeacherSubjectAssignment(subject: 'Mathematics', grade: '9', section: 'B'),
      ],
    ),
    TeacherAssignmentRecord(
      teacherId: mrPatelId,
      teacherName: 'Mr. Patel',
      subjectAssignments: [
        TeacherSubjectAssignment(subject: 'Science', grade: '8', section: 'A'),
        TeacherSubjectAssignment(subject: 'Science', grade: '8', section: 'B'),
        TeacherSubjectAssignment(subject: 'Science', grade: '10', section: 'A'),
      ],
    ),
    TeacherAssignmentRecord(
      teacherId: mrsRaoId,
      teacherName: 'Mrs. Rao',
      subjectAssignments: [
        TeacherSubjectAssignment(subject: 'English', grade: '8', section: 'A'),
        TeacherSubjectAssignment(subject: 'English', grade: '7', section: 'A'),
      ],
    ),
  ];

  static TeacherAssignmentRecord? byTeacherId(String teacherId) {
    for (final record in assignments) {
      if (record.teacherId == teacherId) return record;
    }
    return null;
  }

  /// Whether the teacher (resolved by [teacherId], falling back to
  /// [teacherName]) is assigned to teach [subject] for [grade]/[section].
  ///
  /// Used to scope a subject teacher's exam lists to only the class-sections
  /// they actually teach — a Science teacher across 8-A/8-B/10-A sees exactly
  /// those Science sessions, not every exam in the school. Class-teacher status
  /// is intentionally ignored: marks entry follows the *subject* assignment, so
  /// the class teacher of 8-A still only enters marks for the subjects they
  /// teach. Fails open (returns `true`) for an unknown teacher so an
  /// unrecognised context never silently hides everything.
  static bool teachesSubjectClass({
    String? teacherId,
    String? teacherName,
    required String subject,
    required String grade,
    required String section,
  }) {
    final record = (teacherId != null ? byTeacherId(teacherId) : null) ??
        (teacherName != null ? byTeacherName(teacherName) : null);
    if (record == null) return true;
    return record.subjectAssignments.any(
      (a) => a.subject == subject && a.grade == grade && a.section == section,
    );
  }

  static TeacherAssignmentRecord? byTeacherName(String teacherName) {
    final normalized = teacherName.trim().toLowerCase();
    for (final record in assignments) {
      if (record.teacherName.toLowerCase() == normalized) return record;
    }
    return null;
  }

  static TeacherAssignmentRecord? classTeacherForClass(
    String grade,
    String section,
  ) {
    for (final record in assignments) {
      if (record.classTeacherGrade == grade &&
          record.classTeacherSection == section) {
        return record;
      }
    }
    return null;
  }

  static List<TeacherAssignmentRecord> subjectTeachersForClass(
    String grade,
    String section,
  ) {
    return [
      for (final record in assignments)
        if (!record.isClassTeacher ||
            record.classTeacherGrade != grade ||
            record.classTeacherSection != section)
          if (record.subjectAssignments.any(
            (a) => a.grade == grade && a.section == section,
          ))
            record,
    ];
  }

  static TeacherTeachingContext resolveContext({
    required String teacherId,
    required String teacherName,
    bool preferSubjectTeacherRole = false,
  }) {
    final record = byTeacherId(teacherId) ?? byTeacherName(teacherName);
    if (record == null) {
      return TeacherTeachingContext.demoClassTeacher();
    }

    final primarySubject = record.subjectAssignments.isNotEmpty
        ? record.subjectAssignments.first.subject
        : 'General';

    if (record.isClassTeacher && !preferSubjectTeacherRole) {
      return TeacherTeachingContext(
        teacherId: record.teacherId,
        teacherName: record.teacherName,
        commsRole: TeacherParentCommsRole.classTeacher,
        primarySubject: primarySubject,
        classTeacherGrade: record.classTeacherGrade,
        classTeacherSection: record.classTeacherSection,
        teachingClassLabels: record.teachingClassLabels,
      );
    }

    return TeacherTeachingContext(
      teacherId: record.teacherId,
      teacherName: record.teacherName,
      commsRole: TeacherParentCommsRole.subjectTeacher,
      primarySubject: primarySubject,
      teachingClassLabels: record.teachingClassLabels,
    );
  }

  static CanonicalStudentRecord? studentBySisId(String sisStudentId) =>
      MockCanonicalStudentRegistry.byId(sisStudentId);
}
