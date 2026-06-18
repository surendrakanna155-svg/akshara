import 'package:dio/dio.dart';

import '../../../repository_query.dart';
import '../../admissions/dto/api_envelope_dto.dart';
import '../dto/approval_audit_entry_dto.dart';
import '../dto/approval_request_dto.dart';
import '../dto/approval_request_payload_dto.dart';
import 'approval_api_paths.dart';

/// Dio-backed remote data source for unified Approval API (F2).
class ApprovalRemoteDataSource {
  ApprovalRemoteDataSource(this._dio);

  final Dio _dio;

  Future<List<ApprovalRequestDto>> fetchPending({
    required RepositoryQuery query,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      ApprovalApiPaths.pending,
      queryParameters: _queryParams(query),
    );
    return _items(_requireData(response));
  }

  Future<List<ApprovalRequestDto>> fetchByFilter({
    required RepositoryQuery query,
    required ApprovalListFilterQuery filter,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      ApprovalApiPaths.base,
      queryParameters: {
        ..._queryParams(query),
        ...filter.toQueryParams(),
      },
    );
    return _items(_requireData(response));
  }

  Future<ApprovalRequestDto?> fetchById({
    required RepositoryQuery query,
    required String approvalId,
  }) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        ApprovalApiPaths.detail(approvalId),
        queryParameters: _queryParams(query),
      );
      final data = ApiEnvelopeDto.fromJson(_responseMap(response)).data;
      if (data == null) return null;
      return ApprovalRequestDto.fromJson(data);
    } on DioException catch (error) {
      if (error.response?.statusCode == 404) return null;
      rethrow;
    }
  }

  Future<ApprovalRequestDto?> fetchPendingByEntity({
    required RepositoryQuery query,
    required ApprovalListFilterQuery filter,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      ApprovalApiPaths.entity,
      queryParameters: {
        ..._queryParams(query),
        ...filter.toQueryParams(),
      },
    );
    final envelope = ApiEnvelopeDto.fromJson(_responseMap(response));
    final data = envelope.data;
    if (data == null || data['id'] == null) return null;
    return ApprovalRequestDto.fromJson(data);
  }

  Future<ApprovalRequestDto> submit({
    required RepositoryQuery query,
    required SubmitApprovalRequestDto request,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      ApprovalApiPaths.base,
      queryParameters: _queryParams(query),
      data: request.toJson(),
    );
    return ApprovalRequestDto.fromJson(_requireData(response));
  }

  Future<ApprovalRequestDto> approve({
    required RepositoryQuery query,
    required String approvalId,
    required DecideApprovalRequestDto request,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      ApprovalApiPaths.approve(approvalId),
      queryParameters: _queryParams(query),
      data: request.toJson(),
    );
    return ApprovalRequestDto.fromJson(_requireData(response));
  }

  Future<ApprovalRequestDto> reject({
    required RepositoryQuery query,
    required String approvalId,
    required DecideApprovalRequestDto request,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      ApprovalApiPaths.reject(approvalId),
      queryParameters: _queryParams(query),
      data: request.toJson(),
    );
    return ApprovalRequestDto.fromJson(_requireData(response));
  }

  Future<ApprovalRequestDto> cancel({
    required RepositoryQuery query,
    required String approvalId,
    required DecideApprovalRequestDto request,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      ApprovalApiPaths.cancel(approvalId),
      queryParameters: _queryParams(query),
      data: request.toJson(),
    );
    return ApprovalRequestDto.fromJson(_requireData(response));
  }

  Future<List<ApprovalAuditEntryDto>> fetchAuditEntries({
    required RepositoryQuery query,
    String? approvalRequestId,
  }) async {
    if (approvalRequestId != null) {
      final response = await _dio.get<Map<String, dynamic>>(
        ApprovalApiPaths.auditTrail(approvalRequestId),
        queryParameters: _queryParams(query),
      );
      return ApprovalAuditResponseDto.fromJson(_requireData(response)).items;
    }

    final response = await _dio.get<Map<String, dynamic>>(
      ApprovalApiPaths.audit,
      queryParameters: _queryParams(query),
    );
    return ApprovalAuditResponseDto.fromJson(_requireData(response)).items;
  }

  Future<ApprovalAuditEntryDto> recordAuditEntry({
    required RepositoryQuery query,
    required Map<String, dynamic> body,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      ApprovalApiPaths.audit,
      queryParameters: _queryParams(query),
      data: body,
    );
    return ApprovalAuditEntryDto.fromJson(_requireData(response));
  }

  List<ApprovalRequestDto> _items(Map<String, dynamic> data) {
    return ApprovalRequestsResponseDto.fromJson(data).items;
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

  Map<String, dynamic> _requireData(Response<Map<String, dynamic>> response) {
    final envelope = ApiEnvelopeDto.fromJson(_responseMap(response));
    if (envelope.error != null) {
      throw DioException(
        requestOptions: response.requestOptions,
        response: response,
        type: DioExceptionType.badResponse,
        message: envelope.error!.message,
      );
    }
    return envelope.data ?? const {};
  }
}
