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
    this.attendancePercent,
    this.attendanceTrend,
    this.subjectPerformance = const {},
    this.homeworkCompletionPercent,
    this.behaviorIncidentCount,
    this.feePendingLabel,
    required this.riskLevel,
    required this.riskFactors,
    required this.communicationHistoryCount,
    required this.pendingConcernCount,
  });

  final String sisStudentId;
  final String studentName;
  final String classLabel;
  final String rollNo;

  // E2E-011 — every metric below is NULLABLE and null means "not available".
  // The screen renders "Not available" for a null; it never substitutes a
  // constant, a fixture, or a value belonging to a different student.
  final int? attendancePercent;
  final String? attendanceTrend;
  final Map<String, String> subjectPerformance;
  final int? homeworkCompletionPercent;
  final int? behaviorIncidentCount;
  final String? feePendingLabel;
  final StudentRiskLevel riskLevel;
  final List<String> riskFactors;
  final int communicationHistoryCount;
  final int pendingConcernCount;
}

/// Risk-dossier helpers that carry NO fabricated data.
///
/// E2E-011: the fixture-backed composition that used to live here (constants
/// 92 / 75 / 80, `MockAttendanceSyncStore`, the seeded demo exam and the
/// `acct_ravi ? '₹4,200 due' : 'No dues'` fee statement) has moved to
/// `lib/core/repositories/mock/mock_student_risk_fixtures.dart`. The production
/// dossier is built by `teacherStudentRiskSnapshotProvider` from the live
/// intelligence backend, and every metric that is not yet wired to a real
/// source renders as an honest unknown.
abstract final class TeacherStudentRiskService {
  static String templatePreview(StudentAttentionItem item) {
    if (item.suggestedReason == null) return '';
    return TeacherParentTemplates.resolve(
      reason: item.suggestedReason!,
      tone: item.suggestedTone,
      studentName: item.studentName,
    );
  }
}
