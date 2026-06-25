import 'package:flutter/material.dart';

/// Pipeline stage for leads (AR-016 lifecycle).
enum LeadStage {
  newEnquiry,
  contacted,
  schoolVisit,
  demoClass,
  followUp,
  admissionConfirmed,
  joined,
  lost;

  String get label => switch (this) {
        LeadStage.newEnquiry => 'New Enquiry',
        LeadStage.contacted => 'Contacted',
        LeadStage.schoolVisit => 'School Visit',
        LeadStage.demoClass => 'Demo Class',
        LeadStage.followUp => 'Follow-up',
        LeadStage.admissionConfirmed => 'Admission Confirmed',
        LeadStage.joined => 'Joined',
        LeadStage.lost => 'Lost',
      };
}

/// Lead temperature score chip.
enum LeadScore {
  hot,
  warm,
  cold;

  String get label => switch (this) {
        LeadScore.hot => 'Hot',
        LeadScore.warm => 'Warm',
        LeadScore.cold => 'Cold',
      };
}

/// Acquisition source for a lead.
enum LeadSource {
  website,
  walkIn,
  referral,
  whatsapp,
  facebook,
  googleAds;

  String get label => switch (this) {
        LeadSource.website => 'Website',
        LeadSource.walkIn => 'Walk-in',
        LeadSource.referral => 'Referral',
        LeadSource.whatsapp => 'WhatsApp',
        LeadSource.facebook => 'Facebook',
        LeadSource.googleAds => 'Google Ads',
      };

  IconData get icon => switch (this) {
        LeadSource.website => Icons.language_outlined,
        LeadSource.walkIn => Icons.storefront_outlined,
        LeadSource.referral => Icons.people_outline,
        LeadSource.whatsapp => Icons.chat_outlined,
        LeadSource.facebook => Icons.campaign_outlined,
        LeadSource.googleAds => Icons.ads_click_outlined,
      };
}

/// Application workflow status (AD-05).
enum ApplicationStatus {
  draft,
  submitted,
  documentsPending,
  underReview,
  approved,
  rejected;

  String get label => switch (this) {
        ApplicationStatus.draft => 'Draft',
        ApplicationStatus.submitted => 'Submitted',
        ApplicationStatus.documentsPending => 'Documents Pending',
        ApplicationStatus.underReview => 'Under Review',
        ApplicationStatus.approved => 'Approved',
        ApplicationStatus.rejected => 'Rejected',
      };

  int get workflowIndex => switch (this) {
        ApplicationStatus.draft => 0,
        ApplicationStatus.submitted => 1,
        ApplicationStatus.documentsPending => 2,
        ApplicationStatus.underReview => 3,
        ApplicationStatus.approved => 4,
        ApplicationStatus.rejected => 3,
      };
}

enum FollowUpPriority { high, medium, low }

enum FollowUpStatus { pending, completed, overdue }

@immutable
class AdmissionsKpi {
  const AdmissionsKpi({
    required this.id,
    required this.value,
    required this.label,
    required this.icon,
    required this.accentName,
  });

  final String id;
  final String value;
  final String label;
  final IconData icon;

  /// Maps to [KpiAccent] name: primary, success, warning, error, neutral.
  final String accentName;
}

@immutable
class PipelineStageSummary {
  const PipelineStageSummary({
    required this.stage,
    required this.count,
    required this.leads,
  });

  final LeadStage stage;
  final int count;
  final List<PipelineLeadPreview> leads;
}

@immutable
class PipelineLeadPreview {
  const PipelineLeadPreview({
    required this.id,
    required this.studentName,
    required this.classLabel,
    required this.score,
    required this.source,
    required this.daysInStage,
  });

  final String id;
  final String studentName;
  final String classLabel;
  final LeadScore score;
  final LeadSource source;
  final int daysInStage;
}

@immutable
class ChartSegment {
  const ChartSegment({
    required this.label,
    required this.value,
    required this.percent,
  });

  final String label;
  final int value;
  final double percent;
}

@immutable
class AdmissionsFollowUp {
  const AdmissionsFollowUp({
    required this.id,
    required this.dueLabel,
    required this.leadName,
    required this.task,
    required this.counselor,
    required this.priority,
    required this.status,
  });

