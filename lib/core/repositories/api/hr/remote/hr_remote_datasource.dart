import 'package:dio/dio.dart';

import '../../../repository_query.dart';
import '../dto/hr_responses_dto.dart';
import 'hr_api_paths.dart';

/// Dio-backed remote data source for HR.
class HrRemoteDataSource {
  HrRemoteDataSource(this._dio);

  final Dio _dio;

  Future<HrDashboardDto> fetchDashboard({
    required RepositoryQuery query,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      HrApiPaths.dashboard,
      queryParameters: _queryParams(query),
    );
    return HrDashboardDto.fromJson(_responseMap(response));
  }

  Future<HrEmployeesResponseDto> fetchEmployees({
    required RepositoryQuery query,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      HrApiPaths.employees,
      queryParameters: _queryParams(query),
    );
    return HrEmployeesResponseDto.fromJson(_responseMap(response));
  }

  Future<HrEmployeeDetailDto> fetchEmployeeDetail({
    required RepositoryQuery query,
    required String employeeId,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      HrApiPaths.employeeDetail(employeeId),
      queryParameters: _queryParams(query),
    );
    return HrEmployeeDetailDto.fromJson(_responseMap(response));
  }

  Future<HrAttendanceResponseDto> fetchAttendance({
    required RepositoryQuery query,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      HrApiPaths.attendance,
      queryParameters: _queryParams(query),
    );
    return HrAttendanceResponseDto.fromJson(_responseMap(response));
  }

  Future<HrLeaveResponseDto> fetchLeave({
    required RepositoryQuery query,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      HrApiPaths.leave,
      queryParameters: _queryParams(query),
    );
    return HrLeaveResponseDto.fromJson(_responseMap(response));
  }

  Future<HrPayrollResponseDto> fetchPayroll({
    required RepositoryQuery query,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      HrApiPaths.payroll,
      queryParameters: _queryParams(query),
    );
    return HrPayrollResponseDto.fromJson(_responseMap(response));
  }

  Future<HrRecruitmentResponseDto> fetchRecruitment({
    required RepositoryQuery query,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      HrApiPaths.recruitment,
      queryParameters: _queryParams(query),
    );
    return HrRecruitmentResponseDto.fromJson(_responseMap(response));
  }

  Future<HrPerformanceResponseDto> fetchPerformance({
    required RepositoryQuery query,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      HrApiPaths.performance,
      queryParameters: _queryParams(query),
    );
    return HrPerformanceResponseDto.fromJson(_responseMap(response));
  }

  Future<HrSettingsResponseDto> fetchSettings({
    required RepositoryQuery query,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      HrApiPaths.settings,
      queryParameters: _queryParams(query),
    );
    return HrSettingsResponseDto.fromJson(_responseMap(response));
  }

  Future<HrLeaveRequestDto> approveLeaveRequest({
    required RepositoryQuery query,
    required String leaveRequestId,
    required String comment,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      HrApiPaths.approveLeave(leaveRequestId),
      queryParameters: _queryParams(query),
      data: {'comment': comment},
    );
    return HrLeaveRequestDto.fromJson(_responseMap(response));
  }

  Future<HrLeaveRequestDto> rejectLeaveRequest({
    required RepositoryQuery query,
    required String leaveRequestId,
    required String comment,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      HrApiPaths.rejectLeave(leaveRequestId),
      queryParameters: _queryParams(query),
      data: {'comment': comment},
    );
    return HrLeaveRequestDto.fromJson(_responseMap(response));
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
}
