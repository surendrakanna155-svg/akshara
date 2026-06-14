import '../../../features/admissions/admissions_models.dart';
import '../../../features/admissions/admissions_requests.dart';
import '../paginated_result.dart';
import '../repository_query.dart';

/// Contract for admissions data access (mock or API).
abstract class AdmissionsRepository {
  Future<AdmissionsDashboardData> getDashboard(
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

  Future<AdmissionsLead> assignCounselor({
    required RepositoryQuery query,
    required String leadId,
    required AssignCounselorRequest request,
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

  Future<ApprovedStudentHandoff> updateHandoffStatus({
    required RepositoryQuery query,
    required String handoffId,
    required UpdateHandoffStatusRequest request,
  });
}
