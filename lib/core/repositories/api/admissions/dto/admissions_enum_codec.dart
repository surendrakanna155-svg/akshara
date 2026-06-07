import '../../../../../features/admissions/admissions_models.dart';

/// Serializes admissions enums to/from API snake_case strings.
class AdmissionsEnumCodec {
  const AdmissionsEnumCodec();

  static LeadStage parseLeadStage(String? raw) => switch (raw) {
        'new_enquiry' || 'newEnquiry' => LeadStage.newEnquiry,
        'contacted' => LeadStage.contacted,
        'school_visit' || 'schoolVisit' => LeadStage.schoolVisit,
        'demo_class' || 'demoClass' => LeadStage.demoClass,
        'follow_up' || 'followUp' => LeadStage.followUp,
        'admission_confirmed' || 'admissionConfirmed' =>
          LeadStage.admissionConfirmed,
        'joined' => LeadStage.joined,
        'lost' => LeadStage.lost,
        _ => LeadStage.newEnquiry,
      };

  static String leadStageToApi(LeadStage stage) => switch (stage) {
        LeadStage.newEnquiry => 'new_enquiry',
        LeadStage.contacted => 'contacted',
        LeadStage.schoolVisit => 'school_visit',
        LeadStage.demoClass => 'demo_class',
        LeadStage.followUp => 'follow_up',
        LeadStage.admissionConfirmed => 'admission_confirmed',
        LeadStage.joined => 'joined',
        LeadStage.lost => 'lost',
      };

  static LeadScore parseLeadScore(String? raw) => switch (raw) {
        'hot' => LeadScore.hot,
        'warm' => LeadScore.warm,
        'cold' => LeadScore.cold,
        _ => LeadScore.warm,
      };

  static LeadSource parseLeadSource(String? raw) => switch (raw) {
        'website' => LeadSource.website,
        'walk_in' || 'walkIn' => LeadSource.walkIn,
        'referral' => LeadSource.referral,
        'whatsapp' => LeadSource.whatsapp,
        'facebook' => LeadSource.facebook,
        'google_ads' || 'googleAds' => LeadSource.googleAds,
        _ => LeadSource.website,
      };

  static ApplicationStatus parseApplicationStatus(String? raw) =>
      switch (raw) {
        'draft' => ApplicationStatus.draft,
        'submitted' => ApplicationStatus.submitted,
        'documents_pending' || 'documentsPending' =>
          ApplicationStatus.documentsPending,
        'under_review' || 'underReview' => ApplicationStatus.underReview,
        'approved' => ApplicationStatus.approved,
        'rejected' => ApplicationStatus.rejected,
        _ => ApplicationStatus.draft,
      };

  static FollowUpPriority parseFollowUpPriority(String? raw) => switch (raw) {
        'high' => FollowUpPriority.high,
        'medium' => FollowUpPriority.medium,
        'low' => FollowUpPriority.low,
        _ => FollowUpPriority.medium,
      };

  static FollowUpStatus parseFollowUpStatus(String? raw) => switch (raw) {
        'pending' => FollowUpStatus.pending,
        'completed' => FollowUpStatus.completed,
        'overdue' => FollowUpStatus.overdue,
        _ => FollowUpStatus.pending,
      };

  static DocumentType parseDocumentType(String? raw) => switch (raw) {
        'birth_certificate' || 'birthCertificate' =>
          DocumentType.birthCertificate,
        'aadhaar' => DocumentType.aadhaar,
        'marks_memo' || 'marksMemo' => DocumentType.marksMemo,
        'transfer_certificate' || 'transferCertificate' =>
          DocumentType.transferCertificate,
        'photos' => DocumentType.photos,
        'medical' => DocumentType.medical,
        _ => DocumentType.birthCertificate,
      };

  static DocumentVerificationStatus parseDocumentStatus(String? raw) =>
      switch (raw) {
        'missing' => DocumentVerificationStatus.missing,
        'uploaded' => DocumentVerificationStatus.uploaded,
        'verified' => DocumentVerificationStatus.verified,
        'rejected' => DocumentVerificationStatus.rejected,
        _ => DocumentVerificationStatus.missing,
      };

  static EnrollmentConversionStatus parseConversionStatus(String? raw) =>
      switch (raw) {
        'pending' => EnrollmentConversionStatus.pending,
        'converted' => EnrollmentConversionStatus.converted,
        'failed' => EnrollmentConversionStatus.failed,
        _ => EnrollmentConversionStatus.pending,
      };

  static ApprovalDecision parseApprovalDecision(String? raw) => switch (raw) {
        'pending' => ApprovalDecision.pending,
        'approved' => ApprovalDecision.approved,
        'rejected' => ApprovalDecision.rejected,
        _ => ApprovalDecision.pending,
      };

  static FeeHandoffStatus parseFeeHandoffStatus(String? raw) => switch (raw) {
        'pending' => FeeHandoffStatus.pending,
        'sent_to_finance' || 'sentToFinance' => FeeHandoffStatus.sentToFinance,
        'completed' => FeeHandoffStatus.completed,
        'failed' => FeeHandoffStatus.failed,
        _ => FeeHandoffStatus.pending,
      };

  static EnrollmentStep parseEnrollmentStep(String? raw) => switch (raw) {
        'student_profile' || 'studentProfile' =>
          EnrollmentStep.studentProfile,
        'parent_information' || 'parentInformation' =>
          EnrollmentStep.parentInformation,
        'academic_information' || 'academicInformation' =>
          EnrollmentStep.academicInformation,
        'review_submit' || 'reviewSubmit' => EnrollmentStep.reviewSubmit,
        _ => EnrollmentStep.studentProfile,
      };
}
