import 'package:dio/dio.dart';

import '../../../repository_query.dart';
import '../../admissions/dto/api_envelope_dto.dart';
import '../dto/workflow_request_dto.dart';
import '../workflow_api_paths.dart';

class WorkflowRemoteDataSource {
  WorkflowRemoteDataSource(this._dio);

  final Dio _dio;

  Future<List<Map<String, dynamic>>> listDefinitions({
    required RepositoryQuery query,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      WorkflowApiPaths.definitions,
      queryParameters: _query(query),
    );
    return _list(_data(response)['definitions']);
  }

  Future<Map<String, dynamic>> upsertDefinition({
    required RepositoryQuery query,
    required Map<String, Object?> definition,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      WorkflowApiPaths.definitions,
      queryParameters: _query(query),
      data: definition,
    );
    return _data(response);
  }

  Future<void> deleteDefinition({
    required RepositoryQuery query,
    required String definitionId,
  }) async {
    await _dio.delete<Map<String, dynamic>>(
      WorkflowApiPaths.definition(definitionId),
      queryParameters: _query(query),
    );
  }

  Future<List<Map<String, dynamic>>> listInstances({
    required RepositoryQuery query,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      WorkflowApiPaths.instances,
      queryParameters: _query(query),
    );
    return _list(_data(response)['instances']);
  }

  Future<Map<String, dynamic>?> triggerWorkflow({
    required RepositoryQuery query,
    required WorkflowTriggerRequestDto request,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      WorkflowApiPaths.triggers,
      queryParameters: _query(query),
      data: request.toJson(),
    );
    final instance = _data(response)['instance'];
    if (instance is Map<String, dynamic>) return instance;
    return null;
  }

  Future<Map<String, dynamic>> executeAction({
    required RepositoryQuery query,
    required String instanceId,
    required WorkflowActionRequestDto request,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      WorkflowApiPaths.instanceAction(instanceId),
      queryParameters: _query(query),
      data: request.toJson(),
    );
    return _data(response);
  }

  Future<List<Map<String, dynamic>>> listScheduledJobs({
    required RepositoryQuery query,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      WorkflowApiPaths.scheduledJobs,
      queryParameters: _query(query),
    );
    return _list(_data(response)['jobs']);
  }

  Future<Map<String, dynamic>> scheduleJob({
    required RepositoryQuery query,
    required Map<String, Object?> job,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      WorkflowApiPaths.scheduledJobs,
      queryParameters: _query(query),
      data: job,
    );
    return _data(response);
  }

  Future<List<Map<String, dynamic>>> runScheduledJobs({
    required RepositoryQuery query,
    required DateTime now,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      WorkflowApiPaths.runScheduled,
      queryParameters: _query(query),
      data: <String, Object?>{'runAt': now.toIso8601String()},
    );
    return _list(_data(response)['instances']);
  }

  Map<String, dynamic> _data(Response<Map<String, dynamic>> response) {
    final raw = response.data ?? const <String, dynamic>{};
    return ApiEnvelopeDto.fromJson(raw).requireData();
  }

  List<Map<String, dynamic>> _list(Object? value) {
    final rows = value as List<dynamic>? ?? const <dynamic>[];
    return rows.whereType<Map>().map((row) => row.cast<String, dynamic>()).toList(growable: false);
  }

  Map<String, Object?> _query(RepositoryQuery query) {
    return <String, Object?>{
      'tenantId': query.tenantId,
      if (query.schoolId != null) 'schoolId': query.schoolId,
      if (query.organizationId != null) 'organizationId': query.organizationId,
    };
  }
}
