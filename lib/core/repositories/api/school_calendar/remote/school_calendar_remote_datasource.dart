import 'package:dio/dio.dart';

import '../../../../../features/management/school_calendar/school_calendar_models.dart';
import '../../../repository_query.dart';
import '../../admissions/dto/api_envelope_dto.dart';
import '../mapper/school_calendar_mapper.dart';
import '../school_calendar_api_paths.dart';

/// Talks to the `/school-calendar` edge routes via the shared [Dio] client.
class SchoolCalendarRemoteDataSource {
  SchoolCalendarRemoteDataSource(
    this._dio, {
    SchoolCalendarMapper mapper = const SchoolCalendarMapper(),
  }) : _mapper = mapper;

  final Dio _dio;
  final SchoolCalendarMapper _mapper;

  Future<List<SchoolCalendarEvent>> fetchEvents({
    required RepositoryQuery query,
    DateTime? from,
    DateTime? to,
    SchoolCalendarEventType? eventType,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      SchoolCalendarApiPaths.base,
      queryParameters: {
        ..._queryParams(query),
        if (from != null) 'from': SchoolCalendarMapper.formatDate(from),
        if (to != null) 'to': SchoolCalendarMapper.formatDate(to),
        if (eventType != null) 'eventType': eventType.apiValue,
      },
    );
    final envelope = ApiEnvelopeDto.fromJson(_responseMap(response));
    return _mapper.toDomainList(envelope.requireListItems());
  }

  Future<SchoolCalendarEvent> createEvent({
    required RepositoryQuery query,
    required CreateSchoolCalendarEventInput input,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      SchoolCalendarApiPaths.base,
      queryParameters: _queryParams(query),
      data: _mapper.createBody(input),
    );
    final envelope = ApiEnvelopeDto.fromJson(_responseMap(response));
    return _mapper.toDomain(envelope.requireData());
  }

  Future<void> deleteEvent({
    required RepositoryQuery query,
    required String id,
  }) async {
    await _dio.delete<Map<String, dynamic>>(
      SchoolCalendarApiPaths.event(id),
      queryParameters: _queryParams(query),
    );
  }

  Map<String, dynamic> _queryParams(RepositoryQuery query) => {
        'tenantId': query.tenantId,
        if (query.schoolId != null) 'schoolId': query.schoolId,
      };

  Map<String, dynamic> _responseMap(Response<Map<String, dynamic>> response) =>
      response.data ?? const {};
}
