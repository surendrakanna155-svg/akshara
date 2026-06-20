import 'package:dio/dio.dart';

import '../../../../../features/academics/timetable/timetable_models.dart';
import '../../../repository_query.dart';
import '../dto/timetable_dto.dart';
import 'timetable_api_paths.dart';

class TimetableRemoteDataSource {
  TimetableRemoteDataSource(this._dio);

  final Dio _dio;

  Future<TimetableSummaryDto> fetchSummary({
    required RepositoryQuery query,
    required String academicYearId,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      TimetableApiPaths.summary,
      queryParameters: {..._queryParams(query), 'academicYearId': academicYearId},
    );
    return TimetableSummaryDto.fromJson(parseTimetableEnvelope(_responseMap(response)));
  }

  Future<List<TimetableEntryDto>> fetchTimetables({
    required RepositoryQuery query,
    String? academicYearId,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      TimetableApiPaths.timetables,
      queryParameters: {
        ..._queryParams(query),
        if (academicYearId != null) 'academicYearId': academicYearId,
      },
    );
    return parseTimetableItems(_responseMap(response))
        .map(TimetableEntryDto.fromJson)
        .toList();
  }

  Future<Map<String, dynamic>> fetchDetail({
    required RepositoryQuery query,
    required String timetableId,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      TimetableApiPaths.detail(timetableId),
      queryParameters: _queryParams(query),
    );
    return parseTimetableEnvelope(_responseMap(response));
  }

  Future<List<TeacherWorkloadDto>> fetchWorkload({
    required RepositoryQuery query,
    required String academicYearId,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      TimetableApiPaths.workload,
      queryParameters: {..._queryParams(query), 'academicYearId': academicYearId},
    );
    final data = parseTimetableEnvelope(_responseMap(response));
    final items = data['items'] as List<dynamic>? ?? const [];
    return items.map((item) => TeacherWorkloadDto.fromJson(item as Map<String, dynamic>)).toList();
  }

  Future<Map<String, dynamic>> fetchConflicts({
    required RepositoryQuery query,
    required String academicYearId,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      TimetableApiPaths.conflicts,
      queryParameters: {..._queryParams(query), 'academicYearId': academicYearId},
    );
    return parseTimetableEnvelope(_responseMap(response));
  }

  Future<List<TimetableEntryDto>> generate({
    required RepositoryQuery query,
    required Map<String, dynamic> body,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      TimetableApiPaths.generate,
      queryParameters: _queryParams(query),
      data: body,
    );
    return parseTimetableItems(_responseMap(response))
        .map(TimetableEntryDto.fromJson)
        .toList();
  }

  Future<TimetableValidationResultDto> validate({
    required RepositoryQuery query,
    required String timetableId,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      TimetableApiPaths.validate,
      queryParameters: _queryParams(query),
      data: {'timetableId': timetableId},
    );
    return TimetableValidationResultDto.fromJson(parseTimetableEnvelope(_responseMap(response)));
  }

  Future<TimetableEntryDto> publish({
    required RepositoryQuery query,
    required String timetableId,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      TimetableApiPaths.publish(timetableId),
      queryParameters: _queryParams(query),
    );
    final data = parseTimetableEnvelope(_responseMap(response));
    return TimetableEntryDto.fromJson(data['timetable'] as Map<String, dynamic>? ?? const {});
  }

  Future<TimetablePeriodDto> movePeriod({
    required RepositoryQuery query,
    required MoveTimetablePeriodRequest request,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      TimetableApiPaths.movePeriod,
      queryParameters: _queryParams(query),
      data: {
        'periodId': request.periodId,
        'targetDayOfWeek': request.targetDayOfWeek,
        'targetPeriodNumber': request.targetPeriodNumber,
        if (request.roomLabel != null) 'roomLabel': request.roomLabel,
      },
    );
    return TimetablePeriodDto.fromJson(parseTimetableEnvelope(_responseMap(response)));
  }

  Future<TimetablePeriodDto> reassignPeriodTeacher({
    required RepositoryQuery query,
    required ReassignPeriodTeacherRequest request,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      TimetableApiPaths.reassignPeriodTeacher,
      queryParameters: _queryParams(query),
      data: {
        'periodId': request.periodId,
        'teacherId': request.teacherId,
      },
    );
    return TimetablePeriodDto.fromJson(parseTimetableEnvelope(_responseMap(response)));
  }

  Map<String, dynamic> _responseMap(Response<Map<String, dynamic>> response) {
    return response.data ?? const {};
  }

  Map<String, dynamic> _queryParams(RepositoryQuery query) {
    return {
      if (query.page > 1) 'page': query.page,
      if (query.pageSize != 20) 'pageSize': query.pageSize,
    };
  }
}
