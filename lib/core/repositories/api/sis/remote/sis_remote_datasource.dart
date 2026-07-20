import 'package:dio/dio.dart';

import '../../../repository_query.dart';
import '../../admissions/dto/api_envelope_dto.dart';
import '../../../../../features/sis/sis_models.dart';
import '../../../../../features/sis/sis_requests.dart';
import '../dto/admissions_conversion_request_dto.dart';
import '../dto/create_student_request_dto.dart';
import '../dto/enrollment_request_dto.dart';
import '../dto/sis_certificate_dto.dart';
import '../dto/sis_academic_assignment_dto.dart';
import '../dto/sis_conversion_dto.dart';
import '../dto/sis_dashboard_dto.dart';
import '../dto/sis_enum_codec.dart';
import '../dto/sis_siblings_dto.dart';
import '../dto/sis_student_profile_dto.dart';
import '../dto/sis_students_dto.dart';
import '../dto/sis_transfers_dto.dart';
import '../dto/upload_student_document_request_dto.dart';
import '../dto/update_student_request_dto.dart';
import '../dto/update_student_status_request_dto.dart';
import '../dto/verify_student_document_request_dto.dart';
import '../mapper/sis_mapper.dart';
import 'sis_api_paths.dart';

/// Dio-backed remote data source for SIS.
class SisRemoteDataSource {
  SisRemoteDataSource(this._dio, {SisMapper mapper = const SisMapper()})
      : _mapper = mapper;

  final Dio _dio;
  final SisMapper _mapper;

  Future<SisDashboardDto> fetchDashboard({
    required RepositoryQuery query,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      SisApiPaths.dashboard,
      queryParameters: _queryParams(query),
    );
    return SisDashboardDto.fromJson(_responseMap(response));
  }

  Future<SisStudentsResponseDto> fetchStudents({
    required RepositoryQuery query,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      SisApiPaths.students,
      queryParameters: _queryParams(query),
    );
    return SisStudentsResponseDto.fromJson(_responseMap(response));
  }

  /// SIS-5 — GET /sis/transfers?from&to&status (paginated like /sis/students).
  Future<SisTransfersResponseDto> fetchStudentTransfers({
    required RepositoryQuery query,
    String? fromDate,
    String? toDate,
    SisStudentStatus? status,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      SisApiPaths.transfers,
      queryParameters: {
        ..._queryParams(query),
        if (fromDate != null && fromDate.isNotEmpty) 'from': fromDate,
        if (toDate != null && toDate.isNotEmpty) 'to': toDate,
        if (status != null) 'status': SisEnumCodec.studentStatusToApi(status),
      },
    );
    return SisTransfersResponseDto.fromJson(_responseMap(response));
  }

  Future<SisStudentProfileDto> fetchStudentProfile({
    required RepositoryQuery query,
    required String studentId,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      SisApiPaths.studentProfile(studentId),
      queryParameters: _queryParams(query),
    );
    return SisStudentProfileDto.fromJson(_responseMap(response));
  }

  /// SIS-4 — GET /sis/students/{id}/siblings. Read-only shared-guardian family
  /// list, self-excluded, scoped to the caller's school.
  Future<List<SisSibling>> listStudentSiblings({
    required RepositoryQuery query,
    required String studentId,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      SisApiPaths.studentSiblings(studentId),
      queryParameters: _queryParams(query),
    );
    final dto = SisSiblingsResponseDto.fromJson(_responseMap(response));
    return [for (final item in dto.items) _mapper.toSibling(item.raw)];
  }

  Future<SisAcademicAssignmentDto> fetchAcademicAssignment({
    required RepositoryQuery query,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      SisApiPaths.academicAssignment,
      queryParameters: _queryParams(query),
    );
    return SisAcademicAssignmentDto.fromJson(_responseMap(response));
  }

  Future<SisConversionResponseDto> fetchAdmissionsConversion({
    required RepositoryQuery query,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      SisApiPaths.admissionsConversion,
      queryParameters: _queryParams(query),
    );
    return SisConversionResponseDto.fromJson(_responseMap(response));
  }

  Future<SisStudent> createStudent({
    required RepositoryQuery query,
    required CreateStudentRequest request,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      SisApiPaths.students,
      queryParameters: _queryParams(query),
      data: CreateStudentRequestDto.fromDomain(request).toJson(),
    );
    return _mapper.toStudentFromWriteResponse(_requireData(response));
  }

  Future<SisStudent> updateStudent({
    required RepositoryQuery query,
    required String studentId,
    required UpdateStudentRequest request,
  }) async {
    final response = await _dio.put<Map<String, dynamic>>(
      SisApiPaths.studentProfile(studentId),
      queryParameters: _queryParams(query),
      data: UpdateStudentRequestDto.fromDomain(request).toJson(),
    );
    return _mapper.toStudentFromWriteResponse(_requireData(response));
  }

  Future<SisDocumentSummary> uploadStudentDocument({
    required RepositoryQuery query,
    required String studentId,
    required UploadStudentDocumentRequest request,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      SisApiPaths.studentDocuments(studentId),
      queryParameters: _queryParams(query),
      data: UploadStudentDocumentRequestDto.fromDomain(request).toJson(),
    );
    return _mapper.toDocumentSummary(_requireData(response));
  }

  /// PRA-P1-19 — presign a direct-to-Storage upload, returning the signed URL and
  /// the storage path to confirm with afterwards.
  Future<({String signedUrl, String storagePath})> presignStudentDocumentUpload({
    required RepositoryQuery query,
    required String studentId,
    required String fileName,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      SisApiPaths.studentDocumentsPresign(studentId),
      queryParameters: _queryParams(query),
      data: {'file_name': fileName},
    );
    final data = _requireData(response);
    return (
      signedUrl: data['signedUrl'] as String? ?? '',
      storagePath: data['storagePath'] as String? ?? '',
    );
  }