  final String id;
  final String dueLabel;
  final String leadName;
  final String task;
  final String counselor;
  final FollowUpPriority priority;
  final FollowUpStatus status;
}

@immutable
class CounselorLeaderboardEntry {
  const CounselorLeaderboardEntry({
    required this.counselor,
    required this.leadsHandled,
    required this.conversions,
    required this.conversionRate,
  });

  final String counselor;
  final int leadsHandled;
  final int conversions;
  final double conversionRate;
}

@immutable
class AdmissionsDashboardData {
  const AdmissionsDashboardData({
    required this.kpis,
    required this.pipeline,
    required this.funnelSegments,
    required this.sourceSegments,
    required this.followUps,
    required this.leaderboard,
    required this.aiInsight,
    required this.aiActionLabel,
  });

  final List<AdmissionsKpi> kpis;
  final List<PipelineStageSummary> pipeline;
  final List<ChartSegment> funnelSegments;
  final List<ChartSegment> sourceSegments;
  final List<AdmissionsFollowUp> followUps;
  final List<CounselorLeaderboardEntry> leaderboard;
  final String aiInsight;
  final String aiActionLabel;
}

/// B4 — AI Admissions Assistant: funnel summary + ranked next-best-actions.
@immutable
class AdmissionsIntelligenceData {
  const AdmissionsIntelligenceData({
    required this.funnel,
    required this.nextBestActions,
  });

  final AdmissionsFunnelSummary funnel;
  final List<AdmissionsNextBestAction> nextBestActions;

  bool get isEmpty => nextBestActions.isEmpty;
}

@immutable
class AdmissionsFunnelSummary {
  const AdmissionsFunnelSummary({
    required this.totalLeads,
    required this.hotLeads,
    required this.conversionRate,
    required this.pendingFollowUps,
    required this.unassignedLeads,
    required this.stageCounts,
    this.topSource,
    this.topSourceCount = 0,
  });

  final int totalLeads;
  final int hotLeads;
  final double conversionRate;
  final int pendingFollowUps;
  final int unassignedLeads;
  final Map<String, int> stageCounts;
  final String? topSource;
  final int topSourceCount;
}

/// Priority buckets, highest urgency first.
enum AdmissionsActionPriority { urgent, high, medium, low }

@immutable
class AdmissionsNextBestAction {
  const AdmissionsNextBestAction({
    required this.id,
    required this.kind,
    required this.priority,
    required this.title,
    required this.detail,
    required this.cta,
    this.count,
    this.leadId,
  });

  final String id;
  final String kind;
  final AdmissionsActionPriority priority;
  final String title;
  final String detail;
  final String cta;
  final int? count;
  final String? leadId;
}

@immutable
class AdmissionsLead {
  const AdmissionsLead({
    required this.id,
    required this.parentName,
    required this.studentName,
    required this.classLabel,
    required this.phone,
    required this.source,
    required this.campaign,
    required this.stage,
    required this.counselor,
    required this.score,
    required this.nextFollowUpLabel,
  });

  final String id;
  final String parentName;
  final String studentName;
  final String classLabel;
  final String phone;
  final LeadSource source;
  final String campaign;
  final LeadStage stage;
  final String counselor;
  final LeadScore score;
  final String nextFollowUpLabel;
}

@immutable
class AdmissionsApplication {
  const AdmissionsApplication({
    required this.id,
    required this.studentName,
    required this.classLabel,
    required this.parentName,
    required this.submittedLabel,
    required this.status,
    required this.documentsComplete,
    required this.documentsTotal,
    required this.counselor,
  });

  final String id;
  final String studentName;
  final String classLabel;
  final String parentName;
  final String submittedLabel;
  final ApplicationStatus status;
  final int documentsComplete;
  final int documentsTotal;
  final String counselor;
}

@immutable
class ApplicationWorkflowSummary {
  const ApplicationWorkflowSummary({
    required this.draft,
    required this.submitted,
    required this.underReview,
    required this.approved,
  });

  final int draft;
  final int submitted;
  final int underReview;
  final int approved;
}

// --- Phase 2: AD-04 Lead Detail ---

enum LeadActivityType {
  note,
  call,
  visit,
  whatsapp,
  stageChange,
  assignment;

