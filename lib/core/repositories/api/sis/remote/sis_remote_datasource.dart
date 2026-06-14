import 'package:dio/dio.dart';

import '../../../repository_query.dart';
import '../../admissions/dto/api_envelope_dto.dart';
import '../../../../../features/sis/sis_models.dart';
import '../../../../../features/sis/sis_requests.dart';
import '../dto/admissions_conversion_request_dto.dart';
import '../dto/create_student_request_dto.dart';
import '../dto/enrollment_request_dto.dart';
import '../dto/sis_academic_assignment_dto.dart';
import '../dto/sis_conversion_dto.dart';
import '../dto/sis_dashboard_dto.dart';
import '../dto/sis_student_profile_dto.dart';
import '../dto/sis_students_dto.dart';
import '../dto/upload_student_document_request_dto.dart';
import '../dto/update_student_request_dto.dart';
import '../dto/update_student_status_request_dto.dart';
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
