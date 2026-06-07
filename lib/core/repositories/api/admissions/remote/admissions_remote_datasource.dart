import 'package:dio/dio.dart';

import '../../../repository_query.dart';
import '../../../../../features/admissions/admissions_models.dart';
import '../../../../../features/admissions/admissions_requests.dart';
import '../dto/admissions_applications_dto.dart';
import '../dto/admissions_approval_dto.dart';
import '../dto/admissions_dashboard_dto.dart';
import '../dto/admissions_documents_dto.dart';
import '../dto/admissions_enrollments_dto.dart';
import '../dto/admissions_handoffs_dto.dart';
import '../dto/admissions_leads_dto.dart';
import '../dto/admissions_reports_dto.dart';
import '../dto/admissions_settings_dto.dart';
import '../dto/api_envelope_dto.dart';
import '../dto/application_request_dto.dart';
import '../dto/approval_request_dto.dart';
import '../dto/assign_counselor_request_dto.dart';
import '../dto/create_lead_request_dto.dart';
import '../dto/document_verification_request_dto.dart';
import '../dto/enrollment_request_dto.dart';
import '../dto/finance_handoff_request_dto.dart';
import '../dto/followup_request_dto.dart';
import '../dto/update_lead_request_dto.dart';
import '../mapper/admissions_mapper.dart';
import 'admissions_api_paths.dart';

/// Dio-backed remote data source for Admissions.
class AdmissionsRemoteDataSource {
  AdmissionsRemoteDataSource(this._dio, {AdmissionsMapper mapper = const AdmissionsMapper()})
      : _mapper = mapper;

  final Dio _dio;
  final AdmissionsMapper _mapper;

  Future<AdmissionsDashboardDto> fetchDashboard({
    required RepositoryQuery query,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      AdmissionsApiPaths.dashboard,
      queryParameters: _queryParams(query),
    );
    return AdmissionsDashboardDto.fromJson(_responseMap(response));
  }

  Future<AdmissionsLeadsResponseDto> fetchLeads({
    required RepositoryQuery query,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      AdmissionsApiPaths.leads,
      queryParameters: _queryParams(query),
    );
    return AdmissionsLeadsResponseDto.fromJson(_responseMap(response));
  }

  Future<AdmissionsApplicationsResponseDto> fetchApplications({
    required RepositoryQuery query,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      AdmissionsApiPaths.applications,
      queryParameters: _queryParams(query),
    );
    return AdmissionsApplicationsResponseDto.fromJson(_responseMap(response));
  }

  Future<AdmissionsDocumentsResponseDto> fetchDocuments({
    required RepositoryQuery query,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      AdmissionsApiPaths.documents,
      queryParameters: _queryParams(query),
    );
    return AdmissionsDocumentsResponseDto.fromJson(_responseMap(response));
  }

  Future<AdmissionsEnrollmentsResponseDto> fetchPendingEnrollments({
    required RepositoryQuery query,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      AdmissionsApiPaths.enrollmentsPending,
      queryParameters: _queryParams(query),
    );
    return AdmissionsEnrollmentsResponseDto.fromJson(_responseMap(response));
  }

  Future<AdmissionsHandoffsResponseDto> fetchApprovedHandoffs({
    required RepositoryQuery query,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      AdmissionsApiPaths.handoffsApproved,
      queryParameters: _queryParams(query),
    );
    return AdmissionsHandoffsResponseDto.fromJson(_responseMap(response));
  }

  Future<AdmissionsFeeStructuresResponseDto> fetchFeeStructureOptions({
    required RepositoryQuery query,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      AdmissionsApiPaths.feeStructures,
      queryParameters: _queryParams(query),
    );
    return AdmissionsFeeStructuresResponseDto.fromJson(_responseMap(response));
  }

  Future<AdmissionsApprovalQueueResponseDto> fetchApprovalQueue({
    required RepositoryQuery query,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      AdmissionsApiPaths.approvalQueue,
      queryParameters: _queryParams(query),
    );
    return AdmissionsApprovalQueueResponseDto.fromJson(_responseMap(response));
  }

  Future<AdmissionsReportsDto> fetchReports({
    required RepositoryQuery query,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      AdmissionsApiPaths.reports,
      queryParameters: _queryParams(query),
    );
    return AdmissionsReportsDto.fromJson(_responseMap(response));
  }

  Future<AdmissionsSettingsDto> fetchSettings({
    required RepositoryQuery query,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      AdmissionsApiPaths.settings,
      queryParameters: _queryParams(query),
    );
    return AdmissionsSettingsDto.fromJson(_responseMap(response));
  }

