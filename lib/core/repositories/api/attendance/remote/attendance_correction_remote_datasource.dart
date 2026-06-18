import 'package:dio/dio.dart';

import '../../../repository_query.dart';
import '../../admissions/dto/api_envelope_dto.dart';
import '../../../../attendance/attendance_correction_models.dart';
import '../mapper/attendance_correction_mapper.dart';
import 'attendance_api_paths.dart';

class AttendanceCorrectionRemoteDataSource {
  AttendanceCorrectionRemoteDataSource(
    this._dio, {
    AttendanceCorrectionMapper mapper = const AttendanceCorrectionMapper(),
  }) : _mapper = mapper;

  final Dio _dio;
  final AttendanceCorrectionMapper _mapper;

  Future<List<AttendanceCorrectionRequest>> fetchCorrections({
    required RepositoryQuery query,
    AttendanceCorrectionStatus? status,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      AttendanceApiPaths.corrections,
      queryParameters: {
        ..._queryParams(query),
        if (status != null) 'status': _mapper.statusToApi(status),
      },
    );
    return _mapper.toDomainList(_listData(_responseMap(response)));
  }

  Future<AttendanceCorrectionRequest?> fetchCorrection({
    required RepositoryQuery query,
    required String correctionId,
  }) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        AttendanceApiPaths.correction(correctionId),
        queryParameters: _queryParams(query),
      );
      final data = ApiEnvelopeDto.fromJson(_responseMap(response)).data;
      if (data == null) return null;
      return _mapper.toDomain(data);
    } on DioException catch (error) {
      if (error.response?.statusCode == 404) return null;
      rethrow;
    }
  }

  Future<AttendanceCorrectionRequest> createCorrection({
    required RepositoryQuery query,
    required CreateAttendanceCorrectionRequest request,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      AttendanceApiPaths.corrections,
      queryParameters: _queryParams(query),
      data: _mapper.createBody(request),
    );
    return _mapper.toDomain(_requireData(response));
  }

  Future<AttendanceCorrectionRequest> updateStatus({
    required RepositoryQuery query,
    required String correctionId,
    required AttendanceCorrectionStatus status,
  }) async {
    final response = await _dio.patch<Map<String, dynamic>>(
      AttendanceApiPaths.correctionStatus(correctionId),
      queryParameters: _queryParams(query),
      data: {'status': _mapper.statusToApi(status)},
    );
    return _mapper.toDomain(_requireData(response));
  }

  Map<String, dynamic> _queryParams(RepositoryQuery query) => {
        'tenantId': query.tenantId,
        'schoolId': query.schoolId,
      };

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
      if (dataField.containsKey('id')) return [dataField];
    }
    return const [];
  }
}
