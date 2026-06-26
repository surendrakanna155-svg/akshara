import '../repositories/mock/mock_canonical_student_registry.dart';

/// Whether the logged-in teacher may message parents directly or only flag concerns.
enum TeacherParentCommsRole {
  classTeacher,
  subjectTeacher,
}

/// Teaching assignment context for parent-communication governance.
class TeacherTeachingContext {
  const TeacherTeachingContext({
    required this.teacherId,
    required this.teacherName,
    required this.commsRole,
    required this.primarySubject,
    this.classTeacherGrade,
    this.classTeacherSection,
    this.teachingClassLabels = const [],
  });

  final String teacherId;
  final String teacherName;
  final TeacherParentCommsRole commsRole;
  final String primarySubject;
  final String? classTeacherGrade;
  final String? classTeacherSection;
  final List<String> teachingClassLabels;

  bool get isClassTeacher => commsRole == TeacherParentCommsRole.classTeacher;

  String? get classTeacherClassLabel {
    if (classTeacherGrade == null || classTeacherSection == null) return null;
    return '$classTeacherGrade-$classTeacherSection';
  }

  /// App-bar subtitle for teacher screens: "Name · Subject" (or just the name
  /// when no subject is assigned). Derived from the logged-in teacher (TCH-4).
  String get appBarSubtitle =>
      primarySubject.isEmpty ? teacherName : '$teacherName · $primarySubject';

  bool isClassTeacherForStudent(CanonicalStudentRecord student) {
    if (!isClassTeacher) return false;
    return student.grade == classTeacherGrade &&
        student.section == classTeacherSection;
  }

  bool teachesStudent(CanonicalStudentRecord student) {
    final label = student.classLabel;
    if (isClassTeacherForStudent(student)) return true;
    return teachingClassLabels.contains(label);
  }

  /// Demo persona: Priya Sharma — class teacher 8-A, mathematics subject teacher.
  factory TeacherTeachingContext.demoClassTeacher() {
    return const TeacherTeachingContext(
      teacherId: 'teacher_priya',
      teacherName: 'Priya Sharma',
      commsRole: TeacherParentCommsRole.classTeacher,
      primarySubject: 'Mathematics',
      classTeacherGrade: '8',
      classTeacherSection: 'A',
      teachingClassLabels: ['8-A', '9-B'],
    );
  }

  factory TeacherTeachingContext.demoSubjectTeacher() {
    return const TeacherTeachingContext(
      teacherId: 'teacher_anil',
      teacherName: 'Anil Verma',
      commsRole: TeacherParentCommsRole.subjectTeacher,
      primarySubject: 'Science',
      teachingClassLabels: ['8-A', '8-B'],
    );
  }
}

/// Governance rules for real-school parent communication ownership.
abstract final class ParentCommunicationGovernance {
  static bool canSendParentCommunication(
    TeacherTeachingContext context,
    CanonicalStudentRecord student,
  ) {
    return context.isClassTeacherForStudent(student);
  }

  static bool canFlagConcern(
    TeacherTeachingContext context,
    CanonicalStudentRecord student,
  ) {
    if (context.isClassTeacherForStudent(student)) {
      return true;
    }
    return context.commsRole == TeacherParentCommsRole.subjectTeacher &&
        context.teachesStudent(student);
  }

  static void assertCanSend(
    TeacherTeachingContext context,
    CanonicalStudentRecord student,
  ) {
    if (!canSendParentCommunication(context, student)) {
      throw ParentCommunicationGovernanceException(
        'Only the class teacher may send parent communication for ${student.studentName}. '
        'Subject teachers should flag a concern for class teacher review.',
      );
    }
  }

  static void assertCanFlag(
    TeacherTeachingContext context,
    CanonicalStudentRecord student,
  ) {
    if (!canFlagConcern(context, student)) {
      throw ParentCommunicationGovernanceException(
        'You are not assigned to flag concerns for ${student.studentName}.',
      );
    }
  }
}

class ParentCommunicationGovernanceException implements Exception {
  ParentCommunicationGovernanceException(this.message);
  final String message;

  @override
  String toString() => message;
}