  IconData get icon => switch (this) {
        LeadActivityType.note => Icons.sticky_note_2_outlined,
        LeadActivityType.call => Icons.call_outlined,
        LeadActivityType.visit => Icons.location_on_outlined,
        LeadActivityType.whatsapp => Icons.chat_outlined,
        LeadActivityType.stageChange => Icons.swap_horiz,
        LeadActivityType.assignment => Icons.person_add_alt_1_outlined,
      };
}

@immutable
class LeadActivityItem {
  const LeadActivityItem({
    required this.id,
    required this.timestampLabel,
    required this.title,
    required this.description,
    required this.actor,
    required this.type,
  });

  final String id;
  final String timestampLabel;
  final String title;
  final String description;
  final String actor;
  final LeadActivityType type;
}

@immutable
class LeadFollowUpRecord {
  const LeadFollowUpRecord({
    required this.id,
    required this.scheduledLabel,
    required this.completedLabel,
    required this.task,
    required this.counselor,
    required this.status,
    required this.outcome,
  });

  final String id;
  final String scheduledLabel;
  final String completedLabel;
  final String task;
  final String counselor;
  final FollowUpStatus status;
  final String outcome;
}

@immutable
class LeadStatusStep {
  const LeadStatusStep({
    required this.stage,
    required this.isComplete,
    required this.isCurrent,
    this.completedLabel,
  });

  final LeadStage stage;
  final bool isComplete;
  final bool isCurrent;
  final String? completedLabel;
}

@immutable
class LeadDetailProfile {
  const LeadDetailProfile({
    required this.lead,
    required this.email,
    required this.address,
    required this.createdLabel,
    required this.lastActivityLabel,
    required this.notes,
    required this.availableCounselors,
    required this.statusSteps,
    required this.activities,
    required this.followUpHistory,
    required this.acquisitionReadOnly,
  });

  final AdmissionsLead lead;
  final String email;
  final String address;
  final String createdLabel;
  final String lastActivityLabel;
  final String notes;
  final List<String> availableCounselors;
  final List<LeadStatusStep> statusSteps;
  final List<LeadActivityItem> activities;
  final List<LeadFollowUpRecord> followUpHistory;
  final bool acquisitionReadOnly;
}

/// Raw lead-detail payload returned by the backend (`GET /admissions/leads/{id}`):
/// the lead plus its persisted activity timeline and follow-up history. The
/// presentation [LeadDetailProfile] is composed from this in the provider.
@immutable
class LeadDetailData {
  const LeadDetailData({
    required this.lead,
    required this.email,
    required this.address,
    required this.createdLabel,
    required this.lastActivityLabel,
    required this.notes,
    required this.activities,
    required this.followUpHistory,
  });

  final AdmissionsLead lead;
  final String email;
  final String address;
  final String createdLabel;
  final String lastActivityLabel;
  final String notes;
  final List<LeadActivityItem> activities;
  final List<LeadFollowUpRecord> followUpHistory;
}

// --- Phase 2: AD-05 Student Enrollment ---

enum EnrollmentStep {
  studentProfile,
  parentInformation,
  academicInformation,
  reviewSubmit;

  String get label => switch (this) {
        EnrollmentStep.studentProfile => 'Student profile',
        EnrollmentStep.parentInformation => 'Parent information',
        EnrollmentStep.academicInformation => 'Academic information',
        EnrollmentStep.reviewSubmit => 'Review & submit',
      };
}

@immutable
class EnrollmentStudentProfile {
  const EnrollmentStudentProfile({
    this.fullName = '',
    this.dateOfBirth = '',
    this.gender = '',
    this.aadhaar = '',
  });

  final String fullName;
  final String dateOfBirth;
  final String gender;
  final String aadhaar;

  EnrollmentStudentProfile copyWith({
    String? fullName,
    String? dateOfBirth,
    String? gender,
    String? aadhaar,
  }) {
    return EnrollmentStudentProfile(
      fullName: fullName ?? this.fullName,
      dateOfBirth: dateOfBirth ?? this.dateOfBirth,
      gender: gender ?? this.gender,
      aadhaar: aadhaar ?? this.aadhaar,
    );
  }
}

@immutable
class EnrollmentParentInfo {
  const EnrollmentParentInfo({
    this.guardianName = '',
    this.relationship = '',
    this.phone = '',
    this.email = '',
    this.address = '',
  });

