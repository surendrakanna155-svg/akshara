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
  continuity,
  transfers;

  String get label => switch (this) {
        SisScreen.dashboard => 'Dashboard',
        SisScreen.registry => 'Student Registry',
        SisScreen.academicAssignment => 'Academic Assignment',
        SisScreen.admissionsConversion => 'Admissions Conversion',
        SisScreen.promotion => 'Promotion',
        SisScreen.reshuffle => 'Reshuffle',
        SisScreen.sectionBalance => 'Section Balance',
        SisScreen.continuity => 'Continuity',
        SisScreen.transfers => 'Transfers & Exits',
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
    this.publicStudentId,
    this.feeAccountId,
    this.isPlaceholder = false,
  });

  final String id;
  final String studentName;
  final String admissionNumber;

  /// Permanent, per-school public student identifier
  /// (`<SCHOOL_CODE>-<RUNNING_NUMBER>`, e.g. `DPSKKP-0001`). Null for a
  /// code-less school (the backend sends an empty string in that case).
  final String? publicStudentId;
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

  /// True for skeleton students generated from structure only (Path 2).
  /// They have no real parent login until replaced with real data.
  final bool isPlaceholder;
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
    this.verifiedBy,
    this.verifiedAt,
  });

  final String? id;
  final String type;

  /// Backend lifecycle status: pending / verified / rejected.
  final String status;
  final String uploadedAt;

  /// SIS-3 — set once a manageSis user verifies or rejects the document.
  final String? verifiedBy;
  final String? verifiedAt;
}

/// SIS-5 — one row in the transfers / exit log (a student who has left:
/// transferred out or graduated to alumni), with last-enrollment context.
@immutable
class SisTransferRecord {
  const SisTransferRecord({
    required this.studentId,
    required this.studentName,
    required this.admissionNumber,
    required this.classLabel,
    required this.section,
    required this.academicYear,
    required this.status,
    required this.exitedAt,
    this.reason,
  });

  final String studentId;
  final String studentName;

  /// May be empty when the exited student had no admission number on record.
  final String admissionNumber;
  final String classLabel;
  final String section;
  final String academicYear;
  final SisStudentStatus status;

  /// ISO timestamp (or date) of the exit transition.
  final String exitedAt;

  /// SIS-5 — reason from the latest Transfer Certificate issued for this
  /// student (read-only join). Null when no TC was ever issued.
  final String? reason;
}

/// SIS-4 — one sibling in a student's "Siblings / Family" section: another
/// student in the SAME school who shares an active guardian with the subject.
/// Read-only summary; no PII beyond what the registry/profile already show.
@immutable
class SisSibling {
  const SisSibling({
    required this.studentId,
    required this.studentName,
    required this.admissionNumber,
    required this.classLabel,
    required this.section,
    required this.status,
  });

  final String studentId;
  final String studentName;

  /// May be empty when the sibling has no admission number on record.
  final String admissionNumber;
  final String classLabel;
  final String section;
  final SisStudentStatus status;
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

/// SIS-1 — the certificate types a school can issue. `transfer` is the
/// Transfer Certificate (TC), which goes through the no-dues gated engine.
enum SisCertificateType { bonafide, study, conduct, transfer }

/// Presentation + API code for a certificate type.
extension SisCertificateTypeX on SisCertificateType {
  /// The backend API code (bonafide/study/conduct/transfer).
  String get apiValue => switch (this) {
        SisCertificateType.bonafide => 'bonafide',
        SisCertificateType.study => 'study',
        SisCertificateType.conduct => 'conduct',
        SisCertificateType.transfer => 'transfer',
      };

  /// Short label for a picker / register row.
  String get label => switch (this) {
        SisCertificateType.bonafide => 'Bonafide',
        SisCertificateType.study => 'Study',
        SisCertificateType.conduct => 'Conduct',
        SisCertificateType.transfer => 'Transfer',
      };

  /// The formal certificate title printed on the PDF.
  String get certificateTitle => switch (this) {
        SisCertificateType.bonafide => 'Bonafide Certificate',
        SisCertificateType.study => 'Study Certificate',
        SisCertificateType.conduct => 'Conduct Certificate',
        SisCertificateType.transfer => 'Transfer Certificate',
      };

  static SisCertificateType parse(String? value) => switch (value) {
        'bonafide' => SisCertificateType.bonafide,
        'study' => SisCertificateType.study,
        'conduct' => SisCertificateType.conduct,
        'transfer' => SisCertificateType.transfer,
        _ => SisCertificateType.bonafide,
      };
}

/// SIS-1 — the certificate payload the client PDF renders from (returned by an
/// issuance). Mirrors the backend `certificateDataToApi` shape.
@immutable
class SisCertificateData {
  const SisCertificateData({
    required this.issueId,
    required this.type,
    required this.serialNo,
    required this.reason,
    required this.issuedAt,
    required this.studentName,
    required this.publicStudentId,
    required this.admissionNumber,
    required this.className,
    required this.section,
    required this.academicYear,
    required this.dateOfBirth,
    required this.rollNumber,
    required this.guardianName,
    required this.status,
    required this.schoolName,
    required this.schoolCode,
  });

  final String issueId;
  final SisCertificateType type;

  /// Sequential TC serial (transfer only); null/empty for simple certificates.
  final String? serialNo;
  final String? reason;
  final String issuedAt;

  final String studentName;
  final String? publicStudentId;
  final String admissionNumber;
  final String className;
  final String section;
  final String academicYear;
  final String dateOfBirth;
  final String rollNumber;
  final String guardianName;
  final String status;

  final String schoolName;
  final String schoolCode;
}

/// SIS-1 — one row in a student's certificate issuance register.
@immutable
class SisCertificateIssue {
  const SisCertificateIssue({
    required this.id,
    required this.type,
    required this.serialNo,
    required this.reason,
    required this.issuedBy,
    required this.issuedAt,
  });

  final String id;
  final SisCertificateType type;
  final String? serialNo;
  final String? reason;
  final String issuedBy;
  final String issuedAt;
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
