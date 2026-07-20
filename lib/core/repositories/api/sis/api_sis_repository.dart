import '../../interfaces/sis_repository.dart';
import '../../paginated_result.dart';
import '../../repository_query.dart';
import '../../../../features/sis/sis_models.dart';
import '../../../../features/sis/sis_requests.dart';
import 'mapper/sis_mapper.dart';
import 'remote/sis_remote_datasource.dart';

/// API implementation of [SisRepository] — enabled via [sisApiEnabledProvider].
class ApiSisRepository implements SisRepository {
  ApiSisRepository({
    required SisRemoteDataSource remote,
    SisMapper mapper = const SisMapper(),
  })  : _remote = remote,
        _mapper = mapper;

  final SisRemoteDataSource _remote;
  final SisMapper _mapper;

  @override
  Future<SisDashboardData> getDashboard(
      {required RepositoryQuery query}) async {
    final dto = await _remote.fetchDashboard(query: query);
    return _mapper.toDashboard(dto);
  }

  @override
  Future<PaginatedResult<SisStudent>> getStudents({
    required RepositoryQuery query,
  }) async {
    final dto = await _remote.fetchStudents(query: query);
    return PaginatedResult.fromDto(
      items: _mapper.toStudents(dto),
      pagination: dto.pagination,
      fallbackPage: query.page,
      fallbackPageSize: query.pageSize,
    );
  }

  @override
  Future<SisStudentProfile> getStudentProfile({
    required RepositoryQuery query,
    required String studentId,
  }) async {
    final dto = await _remote.fetchStudentProfile(
      query: query,
      studentId: studentId,
    );
    return _mapper.toStudentProfile(dto);
  }

  @override
  Future<SisAcademicAssignmentData> getAcademicAssignment({
    required RepositoryQuery query,
  }) async {
    final dto = await _remote.fetchAcademicAssignment(query: query);
    return _mapper.toAcademicAssignment(dto);
  }

  @override
  Future<SisAdmissionsConversionData> getAdmissionsConversion({
    required RepositoryQuery query,
  }) async {
    final dto = await _remote.fetchAdmissionsConversion(query: query);
    return _mapper.toAdmissionsConversion(dto);
  }

  @override
  Future<SisStudent> createStudent({
    required RepositoryQuery query,
    required CreateStudentRequest request,
  }) async {
    return _remote.createStudent(query: query, request: request);
  }

  @override
  Future<SisStudent> updateStudent({
    required RepositoryQuery query,
    required String studentId,
    required UpdateStudentRequest request,
  }) async {
    return _remote.updateStudent(
      query: query,
      studentId: studentId,
      request: request,
    );
  }

  @override
  Future<SisDocumentSummary> uploadStudentDocument({
    required RepositoryQuery query,
    required String studentId,
    required UploadStudentDocumentRequest request,
  }) async {
    return _remote.uploadStudentDocument(
      query: query,
      studentId: studentId,
      request: request,
    );
  }

  @override
  Future<SisDocumentSummary> uploadStudentDocumentFile({
    required RepositoryQuery query,
    required String studentId,
    required UploadStudentDocumentRequest request,
    required List<int> bytes,
    required String contentType,
  }) async {
    // PRA-P1-19: presign → PUT bytes → confirm with the real storage_path.
    final presign = await _remote.presignStudentDocumentUpload(
      query: query,
      studentId: studentId,
      fileName: request.fileName,
    );
    await _remote.putSignedUpload(
      signedUrl: presign.signedUrl,
      bytes: bytes,
      contentType: contentType,
    );
    return _remote.uploadStudentDocument(
      query: query,
      studentId: studentId,
      request: UploadStudentDocumentRequest(
        type: request.type,
        fileName: request.fileName,
        status: request.status,
        storagePath: presign.storagePath,
      ),
    );
  }

  @override
  Future<String> getStudentDocumentDownloadUrl({
    required RepositoryQuery query,
    required String studentId,
    required String documentId,
  }) async {
    return _remote.fetchStudentDocumentDownloadUrl(
      query: query,
      studentId: studentId,
      documentId: documentId,
    );
  }

  @override
  Future<SisDocumentSummary> verifyStudentDocument({
    required RepositoryQuery query,
    required String studentId,
    required String documentId,
    required VerifyStudentDocumentRequest request,
  }) async {
    return _remote.verifyStudentDocument(
      query: query,
      studentId: studentId,
      documentId: documentId,
      request: request,
    );
  }

  @override
  Future<List<SisSibling>> listStudentSiblings({
    required RepositoryQuery query,
    required String studentId,
  }) async {
    return _remote.listStudentSiblings(query: query, studentId: studentId);
  }

  @override
  Future<PaginatedResult<SisTransferRecord>> listStudentTransfers({
    required RepositoryQuery query,
    String? fromDate,
    String? toDate,
    SisStudentStatus? status,
  }) async {
    final dto = await _remote.fetchStudentTransfers(
      query: query,
      fromDate: fromDate,
      toDate: toDate,
      status: status,
    );
    return PaginatedResult.fromDto(
      items: _mapper.toTransferRecords(dto),
      pagination: dto.pagination,
      fallbackPage: query.page,
      fallbackPageSize: query.pageSize,
    );
  }

  @override
  Future<SisStudent> updateStudentStatus({
    required RepositoryQuery query,
    required String studentId,
    required UpdateStudentStatusRequest request,
  }) async {
    return _remote.updateStudentStatus(
      query: query,
      studentId: studentId,
      request: request,
    );
  }

  @override
  Future<SisCertificateData> issueCertificate({
    required RepositoryQuery query,
    required String studentId,
    required IssueCertificateRequest request,
  }) async {
    return _remote.issueCertificate(
      query: query,
      studentId: studentId,
      request: request,
    );
  }

  @override
  Future<SisCertificateData> issueTransferCertificate({
    required RepositoryQuery query,
    required String studentId,
    required IssueTransferCertificateRequest request,
  }) async {
    return _remote.issueTransferCertificate(
      query: query,
      studentId: studentId,
      request: request,
    );
  }

  @override
  Future<List<SisCertificateIssue>> listCertificates({
    required RepositoryQuery query,
    required String studentId,
  }) async {
    return _remote.listCertificates(query: query, studentId: studentId);
  }

  @override
  Future<SisStudent> assignAcademicAssignment({
    required RepositoryQuery query,
    required AcademicAssignmentRequest request,
  }) async {
    return _remote.assignAcademicAssignment(query: query, request: request);
  }

  @override
  Future<SisConversionPreview> convertAdmissionsEnrollment({
    required RepositoryQuery query,
    required AdmissionsConversionRequest request,
  }) async {
    return _remote.convertAdmissionsEnrollment(query: query, request: request);
  }
}
