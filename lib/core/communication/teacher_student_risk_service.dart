import '../exams/exam_administration_store.dart';
import '../homework/school_homework_store.dart';
import '../repositories/mock/mock_attendance_sync_store.dart';
import '../repositories/mock/mock_canonical_student_registry.dart';
import 'parent_communication_governance.dart';
import 'parent_communication_models.dart';
import 'parent_communication_store.dart';
import 'subject_teacher_concern_store.dart';
import 'teacher_parent_templates.dart';

/// Risk level for class-teacher prioritization.
enum StudentRiskLevel { low, medium, high }

/// Structured alert for "Students requiring attention today".
class StudentAttentionItem {
  const StudentAttentionItem({
    required this.sisStudentId,
    required this.studentName,
    required this.classLabel,
    required this.summary,
    required this.riskLevel,
    required this.riskFactors,
    this.suggestedReason,
    this.suggestedTone = ParentCommunicationTone.polite,
  });

  final String sisStudentId;
  final String studentName;
  final String classLabel;
  final String summary;
  final StudentRiskLevel riskLevel;
  final List<String> riskFactors;
  final ParentCommunicationReason? suggestedReason;
  final ParentCommunicationTone suggestedTone;
}

/// Mobile student 360 risk snapshot for class teacher.
class TeacherStudentRiskSnapshot {
  const TeacherStudentRiskSnapshot({
    required this.sisStudentId,
    required this.studentName,
    required this.classLabel,
    required this.rollNo,
    required this.attendancePercent,
    required this.attendanceTrend,
    required this.subjectPerformance,
    required this.homeworkCompletionPercent,
    required this.behaviorIncidentCount,
    required this.feePendingLabel,
    required this.riskLevel,
    required this.riskFactors,
    required this.communicationHistoryCount,
    required this.pendingConcernCount,
  });

  final String sisStudentId;
  final String studentName;
  final String classLabel;
  final String rollNo;
  final int attendancePercent;
  final String attendanceTrend;
  final Map<String, String> subjectPerformance;
  final int homeworkCompletionPercent;
  final int behaviorIncidentCount;
  final String feePendingLabel;
  final StudentRiskLevel riskLevel;
  final List<String> riskFactors;
  final int communicationHistoryCount;
  final int pendingConcernCount;
}

/// Identifies at-risk students and builds class-teacher 360 snapshots.
abstract final class TeacherStudentRiskService {
  static List<StudentAttentionItem> attentionForClass(
    TeacherTeachingContext context,
  ) {
    final classLabel = context.classTeacherClassLabel;
    if (classLabel == null) return const [];

    final students = MockCanonicalStudentRegistry.forClass(
      context.classTeacherGrade!,
      context.classTeacherSection!,
    );

    return [
      for (final student in students)
        if (_snapshotFor(student).riskLevel != StudentRiskLevel.low)
          _attentionFrom(_snapshotFor(student)),
    ]..sort((a, b) => _riskRank(b.riskLevel).compareTo(_riskRank(a.riskLevel)));
  }

  static TeacherStudentRiskSnapshot snapshotForStudent(
    String sisStudentId,
  ) {
    final student = MockCanonicalStudentRegistry.byId(sisStudentId);
    if (student == null) {
      throw StateError('Student not found: $sisStudentId');
    }
    return _snapshotFor(student);
  }

