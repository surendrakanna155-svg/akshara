import 'package:dio/dio.dart';

import '../../../repository_query.dart';
import '../../admissions/dto/api_envelope_dto.dart';
import '../dto/communication_dto.dart';
import 'communication_api_paths.dart';

class CommunicationRemoteDataSource {
  CommunicationRemoteDataSource(this._dio);

  final Dio _dio;

  Future<CommunicationNotificationsResponseDto> fetchNotifications({
    required RepositoryQuery query,
    required String path,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      path,
      queryParameters: _queryParams(query),
    );
    return CommunicationNotificationsResponseDto.fromJson(_requireData(response));
  }

  Future<CommunicationTemplatesResponseDto> fetchTemplates({
    required RepositoryQuery query,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      CommunicationApiPaths.templates,
      queryParameters: _queryParams(query),
    );
    return CommunicationTemplatesResponseDto.fromJson(_requireData(response));
  }

  Future<BroadcastResponseDto> sendBroadcast({
    required RepositoryQuery query,
    required BroadcastRequestDto request,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      CommunicationApiPaths.broadcasts,
      queryParameters: _queryParams(query),
      data: request.toJson(),
    );
    return BroadcastResponseDto.fromJson(_requireData(response));
  }

  Future<void> markNotificationRead({
    required RepositoryQuery query,
    required String notificationId,
    required String path,
  }) async {
    await _dio.post<Map<String, dynamic>>(
      path,
      queryParameters: _queryParams(query),
      data: {'notification_id': notificationId},
    );
  }

  Future<void> markAllNotificationsRead({
    required RepositoryQuery query,
    required String path,
  }) async {
    await _dio.post<Map<String, dynamic>>(
      path,
      queryParameters: _queryParams(query),
    );
  }

  Future<void> registerDeviceToken({
    required RepositoryQuery query,
    required String platform,
    required String token,
    required String path,
  }) async {
    await _dio.post<Map<String, dynamic>>(
      path,
      queryParameters: _queryParams(query),
      data: {'platform': platform, 'token': token},
    );
  }

  Future<void> unregisterDeviceToken({
    required RepositoryQuery query,
    required String token,
    required String path,
  }) async {
    await _dio.post<Map<String, dynamic>>(
      path,
      queryParameters: _queryParams(query),
      data: {'token': token},
    );
  }

  Map<String, dynamic> _queryParams(RepositoryQuery query) {
    return {
      'tenant_id': query.tenantId,
      if (query.schoolId != null) 'school_id': query.schoolId,
      if (query.organizationId != null) 'organization_id': query.organizationId,
      ...query.paginationQueryParams(),
    };
  }

  Map<String, dynamic> _responseMap(Response<Map<String, dynamic>> response) {
    final body = response.data;
    if (body == null) {
      throw StateError('Empty communication API response');
    }
    return body;
  }

  Map<String, dynamic> _requireData(Response<Map<String, dynamic>> response) {
    return ApiEnvelopeDto.fromJson(_responseMap(response)).requireData();
  }
}
