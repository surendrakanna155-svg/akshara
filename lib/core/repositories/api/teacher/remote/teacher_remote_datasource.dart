import 'package:dio/dio.dart';

import '../../../repository_query.dart';
import '../dto/teacher_responses_dto.dart';
import 'teacher_api_paths.dart';

/// Dio-backed remote data source for Teacher mobile APIs.
class TeacherRemoteDataSource {
  TeacherRemoteDataSource(this._dio);

  final Dio _dio;

  Future<TeacherDashboardDto> fetchDashboard({
    required RepositoryQuery query,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      TeacherApiPaths.dashboard,
      queryParameters: _queryParams(query),
    );
    return TeacherDashboardDto.fromJson(_responseMap(response));
  }

  Future<TeacherAttendanceClassesResponseDto> fetchAttendanceClasses({
    required RepositoryQuery query,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      TeacherApiPaths.attendanceClasses,
      queryParameters: _queryParams(query),
    );
    return TeacherAttendanceClassesResponseDto.fromJson(_responseMap(response));
  }

  Future<TeacherAttendanceStudentsResponseDto> fetchAttendanceStudentsByClass({
    required RepositoryQuery query,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      TeacherApiPaths.attendanceStudents,
      queryParameters: _queryParams(query),
    );
    return TeacherAttendanceStudentsResponseDto.fromJson(_responseMap(response));
  }

  Future<TeacherHomeworkResponseDto> fetchHomeworkAssignments({
    required RepositoryQuery query,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      TeacherApiPaths.homework,
      queryParameters: _queryParams(query),
    );
    return TeacherHomeworkResponseDto.fromJson(_responseMap(response));
  }

  Future<TeacherUpcomingExamsResponseDto> fetchUpcomingExams({
    required RepositoryQuery query,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      TeacherApiPaths.examsUpcoming,
      queryParameters: _queryParams(query),
    );
    return TeacherUpcomingExamsResponseDto.fromJson(_responseMap(response));
  }

  Future<TeacherExamMarksResponseDto> fetchExamMarks({
    required RepositoryQuery query,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      TeacherApiPaths.examsMarks,
      queryParameters: _queryParams(query),
    );
    return TeacherExamMarksResponseDto.fromJson(_responseMap(response));
  }

  Future<TeacherTimetableResponseDto> fetchTimetable({
    required RepositoryQuery query,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      TeacherApiPaths.timetable,
      queryParameters: _queryParams(query),
    );
    return TeacherTimetableResponseDto.fromJson(_responseMap(response));
  }

  Future<TeacherLeaveResponseDto> fetchLeaveHistory({
    required RepositoryQuery query,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      TeacherApiPaths.leave,
      queryParameters: _queryParams(query),
    );
    return TeacherLeaveResponseDto.fromJson(_responseMap(response));
  }

  Future<TeacherLeaveBalanceResponseDto> fetchLeaveBalance({
    required RepositoryQuery query,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      TeacherApiPaths.leaveBalance,
      queryParameters: _queryParams(query),
    );
    return TeacherLeaveBalanceResponseDto.fromJson(_responseMap(response));
  }

  Future<TeacherMessagesResponseDto> fetchMessageThreads({
    required RepositoryQuery query,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      TeacherApiPaths.messages,
      queryParameters: _queryParams(query),
    );
    return TeacherMessagesResponseDto.fromJson(_responseMap(response));
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
}
