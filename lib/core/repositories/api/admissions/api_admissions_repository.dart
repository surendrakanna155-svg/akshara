import '../../interfaces/admissions_repository.dart';
import '../../paginated_result.dart';
import '../../repository_query.dart';
import '../../../../features/admissions/admissions_models.dart';
import '../../../../features/admissions/admissions_requests.dart';
import 'mapper/admissions_mapper.dart';
import 'remote/admissions_remote_datasource.dart';

/// API implementation of [AdmissionsRepository] — enabled via [admissionsApiEnabledProvider].
class ApiAdmissionsRepository implements AdmissionsRepository {
  ApiAdmissionsRepository({
    required AdmissionsRemoteDataSource remote,
    AdmissionsMapper mapper = const AdmissionsMapper(),
  })  : _remote = remote,
        _mapper = mapper;

  final AdmissionsRemoteDataSource _remote;
  final AdmissionsMapper _mapper;

  @override
  Future<AdmissionsDashboardData> getDashboard({
    required RepositoryQuery query,
  }) async {
    final dto = await _remote.fetchDashboard(query: query);
    return _mapper.toDashboard(dto);
  }

  @override
  Future<PaginatedResult<AdmissionsLead>> getLeads({
    required RepositoryQuery query,
  }) async {
    final dto = await _remote.fetchLeads(query: query);
    return PaginatedResult.fromDto(
      items: _mapper.toLeads(dto),
      pagination: dto.pagination,
      fallbackPage: query.page,
      fallbackPageSize: query.pageSize,
    );
  }

  @override
  Future<PaginatedResult<AdmissionsApplication>> getApplications({
    required RepositoryQuery query,
  }) async {
    final dto = await _remote.fetchApplications(query: query);
    return PaginatedResult.fromDto(
      items: _mapper.toApplications(dto),
      pagination: dto.pagination,
      fallbackPage: query.page,
      fallbackPageSize: query.pageSize,
    );
  }

  @override
  Future<List<StudentDocumentRecord>> getDocuments({
    required RepositoryQuery query,
  }) async {
    final dto = await _remote.fetchDocuments(query: query);
    return _mapper.toDocuments(dto);
  }

  @override
  Future<List<PendingEnrollmentRecord>> getPendingEnrollments({
    required RepositoryQuery query,
  }) async {
    final dto = await _remote.fetchPendingEnrollments(query: query);
    return _mapper.toPendingEnrollments(dto);
  }

  @override
  Future<List<ApprovedStudentHandoff>> getApprovedHandoffs({
    required RepositoryQuery query,
  }) async {
    final dto = await _remote.fetchApprovedHandoffs(query: query);
    return _mapper.toApprovedHandoffs(dto);
  }

  @override
  Future<List<FeeStructureOption>> getFeeStructureOptions({
    required RepositoryQuery query,
  }) async {
    final dto = await _remote.fetchFeeStructureOptions(query: query);
    return _mapper.toFeeStructureOptions(dto);
  }

  @override
  Future<PaginatedResult<ApprovalQueueItem>> getApprovalQueue({
    required RepositoryQuery query,
  }) async {
    final dto = await _remote.fetchApprovalQueue(query: query);
    return PaginatedResult.fromDto(
      items: _mapper.toApprovalQueue(dto),
      pagination: dto.pagination,
      fallbackPage: query.page,
      fallbackPageSize: query.pageSize,
    );
  }

  @override
  Future<AdmissionsReportsData> getReports({
    required RepositoryQuery query,
  }) async {
    final dto = await _remote.fetchReports(query: query);
    return _mapper.toReports(dto);
  }

  @override
  Future<AdmissionsSettingsData> getSettings({
    required RepositoryQuery query,
  }) async {
    final dto = await _remote.fetchSettings(query: query);
    return _mapper.toSettings(dto);
  }

  @override
  Future<EnrollmentFormState> getEnrollmentPrefill({
    required RepositoryQuery query,
  }) async {
    final dto = await _remote.fetchEnrollmentPrefill(query: query);
    return _mapper.toEnrollmentPrefill(dto);
  }

  @override
  Future<AdmissionsLead> createLead({
    required RepositoryQuery query,
    required CreateLeadRequest request,
  }) =>
      _remote.createLead(query: query, request: request);

