import 'package:dio/dio.dart';

import '../../../repository_query.dart';
import '../../../../../features/hostel/hostel_requests.dart';
import '../../admissions/dto/api_envelope_dto.dart';
import '../dto/hostel_enum_codec.dart';
import '../dto/hostel_responses_dto.dart';
import 'hostel_api_paths.dart';

/// Dio-backed remote data source for Hostel.
class HostelRemoteDataSource {
  HostelRemoteDataSource(this._dio);

  final Dio _dio;

  Future<HostelDashboardDto> fetchDashboard({
    required RepositoryQuery query,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      HostelApiPaths.dashboard,
      queryParameters: _queryParams(query),
    );
    return HostelDashboardDto.fromJson(_responseMap(response));
  }

  Future<HostelStudentsResponseDto> fetchStudents({
    required RepositoryQuery query,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      HostelApiPaths.students,
      queryParameters: _queryParams(query),
    );
    return HostelStudentsResponseDto.fromJson(_responseMap(response));
  }

  Future<HostelRoomsResponseDto> fetchRooms({
    required RepositoryQuery query,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      HostelApiPaths.rooms,
      queryParameters: _queryParams(query),
    );
    return HostelRoomsResponseDto.fromJson(_responseMap(response));
  }

  Future<HostelAttendanceResponseDto> fetchAttendanceRecords({
    required RepositoryQuery query,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      HostelApiPaths.attendance,
      queryParameters: _queryParams(query),
    );
    return HostelAttendanceResponseDto.fromJson(_responseMap(response));
  }

  Future<HostelLeaveResponseDto> fetchLeaveRequests({
    required RepositoryQuery query,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      HostelApiPaths.leave,
      queryParameters: _queryParams(query),
    );
    return HostelLeaveResponseDto.fromJson(_responseMap(response));
  }

  Future<HostelMessResponseDto> fetchMessData({
    required RepositoryQuery query,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      HostelApiPaths.mess,
      queryParameters: _queryParams(query),
    );
    return HostelMessResponseDto.fromJson(_responseMap(response));
  }

  Future<HostelVisitorsResponseDto> fetchVisitors({
    required RepositoryQuery query,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      HostelApiPaths.visitors,
      queryParameters: _queryParams(query),
    );
    return HostelVisitorsResponseDto.fromJson(_responseMap(response));
  }

  Future<HostelReportsResponseDto> fetchReports({
    required RepositoryQuery query,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      HostelApiPaths.reports,
      queryParameters: _queryParams(query),
    );
    return HostelReportsResponseDto.fromJson(_responseMap(response));
  }

  Future<HostelOccupancyMetricsDto> fetchOccupancyMetrics({
    required RepositoryQuery query,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      HostelApiPaths.occupancyMetrics,
      queryParameters: _queryParams(query),
    );
    return HostelOccupancyMetricsDto.fromJson(_responseMap(response));
  }

  Future<HostelStudentDto> admitStudent({
    required RepositoryQuery query,
    required AdmitHostelStudentRequest request,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      HostelApiPaths.students,
      queryParameters: _queryParams(query),
      data: {
        'sisStudentId': request.sisStudentId,
        'studentName': request.studentName,
        'admissionNumber': request.admissionNumber,
        'classLabel': request.classLabel,
      },
    );
    return HostelStudentDto.fromJson(_writeData(response));
  }

  Future<HostelStudentDto> assignRoom({
    required RepositoryQuery query,
    required AssignHostelRoomRequest request,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      HostelApiPaths.assignRoom(request.hostelStudentId),
      queryParameters: _queryParams(query),
      data: {'roomId': request.roomId, 'bed': request.bed},
    );
    return HostelStudentDto.fromJson(_writeData(response));
  }

  Future<HostelStudentDto> checkoutStudent({
    required RepositoryQuery query,
    required CheckoutHostelStudentRequest request,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      HostelApiPaths.checkout(request.hostelStudentId),
      queryParameters: _queryParams(query),
      data: const <String, dynamic>{},
    );
    return HostelStudentDto.fromJson(_writeData(response));
  }

  Future<HostelRoomDto> createRoom({
    required RepositoryQuery query,
    required CreateHostelRoomRequest request,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      HostelApiPaths.rooms,
      queryParameters: _queryParams(query),
      data: {
        'block': request.block,
        'roomNumber': request.roomNumber,
        'floor': request.floor,
        'type': HostelEnumCodec.roomTypeToApi(request.type),
        'totalBeds': request.totalBeds,
        'facilities': request.facilities,
      },
    );
    return HostelRoomDto.fromJson(_writeData(response));
  }

  Future<HostelAttendanceRecordDto> recordAttendance({
    required RepositoryQuery query,
    required RecordHostelAttendanceRequest request,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      HostelApiPaths.recordAttendance,
      queryParameters: _queryParams(query),
      data: {
        'studentName': request.studentName,
        'room': request.room,
        'rollNumber': request.rollNumber,
        'morning': HostelEnumCodec.attendanceStatusToApi(request.morning),
        'evening': HostelEnumCodec.attendanceStatusToApi(request.evening),
        'night': HostelEnumCodec.attendanceStatusToApi(request.night),
        'remark': request.remark,
        'sisStudentId': request.sisStudentId,
      },
    );
    return HostelAttendanceRecordDto.fromJson(_writeData(response));
  }

  Future<HostelMealMenuDto> recordMess({
    required RepositoryQuery query,
    required RecordMessRequest request,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      HostelApiPaths.recordMess,
      queryParameters: _queryParams(query),
      data: {
        'day': request.day,
        'mealType': HostelEnumCodec.mealTypeToApi(request.mealType),
        'items': request.items,
        'dietaryTags': request.dietaryTags,
        'headcount': request.headcount,
        'costRupees': request.costRupees,
      },
    );
    return HostelMealMenuDto.fromJson(_writeData(response));
  }

  Future<HostelVisitorDto> logVisitor({
    required RepositoryQuery query,
    required LogVisitorRequest request,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      HostelApiPaths.visitors,
      queryParameters: _queryParams(query),
      data: {
        'visitorName': request.visitorName,
        'relation': request.relation,
        'studentName': request.studentName,
        'sisStudentId': request.sisStudentId,
      },
    );
    return HostelVisitorDto.fromJson(_writeData(response));
  }

  Map<String, dynamic> _queryParams(RepositoryQuery query) {
    return {
      'tenantId': query.tenantId,
      if (query.schoolId != null) 'schoolId': query.schoolId,
      if (query.organizationId != null) 'organizationId': query.organizationId,
    };
  }

  /// Unwraps the `{data, error}` envelope returned by write endpoints.
  Map<String, dynamic> _writeData(Response<Map<String, dynamic>> response) {
    return ApiEnvelopeDto.fromJson(_responseMap(response)).requireData();
  }

  Map<String, dynamic> _responseMap(Response<Map<String, dynamic>> response) {
    return response.data ?? const {};
  }
}
