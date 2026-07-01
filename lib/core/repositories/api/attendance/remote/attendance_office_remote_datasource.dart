import 'package:dio/dio.dart';

import '../../../repository_query.dart';
import '../../admissions/dto/api_envelope_dto.dart';
import '../../../../attendance/attendance_office_models.dart';
import '../mapper/attendance_office_mapper.dart';
import 'attendance_api_paths.dart';

/// Remote datasource for OFFICE / ADMIN attendance reads (ATT-1, ATT-2, ATT-4,
/// ATT-D1, ATT-D2).
class AttendanceOfficeRemoteDataSource {
  AttendanceOfficeRemoteDataSource(
    this._dio, {
    AttendanceOfficeMapper mapper = const AttendanceOfficeMapper(),
  }) : _mapper = mapper;

  final Dio _dio;
  final AttendanceOfficeMapper _mapper;

  Future<List<AttendanceRegisterEntry>> fetchRegister({
    required RepositoryQuery query,
    required String classLabel,
    required DateTime date,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      AttendanceApiPaths.register,
      queryParameters: {
        ..._queryParams(query),
        'classLabel': classLabel,
        'date': _formatDate(date),
      },
    );
    return _mapper.registerList(_listData(_responseMap(response)));
  }

  Future<MonthlyRegister> fetchMonthlyRegister({
    required RepositoryQuery query,
    required String classLabel,
    required String month,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      AttendanceApiPaths.monthlyRegister,
      queryParameters: {
        ..._queryParams(query),
        'classLabel': classLabel,
        'month': month,
      },
    );
    return _mapper.monthlyRegister(_requireData(response));
  }

  Future<List<PendingAttendanceClass>> fetchPending({
    required RepositoryQuery query,
    required DateTime date,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      AttendanceApiPaths.pending,
      queryParameters: {
        ..._queryParams(query),
        'date': _formatDate(date),
      },
    );
    return _mapper.pendingList(_listData(_responseMap(response)));
  }

  Future<List<ConsecutiveAbsenceStudent>> fetchConsecutiveAbsences({
    required RepositoryQuery query,
    int days = 3,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      AttendanceApiPaths.consecutiveAbsenceAlert,
      queryParameters: {
        ..._queryParams(query),
        'days': days,
      },
    );
    return _mapper.consecutiveAbsenceList(_listData(_responseMap(response)));
  }

  Future<List<ShortAttendanceStudent>> fetchShortAttendance({
    required RepositoryQuery query,
    int threshold = 75,
    int windowDays = 30,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      AttendanceApiPaths.shortAttendanceAlert,
      queryParameters: {
        ..._queryParams(query),
        'threshold': threshold,
        'windowDays': windowDays,
      },
    );
    return _mapper.shortAttendanceList(_listData(_responseMap(response)));
  }

  Map<String, dynamic> _queryParams(RepositoryQuery query) => {
        'tenantId': query.tenantId,
        'schoolId': query.schoolId,
      };

  String _formatDate(DateTime date) {
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  Map<String, dynamic> _responseMap(Response<Map<String, dynamic>> response) {
    return response.data ?? const {};
  }

  Map<String, dynamic> _requireData(Response<Map<String, dynamic>> response) {
    final envelope = ApiEnvelopeDto.fromJson(_responseMap(response));
    return envelope.data ?? const {};
  }

  List<dynamic> _listData(Map<String, dynamic> body) {
    final dataField = body['data'];
    if (dataField is List<dynamic>) return dataField;
    if (dataField is Map<String, dynamic>) {
      final items = dataField['items'];
      if (items is List<dynamic>) return items;
    }
    return const [];
  }
}
