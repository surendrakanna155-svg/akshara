import '../../../features/admissions/admissions_models.dart';
import '../../../features/admissions/admissions_requests.dart';
import '../paginated_result.dart';
import '../repository_query.dart';

/// Contract for admissions data access (mock or API).
abstract class AdmissionsRepository {
  Future<AdmissionsDashboardData> getDashboard(
      {required RepositoryQuery query});
  Future<AdmissionsIntelligenceData> getIntelligence(
      {required RepositoryQuery query});
  Future<PaginatedResult<AdmissionsLead>> getLeads(
      {required RepositoryQuery query});
  Future<PaginatedResult<AdmissionsApplication>> getApplications(
      {required RepositoryQuery query});
  Future<PaginatedResult<StudentDocumentRecord>> getDocuments(
      {required RepositoryQuery query});
  Future<PaginatedResult<PendingEnrollmentRecord>> getPendingEnrollments(
      {required RepositoryQuery query});
  Future<PaginatedResult<ApprovedStudentHandoff>> getApprovedHandoffs(
      {required RepositoryQuery query});
  Future<PaginatedResult<FeeStructureOption>> getFeeStructureOptions(
      {required RepositoryQuery query});
  Future<PaginatedResult<ApprovalQueueItem>> getApprovalQueue(
      {required RepositoryQuery query});
  Future<AdmissionsReportsData> getReports({required RepositoryQuery query});
  Future<AdmissionsSettingsData> getSettings({required RepositoryQuery query});
  Future<AdmissionsSettingsData> updateSettings({
    required RepositoryQuery query,
    required UpdateAdmissionsSettingsRequest request,
  });

  /// #6: persist the full admissions settings snapshot
  /// (`POST /admissions/settings`) and return the saved state.
  Future<AdmissionsSettingsData> saveSettings({
    required RepositoryQuery query,
    required SaveAdmissionsSettingsRequest request,
  });
  Future<EnrollmentFormState> getEnrollmentPrefill(
      {required RepositoryQuery query});

  Future<AdmissionsLead> createLead({
    required RepositoryQuery query,
    required CreateLeadRequest request,
  });

  Future<AdmissionsLead> updateLead({
    required RepositoryQuery query,
    required String leadId,
    required UpdateLeadRequest request,
  });

  /// Fetches a single lead with its persisted activity timeline and follow-up
  /// history (`GET /admissions/leads/{id}`).
  Future<LeadDetailData> getLeadDetail({
    required RepositoryQuery query,
    required String leadId,
  });

  Future<AdmissionsLead> assignCounselor({
    required RepositoryQuery query,
    required String leadId,
    required AssignCounselorRequest request,
  });

  /// ADM-3: bulk assign a counselor / change stage over many leads
  /// (`POST /admissions/leads/bulk`) → `{updated, skipped}` partial-success.
  Future<BulkLeadActionResult> bulkLeadAction({
    required RepositoryQuery query,
    required BulkLeadActionRequest request,
  });

  /// ADM-D1: mark a lead lost with a fixed-picklist reason
  /// (`PATCH /admissions/leads/{id}/lost`).
  Future<AdmissionsLead> markLeadLost({
    required RepositoryQuery query,
    required String leadId,
    required MarkLeadLostRequest request,
  });

  /// ADM-4: complete a scheduled follow-up
  /// (`POST /admissions/leads/{id}/followups/{followupId}/complete`).
  Future<LeadFollowUpRecord> completeFollowUp({
    required RepositoryQuery query,
    required String leadId,
    required String followUpId,
    required CompleteFollowUpRequest request,
  });

  /// ADM-4: reschedule a follow-up to a new due label
  /// (`POST /admissions/leads/{id}/followups/{followupId}/reschedule`).
  Future<LeadFollowUpRecord> rescheduleFollowUp({
    required RepositoryQuery query,
    required String leadId,
    required String followUpId,
    required RescheduleFollowUpRequest request,
  });

  /// ADM-D2: warn-only duplicate lookup by phone
  /// (`GET /admissions/leads/check-duplicate?phone=`).
  Future<DuplicateLeadCheckResult> checkDuplicateByPhone({
    required RepositoryQuery query,
    required String phone,
  });

  Future<AdmissionsLead> changeLeadStage({
    required RepositoryQuery query,
    required String leadId,
    required ChangeLeadStageRequest request,
  });

  Future<LeadFollowUpRecord> addLeadFollowUp({
    required RepositoryQuery query,
    required String leadId,
    required FollowUpRequest request,
  });

  Future<LeadActivityItem> addLeadNote({
    required RepositoryQuery query,
    required String leadId,
    required LeadNoteRequest request,
  });

  Future<AdmissionsApplication> createApplication({
    required RepositoryQuery query,
    required CreateApplicationRequest request,
  });

  Future<AdmissionsApplication> updateApplication({
    required RepositoryQuery query,
    required String applicationId,
    required UpdateApplicationRequest request,
  });

  Future<AdmissionsApplication> submitApplication({
    required RepositoryQuery query,
    required String applicationId,
  });

  Future<PendingEnrollmentRecord> submitEnrollment({
    required RepositoryQuery query,
    required EnrollmentSubmitRequest request,
  });

  Future<GeneratedAdmissionNumber> generateAdmissionNumber({
    required RepositoryQuery query,
    required GenerateAdmissionNumberRequest request,
  });

  Future<StudentDocumentRecord> uploadDocument({
    required RepositoryQuery query,
    required DocumentUploadRequest request,
  });

  /// Uploads the real file bytes to Storage (presign → PUT) and then confirms
  /// the document metadata, returning the persisted, retrievable record.
  Future<StudentDocumentRecord> uploadDocumentFile({
    required RepositoryQuery query,
    required String leadId,
    required DocumentType documentType,
    required String fileName,
    required List<int> bytes,
    required String contentType,
    String studentName,
    String classLabel,
  });

  /// Resolves a short-lived signed URL for opening/downloading a stored
  /// document during verification.
  Future<String> getDocumentDownloadUrl({
    required RepositoryQuery query,
    required String documentId,
  });

  Future<StudentDocumentRecord> approveDocument({
    required RepositoryQuery query,
    required String documentId,
    required DocumentVerificationRequest request,
  });

  Future<StudentDocumentRecord> rejectDocument({
    required RepositoryQuery query,
    required String documentId,
    required DocumentVerificationRequest request,
  });

  Future<ApprovalQueueItem> approveAdmission({
    required RepositoryQuery query,
    required String approvalId,
    required ApprovalDecisionRequest request,
  });

  Future<ApprovalQueueItem> rejectAdmission({
    required RepositoryQuery query,
    required String approvalId,
    required ApprovalDecisionRequest request,
  });

  Future<CounselorNote> addApprovalNote({
    required RepositoryQuery query,
    required String approvalId,
    required ApprovalNoteRequest request,
  });

  Future<ApprovedStudentHandoff> sendToFinance({
    required RepositoryQuery query,
    required FinanceHandoffRequest request,
  });

  /// ADM-D4: offer-letter template data for an approved enrollment
  /// (`GET /admissions/enrollments/{id}/offer-letter`); the client renders the
  /// PDF from these fields.
  Future<OfferLetterData> getOfferLetter({
    required RepositoryQuery query,
    required String enrollmentId,
  });

  Future<ApprovedStudentHandoff> updateHandoffStatus({
    required RepositoryQuery query,
    required String handoffId,
    required UpdateHandoffStatusRequest request,
  });
}