  @override
  Future<AdmissionsLead> updateLead({
    required RepositoryQuery query,
    required String leadId,
    required UpdateLeadRequest request,
  }) =>
      _remote.updateLead(query: query, leadId: leadId, request: request);

  @override
  Future<AdmissionsLead> assignCounselor({
    required RepositoryQuery query,
    required String leadId,
    required AssignCounselorRequest request,
  }) =>
      _remote.assignCounselor(query: query, leadId: leadId, request: request);

  @override
  Future<AdmissionsLead> changeLeadStage({
    required RepositoryQuery query,
    required String leadId,
    required ChangeLeadStageRequest request,
  }) =>
      _remote.changeLeadStage(query: query, leadId: leadId, request: request);

  @override
  Future<LeadFollowUpRecord> addLeadFollowUp({
    required RepositoryQuery query,
    required String leadId,
    required FollowUpRequest request,
  }) =>
      _remote.addLeadFollowUp(query: query, leadId: leadId, request: request);

  @override
  Future<LeadActivityItem> addLeadNote({
    required RepositoryQuery query,
    required String leadId,
    required LeadNoteRequest request,
  }) =>
      _remote.addLeadNote(query: query, leadId: leadId, request: request);

  @override
  Future<AdmissionsApplication> createApplication({
    required RepositoryQuery query,
    required CreateApplicationRequest request,
  }) =>
      _remote.createApplication(query: query, request: request);

  @override
  Future<AdmissionsApplication> updateApplication({
    required RepositoryQuery query,
    required String applicationId,
    required UpdateApplicationRequest request,
  }) =>
      _remote.updateApplication(
        query: query,
        applicationId: applicationId,
        request: request,
      );

  @override
  Future<AdmissionsApplication> submitApplication({
    required RepositoryQuery query,
    required String applicationId,
  }) =>
      _remote.submitApplication(query: query, applicationId: applicationId);

  @override
  Future<PendingEnrollmentRecord> submitEnrollment({
    required RepositoryQuery query,
    required EnrollmentSubmitRequest request,
  }) =>
      _remote.submitEnrollment(query: query, request: request);

  @override
  Future<GeneratedAdmissionNumber> generateAdmissionNumber({
    required RepositoryQuery query,
    required GenerateAdmissionNumberRequest request,
  }) =>
      _remote.generateAdmissionNumber(query: query, request: request);

  @override
  Future<StudentDocumentRecord> uploadDocument({
    required RepositoryQuery query,
    required DocumentUploadRequest request,
  }) =>
      _remote.uploadDocument(query: query, request: request);

  @override
  Future<StudentDocumentRecord> approveDocument({
    required RepositoryQuery query,
    required String documentId,
    required DocumentVerificationRequest request,
  }) =>
      _remote.approveDocument(
        query: query,
        documentId: documentId,
        request: request,
      );

  @override
  Future<StudentDocumentRecord> rejectDocument({
    required RepositoryQuery query,
    required String documentId,
    required DocumentVerificationRequest request,
  }) =>
      _remote.rejectDocument(
        query: query,
        documentId: documentId,
        request: request,
      );

  @override
  Future<ApprovalQueueItem> approveAdmission({
    required RepositoryQuery query,
    required String approvalId,
    required ApprovalDecisionRequest request,
  }) =>
      _remote.approveAdmission(
        query: query,
        approvalId: approvalId,
        request: request,
      );

  @override
  Future<ApprovalQueueItem> rejectAdmission({
    required RepositoryQuery query,
    required String approvalId,
    required ApprovalDecisionRequest request,
  }) =>
      _remote.rejectAdmission(
        query: query,
        approvalId: approvalId,
        request: request,
      );

  @override
  Future<CounselorNote> addApprovalNote({
    required RepositoryQuery query,
    required String approvalId,
    required ApprovalNoteRequest request,
  }) =>
      _remote.addApprovalNote(
        query: query,
        approvalId: approvalId,
        request: request,
      );

  @override
  Future<ApprovedStudentHandoff> sendToFinance({
    required RepositoryQuery query,
    required FinanceHandoffRequest request,
  }) =>
      _remote.sendToFinance(query: query, request: request);

  @override
  Future<ApprovedStudentHandoff> updateHandoffStatus({
    required RepositoryQuery query,
    required String handoffId,
    required UpdateHandoffStatusRequest request,
  }) =>
      _remote.updateHandoffStatus(
        query: query,
        handoffId: handoffId,
        request: request,
      );
}