  final String guardianName;
  final String relationship;
  final String phone;
  final String email;
  final String address;

  EnrollmentParentInfo copyWith({
    String? guardianName,
    String? relationship,
    String? phone,
    String? email,
    String? address,
  }) {
    return EnrollmentParentInfo(
      guardianName: guardianName ?? this.guardianName,
      relationship: relationship ?? this.relationship,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      address: address ?? this.address,
    );
  }
}

@immutable
class EnrollmentAcademicInfo {
  const EnrollmentAcademicInfo({
    this.seekingClass = '',
    this.section = '',
    this.academicYear = '2026–27',
    this.previousSchool = '',
    this.needsTransport = false,
    this.needsHostel = false,
    this.academicYearId,
    this.classId,
    this.sectionId,
  });

  final String seekingClass;
  final String section;
  final String academicYear;
  final String previousSchool;
  final bool needsTransport;
  final bool needsHostel;
  final String? academicYearId;
  final String? classId;
  final String? sectionId;

  EnrollmentAcademicInfo copyWith({
    String? seekingClass,
    String? section,
    String? academicYear,
    String? previousSchool,
    bool? needsTransport,
    bool? needsHostel,
    String? academicYearId,
    String? classId,
    String? sectionId,
  }) {
    return EnrollmentAcademicInfo(
      seekingClass: seekingClass ?? this.seekingClass,
      section: section ?? this.section,
      academicYear: academicYear ?? this.academicYear,
      previousSchool: previousSchool ?? this.previousSchool,
      needsTransport: needsTransport ?? this.needsTransport,
      needsHostel: needsHostel ?? this.needsHostel,
      academicYearId: academicYearId ?? this.academicYearId,
      classId: classId ?? this.classId,
      sectionId: sectionId ?? this.sectionId,
    );
  }
}

@immutable
class EnrollmentFormState {
  const EnrollmentFormState({
    this.currentStep = EnrollmentStep.studentProfile,
    this.student = const EnrollmentStudentProfile(),
    this.parent = const EnrollmentParentInfo(),
    this.academic = const EnrollmentAcademicInfo(),
    this.isSubmitting = false,
    this.isSubmitted = false,
    this.generatedAdmissionNumber,
    this.stepFieldErrors,
  });

  final EnrollmentStep currentStep;
  final EnrollmentStudentProfile student;
  final EnrollmentParentInfo parent;
  final EnrollmentAcademicInfo academic;
  final bool isSubmitting;
  final bool isSubmitted;
  final String? generatedAdmissionNumber;
  final Map<String, String>? stepFieldErrors;

  EnrollmentFormState copyWith({
    EnrollmentStep? currentStep,
    EnrollmentStudentProfile? student,
    EnrollmentParentInfo? parent,
    EnrollmentAcademicInfo? academic,
    bool? isSubmitting,
    bool? isSubmitted,
    String? generatedAdmissionNumber,
    Map<String, String>? stepFieldErrors,
    bool clearStepFieldErrors = false,
  }) {
    return EnrollmentFormState(
      currentStep: currentStep ?? this.currentStep,
      student: student ?? this.student,
      parent: parent ?? this.parent,
      academic: academic ?? this.academic,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      isSubmitted: isSubmitted ?? this.isSubmitted,
      generatedAdmissionNumber:
          generatedAdmissionNumber ?? this.generatedAdmissionNumber,
      stepFieldErrors: clearStepFieldErrors
          ? null
          : (stepFieldErrors ?? this.stepFieldErrors),
    );
  }
}

// --- AD-05 Enrollment records for SIS conversion ---

enum EnrollmentConversionStatus { pending, converted, failed }

@immutable
class PendingEnrollmentRecord {
  const PendingEnrollmentRecord({
    required this.id,
    required this.studentName,
    required this.applicationId,
    required this.seekingClass,
    required this.section,
    required this.academicYear,
    required this.guardianName,
    required this.phone,
    required this.submittedAt,
    required this.conversionStatus,
    this.generatedAdmissionNumber,
    this.previewStudentId,
    this.gender = '',
    this.dateOfBirth = '',
  });