  Future<EnrollmentPrefillDto> fetchEnrollmentPrefill({
    required RepositoryQuery query,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      AdmissionsApiPaths.enrollmentPrefill,
      queryParameters: _queryParams(query),
    );
    return EnrollmentPrefillDto.fromJson(_responseMap(response));
  }

  Future<AdmissionsLead> createLead({
    required RepositoryQuery query,
    required CreateLeadRequest request,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      AdmissionsApiPaths.leads,
      queryParameters: _queryParams(query),
      data: CreateLeadRequestDto.fromDomain(request).toJson(),
    );
    return _mapper.toLead(
      AdmissionsLeadDto.fromJson(_requireData(response)),
    );
  }

  Future<AdmissionsLead> updateLead({
    required RepositoryQuery query,
    required String leadId,
    required UpdateLeadRequest request,
  }) async {
    final response = await _dio.put<Map<String, dynamic>>(
      AdmissionsApiPaths.lead(leadId),
      queryParameters: _queryParams(query),
      data: UpdateLeadRequestDto.fromDomain(request).toJson(),
    );
    return _mapper.toLead(
      AdmissionsLeadDto.fromJson(_requireData(response)),
    );
  }

  Future<AdmissionsLead> assignCounselor({
    required RepositoryQuery query,
    required String leadId,
    required AssignCounselorRequest request,
  }) async {
    final response = await _dio.patch<Map<String, dynamic>>(
      AdmissionsApiPaths.leadAssign(leadId),
      queryParameters: _queryParams(query),
      data: AssignCounselorRequestDto.fromDomain(request).toJson(),
    );
    return _mapper.toLead(
      AdmissionsLeadDto.fromJson(_requireData(response)),
    );
  }

  Future<AdmissionsLead> changeLeadStage({
    required RepositoryQuery query,
    required String leadId,
    required ChangeLeadStageRequest request,
  }) async {
    final response = await _dio.patch<Map<String, dynamic>>(
      AdmissionsApiPaths.leadStage(leadId),
      queryParameters: _queryParams(query),
      data: ChangeLeadStageRequestDto.fromDomain(request).toJson(),
    );
    return _mapper.toLead(
      AdmissionsLeadDto.fromJson(_requireData(response)),
    );
  }

  Future<LeadFollowUpRecord> addLeadFollowUp({
    required RepositoryQuery query,
    required String leadId,
    required FollowUpRequest request,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      AdmissionsApiPaths.leadFollowUps(leadId),
      queryParameters: _queryParams(query),
      data: FollowUpRequestDto.fromDomain(request).toJson(),
    );
    return _mapper.toFollowUpRecord(_requireData(response));
  }

  Future<LeadActivityItem> addLeadNote({
    required RepositoryQuery query,
    required String leadId,
    required LeadNoteRequest request,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      AdmissionsApiPaths.leadNotes(leadId),
      queryParameters: _queryParams(query),
      data: LeadNoteRequestDto.fromDomain(request).toJson(),
    );
    return _mapper.toLeadActivityItem(_requireData(response));
  }

  Future<AdmissionsApplication> createApplication({
    required RepositoryQuery query,
    required CreateApplicationRequest request,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      AdmissionsApiPaths.applications,
      queryParameters: _queryParams(query),
      data: ApplicationRequestDto.create(request).toJson(),
    );
    return _mapper.toApplication(
      AdmissionsApplicationDto.fromJson(_requireData(response)),
    );
  }

  Future<AdmissionsApplication> updateApplication({
    required RepositoryQuery query,
    required String applicationId,
    required UpdateApplicationRequest request,
  }) async {
    final response = await _dio.put<Map<String, dynamic>>(
      AdmissionsApiPaths.application(applicationId),
      queryParameters: _queryParams(query),
      data: ApplicationRequestDto.update(request).toJson(),
    );
    return _mapper.toApplication(
      AdmissionsApplicationDto.fromJson(_requireData(response)),
    );
  }

  Future<AdmissionsApplication> submitApplication({
    required RepositoryQuery query,
    required String applicationId,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      AdmissionsApiPaths.applicationSubmit(applicationId),
      queryParameters: _queryParams(query),
    );
    return _mapper.toApplication(
      AdmissionsApplicationDto.fromJson(_requireData(response)),
    );
  }

  Future<PendingEnrollmentRecord> submitEnrollment({
    required RepositoryQuery query,
    required EnrollmentSubmitRequest request,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      AdmissionsApiPaths.enrollments,
      queryParameters: _queryParams(query),
      data: EnrollmentRequestDto.submit(request).toJson(),
    );
    return _mapper.toPendingEnrollment(
      PendingEnrollmentDto.fromJson(_requireData(response)),
    );
  }

