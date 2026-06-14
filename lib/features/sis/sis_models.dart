import 'package:flutter/material.dart';

import '../admissions/admissions_models.dart';

/// SIS sub-module destinations (SIS-01 → SIS-05 Phase 1).
enum SisScreen {
  dashboard,
  registry,
  academicAssignment,
  admissionsConversion,
  promotion,
  reshuffle,
  sectionBalance,
  continuity;

  String get label => switch (this) {
        SisScreen.dashboard => 'Dashboard',
        SisScreen.registry => 'Student Registry',
        SisScreen.academicAssignment => 'Academic Assignment',
        SisScreen.admissionsConversion => 'Admissions Conversion',
        SisScreen.promotion => 'Promotion',
        SisScreen.reshuffle => 'Reshuffle',
        SisScreen.sectionBalance => 'Section Balance',
        SisScreen.continuity => 'Continuity',
      };
}

enum SisStudentStatus { active, prospect, transferred, exited, alumni }

enum SisGender { male, female, other }

@immutable
class SisKpi {
  const SisKpi({
    required this.id,
    required this.value,
    required this.label,
    required this.icon,
    required this.accentName,
    this.detail,
  });

  final String id;
  final String value;
  final String label;
  final IconData icon;
  final String accentName;
  final String? detail;
}

@immutable
class DistributionSegment {
  const DistributionSegment({
    required this.label,
    required this.count,
    required this.percent,
  });

  final String label;
  final int count;
  final double percent;
}

@immutable
class RecentEnrollment {
  const RecentEnrollment({
    required this.id,
    required this.studentName,
    required this.admissionNumber,
    required this.classLabel,
    required this.section,
    required this.enrolledAt,
    required this.status,
  });

  final String id;
  final String studentName;
  final String admissionNumber;
  final String classLabel;
  final String section;
  final String enrolledAt;
  final SisStudentStatus status;
}

@immutable
class SisDashboardData {
  const SisDashboardData({
    required this.kpis,
    required this.classDistribution,
    required this.genderDistribution,
    required this.recentEnrollments,
    required this.aiInsight,
  });

  final List<SisKpi> kpis;
  final List<DistributionSegment> classDistribution;
  final List<DistributionSegment> genderDistribution;
  final List<RecentEnrollment> recentEnrollments;
  final String aiInsight;
}

@immutable
class SisStudent {
  const SisStudent({
    required this.id,
    required this.studentName,
    required this.admissionNumber,
    required this.classLabel,
    required this.section,
    required this.academicYear,
    required this.status,
    required this.gender,
    required this.dateOfBirth,
    required this.guardianName,
    required this.phone,
    required this.email,
    required this.enrolledAt,
    this.feeAccountId,
  });

  final String id;
  final String studentName;
  final String admissionNumber;
  final String classLabel;
  final String section;
  final String academicYear;
  final SisStudentStatus status;
  final String gender;
  final String dateOfBirth;
  final String guardianName;
  final String phone;
  final String email;
  final String enrolledAt;
  final String? feeAccountId;
}

@immutable
class SisAcademicAssignmentData {
  const SisAcademicAssignmentData({
    required this.classOptions,
    required this.sectionOptions,
    required this.academicYearOptions,
  });

  final List<String> classOptions;
  final List<String> sectionOptions;
  final List<String> academicYearOptions;
}

@immutable
class SisAdmissionsConversionData {
  const SisAdmissionsConversionData({
    required this.queue,
  });

  final List<SisEnrollmentQueueItem> queue;
}

@immutable
class SisParentDetails {
  const SisParentDetails({
    required this.guardianName,
    required this.relationship,
    required this.phone,
    required this.email,
    required this.address,
  });

  final String guardianName;
  final String relationship;
  final String phone;
  final String email;
  final String address;
}

@immutable
class SisAcademicHistoryEntry {
  const SisAcademicHistoryEntry({
    required this.academicYear,
    required this.classLabel,
    required this.section,
    required this.result,
  });

  final String academicYear;
  final String classLabel;
  final String section;
  final String result;
}

@immutable
class SisFeeAccountSummary {
  const SisFeeAccountSummary({
    required this.feeStructureName,
    required this.totalDue,
    required this.totalPaid,
    required this.balance,
    required this.status,
  });

  final String feeStructureName;
  final String totalDue;
  final String totalPaid;
  final String balance;
  final String status;
}

@immutable
class SisAttendanceSummary {
  const SisAttendanceSummary({
    required this.presentPercent,
    required this.absentDays,
    required this.lateDays,
    required this.periodLabel,
  });

  final String presentPercent;
  final int absentDays;
  final int lateDays;
  final String periodLabel;
}

@immutable
class SisDocumentSummary {
  const SisDocumentSummary({
    this.id,
    required this.type,
    required this.status,
    required this.uploadedAt,
  });

  final String? id;
  final String type;
  final String status;
  final String uploadedAt;
}

@immutable
class SisTimelineEvent {
  const SisTimelineEvent({
    required this.dateLabel,
    required this.title,
    required this.detail,
  });

  final String dateLabel;
  final String title;
  final String detail;
}

@immutable
class SisStudentProfile {
  const SisStudentProfile({
    required this.student,
    required this.parent,
    required this.academicHistory,
    required this.feeAccount,
    required this.attendance,
    required this.documents,
    required this.timeline,
  });

  final SisStudent student;
  final SisParentDetails parent;
  final List<SisAcademicHistoryEntry> academicHistory;
  final SisFeeAccountSummary? feeAccount;
  final SisAttendanceSummary attendance;
  final List<SisDocumentSummary> documents;
  final List<SisTimelineEvent> timeline;
}

@immutable
class SisAcademicAssignmentDraft {
  const SisAcademicAssignmentDraft({
    required this.studentId,
    required this.classLabel,
    required this.section,
    required this.academicYear,
  });

  final String studentId;
  final String classLabel;
  final String section;
  final String academicYear;
}

@immutable
class SisConversionPreview {
  const SisConversionPreview({
    required this.studentId,
    required this.admissionNumber,
    required this.studentName,
    required this.classLabel,
    required this.section,
    required this.academicYear,
  });

  final String studentId;
  final String admissionNumber;
  final String studentName;
  final String classLabel;
  final String section;
  final String academicYear;
}

@immutable
class SisEnrollmentQueueItem {
  const SisEnrollmentQueueItem({
    required this.enrollment,
    required this.effectiveStatus,
  });

  final PendingEnrollmentRecord enrollment;
  final EnrollmentConversionStatus effectiveStatus;
}
