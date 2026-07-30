/// Demo-lane composition of the class-teacher student-risk dossier.
///
/// **E2E-011 (P0).** This code used to live in
/// `lib/core/communication/teacher_student_risk_service.dart` — a *production*
/// file wired into a live route. It composed every metric row on the Student
/// risk screen out of fixtures and constants:
///
///   * attendance = `MockAttendanceSyncStore.attendancePercent()`, else the
///     constant `92` (or `88`/`74` depending on marks),
///   * marks = the constant `75`, overridden only by the **seeded demo exam**
///     (`exam_math_8a`, "Unit Test — Mathematics", mock 8-A roster),
///   * homework = `SchoolHomeworkStore`, else the constant `80`,
///   * fees = `student.feeAccountId == 'acct_ravi' ? '₹4,200 due' : 'No dues'`.
///
/// A class teacher preparing for a parent meeting was shown "No dues" and
/// "92% attendance" for a student who might owe fees and be at 55% — fabricated
/// financial and attendance claims, which the register's standing rule makes
/// P0. The live `/intelligence/risk/*` merge replaced only the risk level,
/// score and reasons; every displayed metric still came from this base.
///
/// It now lives in the mock lane, where it belongs: it is reachable only from
/// `TeacherDashboardData.mock()` (i.e. only when a mock repository is resolved).
/// The production path is `teacherStudentRiskSnapshotProvider`, which sources
/// the verdict from the live intelligence backend and renders every unwired
/// metric as an honest unknown.
library;

import '../../communication/parent_communication_governance.dart';
import '../../communication/parent_communication_models.dart';
import '../../communication/parent_communication_store.dart';
import '../../communication/subject_teacher_concern_store.dart';
import '../../communication/teacher_parent_templates.dart';
import '../../communication/teacher_student_risk_service.dart';
import '../../exams/exam_administration_store.dart';
import '../../homework/school_homework_store.dart';
import 'mock_attendance_sync_store.dart';
import 'mock_canonical_student_registry.dart';

/// Fixture-backed risk snapshots for the demo/QA personas. NOT a production
/// data source — see the library doc above.
abstract final class MockStudentRiskFixtures {
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
        if (snapshotFor(student).riskLevel != StudentRiskLevel.low)
          attentionFrom(snapshotFor(student)),
    ]..sort((a, b) => _riskRank(b.riskLevel).compareTo(_riskRank(a.riskLevel)));
  }

  static TeacherStudentRiskSnapshot snapshotForStudent(String sisStudentId) {
    final student = MockCanonicalStudentRegistry.byId(sisStudentId);
    if (student == null) {
      throw StateError('Student not found: $sisStudentId');
    }
    return snapshotFor(student);
  }

  static TeacherStudentRiskSnapshot snapshotFor(
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
    final feePending =
        student.feeAccountId == 'acct_ravi' ? '₹4,200 due' : 'No dues';

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
    final commCount = ParentCommunicationStore.instance
        .timelineForStudent(student.sisStudentId)
        .length;

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

  static StudentAttentionItem attentionFrom(TeacherStudentRiskSnapshot snap) {
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
}