  final String id;
  final String studentName;
  final String applicationId;
  final String seekingClass;
  final String section;
  final String academicYear;
  final String guardianName;
  final String phone;
  final String submittedAt;
  final EnrollmentConversionStatus conversionStatus;
  final String? generatedAdmissionNumber;
  final String? previewStudentId;
  final String gender;
  final String dateOfBirth;
}

// --- Phase 2: AD-06 Document Verification ---

enum DocumentType {
  birthCertificate,
  aadhaar,
  marksMemo,
  transferCertificate,
  photos,
  medical;

  String get label => switch (this) {
        DocumentType.birthCertificate => 'Birth Certificate',
        DocumentType.aadhaar => 'Aadhaar',
        DocumentType.marksMemo => 'Previous marks memo',
        DocumentType.transferCertificate => 'Transfer certificate',
        DocumentType.photos => 'Photos',
        DocumentType.medical => 'Medical',
      };
}

enum DocumentVerificationStatus {
  missing,
  uploaded,
  verified,
  rejected;

  String get label => switch (this) {
        DocumentVerificationStatus.missing => 'Missing',
        DocumentVerificationStatus.uploaded => 'Uploaded',
        DocumentVerificationStatus.verified => 'Verified',
        DocumentVerificationStatus.rejected => 'Rejected',
      };
}

enum DocumentApprovalAction { approve, reject, requestResubmit }

@immutable
class StudentDocumentRecord {
  const StudentDocumentRecord({
    required this.id,
    required this.studentName,
    required this.classLabel,
    required this.documentType,
    required this.isRequired,
    required this.status,
    required this.uploadedLabel,
    required this.verifiedBy,
    required this.leadId,
  });

  final String id;
  final String studentName;
  final String classLabel;
  final DocumentType documentType;
  final bool isRequired;
  final DocumentVerificationStatus status;
  final String uploadedLabel;
  final String? verifiedBy;
  final String leadId;
}

@immutable
class DocumentVerificationSummary {
  const DocumentVerificationSummary({
    required this.pending,
    required this.verified,
    required this.rejected,
    required this.missing,
  });

  final int pending;
  final int verified;
  final int rejected;
  final int missing;
}

@immutable
class DocumentChecklistItem {
  const DocumentChecklistItem({
    required this.documentType,
    required this.status,
    required this.isRequired,
    required this.note,
  });

  final DocumentType documentType;
  final DocumentVerificationStatus status;
  final bool isRequired;
  final String note;
}

// --- Phase 3: AD-07 Admission Approval ---

enum ApprovalDecision { pending, approved, rejected }

@immutable
class ApprovalQueueItem {
  const ApprovalQueueItem({
    required this.id,
    required this.applicationId,
    required this.studentName,
    required this.classLabel,
    required this.parentName,
    required this.counselor,
    required this.submittedLabel,
    required this.documentsComplete,
    required this.documentsTotal,
    required this.decision,
    required this.aiScore,
  });

  final String id;
  final String applicationId;
  final String studentName;
  final String classLabel;
  final String parentName;
  final String counselor;
  final String submittedLabel;
  final int documentsComplete;
  final int documentsTotal;
  final ApprovalDecision decision;
  final int aiScore;
}

@immutable
class CounselorNote {
  const CounselorNote({
    required this.id,
    required this.author,
    required this.timestampLabel,
    required this.content,
  });

  final String id;
  final String author;
  final String timestampLabel;
  final String content;
}

@immutable
class ApprovalHistoryRecord {
  const ApprovalHistoryRecord({
    required this.id,
    required this.timestampLabel,
    required this.actor,
    required this.decision,
    required this.comment,
  });

  final String id;
  final String timestampLabel;
  final String actor;
  final ApprovalDecision decision;
  final String comment;
}

@immutable
class ApprovalReviewDetail {
  const ApprovalReviewDetail({
    required this.queueItem,
    required this.feePlanLabel,
    required this.counselorNotes,
    required this.history,
    required this.workflowSteps,
  });

  final ApprovalQueueItem queueItem;
  final String feePlanLabel;
  final List<CounselorNote> counselorNotes;
  final List<ApprovalHistoryRecord> history;
  final List<String> workflowSteps;
}

// --- Phase 3: AD-08 Fee Setup Handoff ---

enum FeeHandoffStatus { pending, sentToFinance, completed, failed }

