import 'package:dio/dio.dart';

import '../../../repository_query.dart';
import '../../admissions/dto/api_envelope_dto.dart';
import '../../../../../features/student_app/student_requests.dart';
import '../dto/student_homework_submit_request_dto.dart';
import '../dto/student_responses_dto.dart';
import 'student_api_paths.dart';

/// Dio-backed remote data source for Student mobile APIs.
class StudentRemoteDataSource {
  StudentRemoteDataSource(this._dio);

  final Dio _dio;

  Future<StudentDashboardDto> fetchDashboard({
    required RepositoryQuery query,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      StudentApiPaths.dashboard,
      queryParameters: _queryParams(query),
    );
    return StudentDashboardDto.fromJson(_responseMap(response));
  }

  Future<StudentAttendanceResponseDto> fetchAttendance({
    required RepositoryQuery query,
    required DateTime month,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      StudentApiPaths.attendance,
      queryParameters: {
        ..._queryParams(query),
        'month': _monthParam(month),
      },
    );
    return StudentAttendanceResponseDto.fromJson(_responseMap(response));
  }

  Future<StudentHomeworkResponseDto> fetchHomeworkItems({
    required RepositoryQuery query,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      StudentApiPaths.homework,
      queryParameters: _queryParams(query),
    );
    return StudentHomeworkResponseDto.fromJson(_responseMap(response));
  }

  Future<StudentExamsResponseDto> fetchExams({
    required RepositoryQuery query,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      StudentApiPaths.exams,
      queryParameters: _queryParams(query),
    );
    return StudentExamsResponseDto.fromJson(_responseMap(response));
  }

  Future<StudentTimetableResponseDto> fetchTimetable({
    required RepositoryQuery query,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      StudentApiPaths.timetable,
      queryParameters: _queryParams(query),
    );
    return StudentTimetableResponseDto.fromJson(_responseMap(response));
  }

  Future<StudentNoticesResponseDto> fetchNotices({
    required RepositoryQuery query,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      StudentApiPaths.notices,
      queryParameters: _queryParams(query),
    );
    return StudentNoticesResponseDto.fromJson(_responseMap(response));
  }

  Future<StudentProfileResponseDto> fetchProfile({
    required RepositoryQuery query,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      StudentApiPaths.profile,
      queryParameters: _queryParams(query),
    );
    return StudentProfileResponseDto.fromJson(_responseMap(response));
  }

  Future<StudentHomeworkSubmitResponseDto> submitHomework({
    required RepositoryQuery query,
    required StudentHomeworkSubmitRequest request,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      StudentApiPaths.homeworkSubmit,
      queryParameters: _queryParams(query),
      data: StudentHomeworkSubmitRequestDto.fromDomain(request).toJson(),
    );
    return StudentHomeworkSubmitResponseDto.fromJson(_requireData(response));
  }

  /// PRA-P1-30 — presign a real submission attachment upload, returning the signed
  /// URL and the storage path to confirm with on submit.
  Future<({String signedUrl, String storagePath})> presignHomeworkAttachment({
    required RepositoryQuery query,
    required String homeworkId,
    required String fileName,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      StudentApiPaths.homeworkAttachmentPresign,
      queryParameters: _queryParams(query),
      data: {'homework_id': homeworkId, 'file_name': fileName},
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

  Map<String, dynamic> _queryParams(RepositoryQuery query) {
    return {
      'tenantId': query.tenantId,
      if (query.schoolId != null) 'schoolId': query.schoolId,
      if (query.organizationId != null) 'organizationId': query.organizationId,
    };
  }

  String _monthParam(DateTime month) {
    final m = month.month.toString().padLeft(2, '0');
    return '${month.year}-$m';
  }

  Map<String, dynamic> _responseMap(Response<Map<String, dynamic>> response) {
    return response.data ?? const {};
  }

  Map<String, dynamic> _requireData(Response<Map<String, dynamic>> response) {
    return ApiEnvelopeDto.fromJson(_responseMap(response)).requireData();
  }
}