  /// PUT file bytes to the Supabase signed upload URL (separate host from API).
  Future<void> putSignedUpload({
    required String signedUrl,
    required List<int> bytes,
    required String contentType,
  }) async {
    final uploadClient = Dio(
      BaseOptions(
        headers: {'Content-Type': contentType},
        validateStatus: (status) => status != null && status < 500,
      ),
    );
    final response = await uploadClient.put<List<int>>(
      signedUrl,
      data: bytes,
      options: Options(responseType: ResponseType.bytes),
    );
    if (response.statusCode == null || response.statusCode! >= 400) {
      throw DioException(
        requestOptions: response.requestOptions,
        response: response,
        message: 'Upload failed (${response.statusCode})',
      );
    }
  }

  /// PRA-P1-19 — resolve a signed download URL for a stored document.
  Future<String> fetchStudentDocumentDownloadUrl({
    required RepositoryQuery query,
    required String studentId,
    required String documentId,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      SisApiPaths.studentDocumentDownload(studentId, documentId),
      queryParameters: _queryParams(query),
    );
    return _requireData(response)['downloadUrl'] as String? ?? '';
  }

  /// SIS-3 — PATCH /sis/students/{id}/documents/{docId}/verify. Response is
  /// the updated document envelope incl. status / verifiedBy / verifiedAt.
  Future<SisDocumentSummary> verifyStudentDocument({
    required RepositoryQuery query,
    required String studentId,
    required String documentId,
    required VerifyStudentDocumentRequest request,
  }) async {
    final response = await _dio.patch<Map<String, dynamic>>(
      SisApiPaths.studentDocumentVerify(studentId, documentId),
      queryParameters: _queryParams(query),
      data: VerifyStudentDocumentRequestDto.fromDomain(request).toJson(),
    );
    return _mapper.toDocumentSummary(_requireData(response));
  }

  Future<SisStudent> updateStudentStatus({
    required RepositoryQuery query,
    required String studentId,
    required UpdateStudentStatusRequest request,
  }) async {
    final response = await _dio.patch<Map<String, dynamic>>(
      SisApiPaths.studentStatus(studentId),
      queryParameters: _queryParams(query),
      data: UpdateStudentStatusRequestDto.fromDomain(request).toJson(),
    );
    return _mapper.toStudentFromWriteResponse(_requireData(response));
  }

  /// SIS-1 — POST /sis/students/{id}/certificates. Returns the certificate DATA
  /// for the client PDF.
  Future<SisCertificateData> issueCertificate({
    required RepositoryQuery query,
    required String studentId,
    required IssueCertificateRequest request,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      SisApiPaths.studentCertificates(studentId),
      queryParameters: _queryParams(query),
      data: IssueCertificateRequestDto.fromDomain(request).toJson(),
    );
    return _mapper.toCertificateData(_requireData(response));
  }

  /// SIS-D1 — POST /sis/students/{id}/transfer-certificate. Returns the TC DATA
  /// (with serial) or surfaces 409 DUES_PENDING via the interceptor.
  Future<SisCertificateData> issueTransferCertificate({
    required RepositoryQuery query,
    required String studentId,
    required IssueTransferCertificateRequest request,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      SisApiPaths.studentTransferCertificate(studentId),
      queryParameters: _queryParams(query),
      data: IssueTransferCertificateRequestDto.fromDomain(request).toJson(),
    );
    return _mapper.toCertificateData(_requireData(response));
  }

  /// SIS-1 — GET /sis/students/{id}/certificates. The issuance register.
  Future<List<SisCertificateIssue>> listCertificates({
    required RepositoryQuery query,
    required String studentId,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      SisApiPaths.studentCertificates(studentId),
      queryParameters: _queryParams(query),
    );
    final dto = SisCertificateRegisterDto.fromJson(_responseMap(response));
    return [for (final item in dto.items) _mapper.toCertificateIssue(item)];
  }

  Future<SisStudent> assignAcademicAssignment({
    required RepositoryQuery query,
    required AcademicAssignmentRequest request,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      SisApiPaths.enrollments,
      queryParameters: _queryParams(query),
      data: EnrollmentCreateRequestDto.fromAcademicAssignment(request).toJson(),
    );
    return _mapper.toStudentFromEnrollment(_requireData(response));
  }

  Future<SisConversionPreview> convertAdmissionsEnrollment({
    required RepositoryQuery query,
    required AdmissionsConversionRequest request,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      SisApiPaths.admissionsConversion,
      queryParameters: _queryParams(query),
      data: AdmissionsConversionRequestDto.fromDomain(request).toJson(),
    );
    return _mapper.toConversionPreview(
      SisConversionPreviewDto.fromJson(_requireData(response)),
    );
  }

  Map<String, dynamic> _queryParams(RepositoryQuery query) {
    return {
      'tenantId': query.tenantId,
      if (query.schoolId != null) 'schoolId': query.schoolId,
      if (query.organizationId != null) 'organizationId': query.organizationId,
      ...query.paginationQueryParams(),
    };
  }

  Map<String, dynamic> _responseMap(Response<Map<String, dynamic>> response) {
    return response.data ?? const {};
  }

  Map<String, dynamic> _requireData(Response<Map<String, dynamic>> response) {
    return ApiEnvelopeDto.fromJson(_responseMap(response)).requireData();
  }
}