  Future<GeneratedAdmissionNumber> generateAdmissionNumber({
    required RepositoryQuery query,
    required GenerateAdmissionNumberRequest request,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      AdmissionsApiPaths.enrollmentsGenerateNumber,
      queryParameters: _queryParams(query),
      data: EnrollmentRequestDto.generateNumber(request).toJson(),
    );
    return _mapper.toGeneratedAdmissionNumber(_requireData(response));
  }

  Future<StudentDocumentRecord> uploadDocument({
    required RepositoryQuery query,
    required DocumentUploadRequest request,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      AdmissionsApiPaths.documentsUpload,
      queryParameters: _queryParams(query),
      data: DocumentUploadRequestDto.fromDomain(request).toJson(),
    );
    return _mapper.toDocument(
      StudentDocumentDto.fromJson(_requireData(response)),
    );
  }

  Future<StudentDocumentRecord> approveDocument({
    required RepositoryQuery query,
    required String documentId,
    required DocumentVerificationRequest request,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      AdmissionsApiPaths.documentApprove(documentId),
      queryParameters: _queryParams(query),
      data: DocumentVerificationRequestDto.fromDomain(request).toJson(),
    );
    return _mapper.toDocument(
      StudentDocumentDto.fromJson(_requireData(response)),
    );
  }

  Future<StudentDocumentRecord> rejectDocument({
    required RepositoryQuery query,
    required String documentId,
    required DocumentVerificationRequest request,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      AdmissionsApiPaths.documentReject(documentId),
      queryParameters: _queryParams(query),
      data: DocumentVerificationRequestDto.fromDomain(request).toJson(),
    );
    return _mapper.toDocument(
      StudentDocumentDto.fromJson(_requireData(response)),
    );
  }

  Future<ApprovalQueueItem> approveAdmission({
    required RepositoryQuery query,
    required String approvalId,
    required ApprovalDecisionRequest request,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      AdmissionsApiPaths.approvalApprove(approvalId),
      queryParameters: _queryParams(query),
      data: ApprovalRequestDto.decision(request).toJson(),
    );
    return _mapper.toApprovalQueueItem(
      ApprovalQueueItemDto.fromJson(_requireData(response)),
    );
  }

  Future<ApprovalQueueItem> rejectAdmission({
    required RepositoryQuery query,
    required String approvalId,
    required ApprovalDecisionRequest request,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      AdmissionsApiPaths.approvalReject(approvalId),
      queryParameters: _queryParams(query),
      data: ApprovalRequestDto.decision(request).toJson(),
    );
    return _mapper.toApprovalQueueItem(
      ApprovalQueueItemDto.fromJson(_requireData(response)),
    );
  }

  Future<CounselorNote> addApprovalNote({
    required RepositoryQuery query,
    required String approvalId,
    required ApprovalNoteRequest request,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      AdmissionsApiPaths.approvalNotes(approvalId),
      queryParameters: _queryParams(query),
      data: ApprovalRequestDto.note(request).toJson(),
    );
    return _mapper.toCounselorNote(_requireData(response));
  }

  Future<ApprovedStudentHandoff> sendToFinance({
    required RepositoryQuery query,
    required FinanceHandoffRequest request,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      AdmissionsApiPaths.handoffsSend,
      queryParameters: _queryParams(query),
      data: FinanceHandoffRequestDto.send(request).toJson(),
    );
    return _mapper.toApprovedHandoff(
      ApprovedStudentHandoffDto.fromJson(_requireData(response)),
    );
  }

  Future<ApprovedStudentHandoff> updateHandoffStatus({
    required RepositoryQuery query,
    required String handoffId,
    required UpdateHandoffStatusRequest request,
  }) async {
    final response = await _dio.patch<Map<String, dynamic>>(
      AdmissionsApiPaths.handoffStatus(handoffId),
      queryParameters: _queryParams(query),
      data: FinanceHandoffRequestDto.updateStatus(request).toJson(),
    );
    return _mapper.toApprovedHandoff(
      ApprovedStudentHandoffDto.fromJson(_requireData(response)),
    );
  }

  Map<String, dynamic> _queryParams(RepositoryQuery query) {
    return {
      'tenantId': query.tenantId,
      if (query.schoolId != null) 'schoolId': query.schoolId,
      if (query.organizationId != null) 'organizationId': query.organizationId,
    };
  }

  Map<String, dynamic> _responseMap(Response<Map<String, dynamic>> response) {
    return response.data ?? const {};
  }

  Map<String, dynamic> _requireData(Response<Map<String, dynamic>> response) {
    return ApiEnvelopeDto.fromJson(_responseMap(response)).requireData();
  }
}