  static TeacherStudentRiskSnapshot _snapshotFor(
    CanonicalStudentRecord student,
  ) {
    final examStore = ExamAdministrationStore.instance..ensureSeeded();
    final published = examStore.resultsForStudent(student.sisStudentId);

    final syncAttendance = MockAttendanceSyncStore.instance.attendancePercent();
    var attendance = syncAttendance >= 0 ? syncAttendance : 92;
    var marks = 75;
    if (published.isNotEmpty) {
      final totalPercent = published
          .map((r) => (r.scoreObtained / r.maxScore * 100).round())
          .toList();
      marks = totalPercent.reduce((a, b) => a + b) ~/ totalPercent.length;
      if (syncAttendance < 0) {
        attendance = marks >= 60 ? 88 : 74;
      }
    }

    final homeworkPercent =
        SchoolHomeworkStore.instance.completionPercentForStudent(
      student.sisStudentId,
    );
    final homework = homeworkPercent >= 0 ? homeworkPercent : 80;
    final behavior = SubjectTeacherConcernStore.instance
        .forStudent(student.sisStudentId)
        .where((c) => c.category == SubjectConcernCategory.disciplineObservation)
        .length;
    final feePending = student.feeAccountId == 'acct_ravi'
        ? '₹4,200 due'
        : 'No dues';

    final factors = <String>[];
    if (attendance < 80) factors.add('attendance');
    if (marks < 60) factors.add('declining marks');
    if (homework < 70) factors.add('homework gaps');
    if (behavior > 0) factors.add('behaviour incident');
    if (feePending.contains('due')) factors.add('fee concern');

    final pendingConcerns = SubjectTeacherConcernStore.instance
        .forStudent(student.sisStudentId)
        .where((c) => c.isPending)
        .length;

    if (pendingConcerns > 0) factors.add('subject teacher flag');

    final riskLevel = _riskFrom(factors.length, attendance, marks);
    final commCount = _communicationCount(student.sisStudentId);

    final subjectPerformance = <String, String>{};
    for (final result in published) {
      final percent = (result.scoreObtained / result.maxScore * 100).round();
      subjectPerformance[result.subject] =
          '$percent% · ${percent < 60 ? 'Needs support' : 'On track'}';
    }
    if (subjectPerformance.isEmpty) {
      subjectPerformance['Mathematics'] =
          '$marks% · ${marks < 60 ? 'Below average' : 'On track'}';
    }

    return TeacherStudentRiskSnapshot(
      sisStudentId: student.sisStudentId,
      studentName: student.studentName,
      classLabel: student.classLabel,
      rollNo: student.rollNo,
      attendancePercent: attendance,
      attendanceTrend: attendance < 80 ? 'Declining' : 'Stable',
      subjectPerformance: subjectPerformance,
      homeworkCompletionPercent: homework,
      behaviorIncidentCount: behavior,
      feePendingLabel: feePending,
      riskLevel: riskLevel,
      riskFactors: factors,
      communicationHistoryCount: commCount,
      pendingConcernCount: pendingConcerns,
    );
  }

  static StudentAttentionItem _attentionFrom(TeacherStudentRiskSnapshot snap) {
    ParentCommunicationReason? reason;
    ParentCommunicationTone tone = ParentCommunicationTone.polite;
    if (snap.riskFactors.contains('attendance')) {
      reason = ParentCommunicationReason.attendanceLow;
      tone = ParentCommunicationTone.concerned;
    } else if (snap.riskFactors.contains('declining marks')) {
      reason = ParentCommunicationReason.marksLow;
      tone = ParentCommunicationTone.encouragement;
    } else if (snap.riskFactors.contains('homework gaps')) {
      reason = ParentCommunicationReason.homeworkMissing;
      tone = ParentCommunicationTone.gentleReminder;
    } else if (snap.riskFactors.contains('behaviour incident')) {
      reason = ParentCommunicationReason.disciplineIssue;
      tone = ParentCommunicationTone.informational;
    } else if (snap.riskFactors.contains('fee concern')) {
      reason = ParentCommunicationReason.feeReminder;
      tone = ParentCommunicationTone.friendlyReminder;
    } else if (snap.pendingConcernCount > 0) {
      reason = ParentCommunicationReason.generalProgress;
    }

    return StudentAttentionItem(
      sisStudentId: snap.sisStudentId,
      studentName: snap.studentName,
      classLabel: snap.classLabel,
      summary: snap.riskFactors.isEmpty
          ? 'Review recommended'
          : snap.riskFactors.join(' · '),
      riskLevel: snap.riskLevel,
      riskFactors: snap.riskFactors,
      suggestedReason: reason,
      suggestedTone: tone,
    );
  }

  static int _communicationCount(String sisStudentId) {
    return ParentCommunicationStore.instance
        .timelineForStudent(sisStudentId)
        .length;
  }

  static StudentRiskLevel _riskFrom(int factorCount, int attendance, int marks) {
    if (factorCount >= 3 || attendance < 75 || marks < 50) {
      return StudentRiskLevel.high;
    }
    if (factorCount >= 1) return StudentRiskLevel.medium;
    return StudentRiskLevel.low;
  }

  static int _riskRank(StudentRiskLevel level) => switch (level) {
        StudentRiskLevel.high => 3,
        StudentRiskLevel.medium => 2,
        StudentRiskLevel.low => 1,
      };

  static String templatePreview(StudentAttentionItem item) {
    if (item.suggestedReason == null) return '';
    return TeacherParentTemplates.resolve(
      reason: item.suggestedReason!,
      tone: item.suggestedTone,
      studentName: item.studentName,
    );
  }
}
