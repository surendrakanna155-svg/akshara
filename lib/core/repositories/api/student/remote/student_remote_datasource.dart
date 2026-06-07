import 'package:dio/dio.dart';

import '../../../repository_query.dart';
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
}