@immutable
class FeeStructureOption {
  const FeeStructureOption({
    required this.id,
    required this.label,
    required this.annualAmount,
    required this.installments,
  });

  final String id;
  final String label;
  final String annualAmount;
  final int installments;
}

@immutable
class ApprovedStudentHandoff {
  const ApprovedStudentHandoff({
    required this.id,
    required this.studentName,
    required this.classLabel,
    required this.applicationId,
    required this.admissionNumber,
    required this.needsTransport,
    required this.needsHostel,
    required this.selectedFeeStructureId,
    required this.handoffStatus,
    required this.previewStudentId,
    required this.sisHandoffLabel,
  });

  final String id;
  final String studentName;
  final String classLabel;
  final String applicationId;
  final String admissionNumber;
  final bool needsTransport;
  final bool needsHostel;
  final String? selectedFeeStructureId;
  final FeeHandoffStatus handoffStatus;
  final String previewStudentId;
  final String sisHandoffLabel;
}

// --- Phase 3: AD-09 Admissions Reports ---

enum AdmissionsReportTab {
  funnel,
  sources,
  counselors,
  applications,
}

@immutable
class SourceLeadAnalysisRow {
  const SourceLeadAnalysisRow({
    required this.source,
    required this.leads,
    required this.converted,
    required this.conversionRate,
  });

  final LeadSource source;
  final int leads;
  final int converted;
  final double conversionRate;
}

@immutable
class CounselorPerformanceRow {
  const CounselorPerformanceRow({
    required this.counselor,
    required this.leads,
    required this.applications,
    required this.approved,
    required this.conversionRate,
  });

  final String counselor;
  final int leads;
  final int applications;
  final int approved;
  final double conversionRate;
}

@immutable
class ApplicationStatusReportRow {
  const ApplicationStatusReportRow({
    required this.status,
    required this.count,
    required this.percent,
  });

  final ApplicationStatus status;
  final int count;
  final double percent;
}

@immutable
class AdmissionsReportsData {
  const AdmissionsReportsData({
    required this.funnelSegments,
    required this.sourceAnalysis,
    required this.counselorPerformance,
    required this.applicationStatus,
  });

  final List<ChartSegment> funnelSegments;
  final List<SourceLeadAnalysisRow> sourceAnalysis;
  final List<CounselorPerformanceRow> counselorPerformance;
  final List<ApplicationStatusReportRow> applicationStatus;
}

// --- Phase 3: AD-10 Admissions Settings ---

@immutable
class LeadStageConfig {
  const LeadStageConfig({
    required this.stage,
    required this.enabled,
    required this.autoAdvanceDays,
  });

  final LeadStage stage;
  final bool enabled;
  final int? autoAdvanceDays;
}

@immutable
class LeadScoreConfig {
  const LeadScoreConfig({
    required this.score,
    required this.minEngagement,
    required this.followUpHours,
  });

  final LeadScore score;
  final int minEngagement;
  final int followUpHours;
}

@immutable
class ApplicationWorkflowConfig {
  const ApplicationWorkflowConfig({
    required this.status,
    required this.enabled,
    required this.requiresPrincipalApproval,
  });

  final ApplicationStatus status;
  final bool enabled;
  final bool requiresPrincipalApproval;
}

@immutable
class CounselorAssignmentRule {
  const CounselorAssignmentRule({
    required this.id,
    required this.label,
    required this.strategy,
    required this.enabled,
  });

  final String id;
  final String label;
  final String strategy;
  final bool enabled;
}

@immutable
class NotificationTemplate {
  const NotificationTemplate({
    required this.id,
    required this.name,
    required this.channel,
    required this.preview,
    required this.enabled,
  });

  final String id;
  final String name;
  final String channel;
  final String preview;
  final bool enabled;
}

@immutable
class AdmissionsSettingsData {
  const AdmissionsSettingsData({
    required this.leadStages,
    required this.leadScores,
    required this.workflowSteps,
    required this.assignmentRules,
    required this.notificationTemplates,
  });

  final List<LeadStageConfig> leadStages;
  final List<LeadScoreConfig> leadScores;
  final List<ApplicationWorkflowConfig> workflowSteps;
  final List<CounselorAssignmentRule> assignmentRules;
  final List<NotificationTemplate> notificationTemplates;
}
