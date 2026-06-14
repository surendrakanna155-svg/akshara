import 'package:dio/dio.dart';

import '../../../repository_query.dart';
import '../../admissions/dto/api_envelope_dto.dart';
import '../academic_operations_api_paths.dart';
import '../dto/academic_operations_request_dto.dart';
import '../dto/academic_operations_response_dto.dart';

class AcademicOperationsRemoteDataSource {
  AcademicOperationsRemoteDataSource(this._dio);

  final Dio _dio;

  Future<List<ClassMappingRuleResponseDto>> suggestClassMappings({
    required RepositoryQuery query,
    required String sourceYearId,
    required String targetYearId,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      AcademicOperationsApiPaths.suggestMappings,
      queryParameters: _query(query)
        ..addAll({
          'sourceYearId': sourceYearId,
          'targetYearId': targetYearId,
        }),
    );
    final rows = _list(_requireData(response)['mappings']);
    return rows.map(ClassMappingRuleResponseDto.fromJson).toList(growable: false);
  }

  Future<AcademicTransitionJobResponseDto> previewYearTransition({
    required RepositoryQuery query,
    required String sourceYearId,
    required String targetYearId,
    required List<ClassMappingRuleDto> mappings,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      AcademicOperationsApiPaths.previewTransition,
      queryParameters: _query(query),
      data: YearTransitionPreviewRequestDto(
        sourceYearId: sourceYearId,
        targetYearId: targetYearId,
        mappings: mappings,
      ).toJson(),
    );
    return AcademicTransitionJobResponseDto.fromJson(_requireData(response));
  }

  Future<ExecutionReportResponseDto> executeYearTransition({
    required RepositoryQuery query,
    required String jobId,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      AcademicOperationsApiPaths.executeTransition(jobId),
      queryParameters: _query(query),
    );
    final data = _requireData(response);
    return ExecutionReportResponseDto.fromJson({
      'id': data['jobId'] ?? jobId,
      ...data,
    });
  }

  Future<AcademicTransitionJobResponseDto> getTransitionJob({
    required RepositoryQuery query,
    required String jobId,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      AcademicOperationsApiPaths.transitionJob(jobId),
      queryParameters: _query(query),
    );
    return AcademicTransitionJobResponseDto.fromJson(_requireData(response));
  }

  Future<AcademicOperationPlanResponseDto> previewStudentReshuffle({
    required RepositoryQuery query,
    required String classLabel,
    required String academicYear,
    required String strategy,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      AcademicOperationsApiPaths.previewReshuffle,
      queryParameters: _query(query),
      data: {
        'classLabel': classLabel,
        'academicYear': academicYear,
        'strategy': strategy,
      },
    );
    return AcademicOperationPlanResponseDto.fromJson(_requireData(response));
  }

  Future<ExecutionReportResponseDto> executeStudentReshuffle({
    required RepositoryQuery query,
    required String planId,
  }) =>
      _executePlan(
        query: query,
        path: AcademicOperationsApiPaths.executeReshuffle(planId),
        planId: planId,
      );

  Future<AcademicOperationPlanResponseDto> previewSectionBalance({
    required RepositoryQuery query,
    required String classLabel,
    required String academicYear,
    int? targetSize,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      AcademicOperationsApiPaths.previewSectionBalance,
      queryParameters: _query(query),
      data: {
        'classLabel': classLabel,
        'academicYear': academicYear,
        if (targetSize != null) 'targetSize': targetSize,
      },
    );
    return AcademicOperationPlanResponseDto.fromJson(_requireData(response));
  }

  Future<ExecutionReportResponseDto> executeSectionBalance({
    required RepositoryQuery query,
    required String planId,
  }) =>
      _executePlan(
        query: query,
        path: AcademicOperationsApiPaths.executeSectionBalance(planId),
        planId: planId,
      );

  Future<AcademicOperationPlanResponseDto> previewQuarterlyReshuffle({
    required RepositoryQuery query,
    required String classLabel,
    required String academicYear,
    required int quarter,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      AcademicOperationsApiPaths.previewQuarterlyReshuffle,
      queryParameters: _query(query),
      data: {
        'classLabel': classLabel,
        'academicYear': academicYear,
        'quarter': quarter,
      },
    );
    return AcademicOperationPlanResponseDto.fromJson(_requireData(response));
  }

  Future<ExecutionReportResponseDto> executeQuarterlyReshuffle({
    required RepositoryQuery query,
    required String planId,
  }) =>
      _executePlan(
        query: query,
        path: AcademicOperationsApiPaths.executeQuarterlyReshuffle(planId),
        planId: planId,
      );

  Future<AcademicOperationPlanResponseDto> previewPerformanceBalance({
    required RepositoryQuery query,
    required String classLabel,
    required String academicYear,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      AcademicOperationsApiPaths.previewPerformanceBalance,
      queryParameters: _query(query),
      data: {
        'classLabel': classLabel,
        'academicYear': academicYear,
      },
    );
    return AcademicOperationPlanResponseDto.fromJson(_requireData(response));
  }

  Future<ExecutionReportResponseDto> executePerformanceBalance({
    required RepositoryQuery query,
    required String planId,
  }) =>
      _executePlan(
        query: query,
        path: AcademicOperationsApiPaths.executePerformanceBalance(planId),
        planId: planId,
      );

  Future<ExecutionReportResponseDto> _executePlan({
    required RepositoryQuery query,
    required String path,
    required String planId,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      path,
      queryParameters: _query(query),
    );
    final data = _requireData(response);
    return ExecutionReportResponseDto.fromJson({
      'id': data['planId'] ?? planId,
      ...data,
    });
  }

  Map<String, dynamic> _query(RepositoryQuery query) {
    return {
      'tenantId': query.tenantId,
      if (query.schoolId != null) 'schoolId': query.schoolId,
      if (query.organizationId != null) 'organizationId': query.organizationId,
    };
  }

  Map<String, dynamic> _requireData(Response<Map<String, dynamic>> response) {
    final raw = response.data ?? const {};
    return ApiEnvelopeDto.fromJson(raw).requireData();
  }

  List<Map<String, dynamic>> _list(Object? value) {
    final list = value as List<dynamic>? ?? const [];
    return list
        .whereType<Map>()
        .map((row) => row.cast<String, dynamic>())
        .toList(growable: false);
  }
}
