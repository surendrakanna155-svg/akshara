import 'package:dio/dio.dart';

import '../../../repository_query.dart';
import '../../admissions/dto/api_envelope_dto.dart';
import '../dto/inventory_responses_dto.dart';
import 'inventory_api_paths.dart';

/// Dio-backed remote data source for Inventory.
class InventoryRemoteDataSource {
  InventoryRemoteDataSource(this._dio);

  final Dio _dio;

  Future<InventoryDashboardDto> fetchDashboard({
    required RepositoryQuery query,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      InventoryApiPaths.dashboard,
      queryParameters: _queryParams(query),
    );
    return InventoryDashboardDto.fromJson(_responseMap(response));
  }

  Future<InventoryAssetsResponseDto> fetchAssets({
    required RepositoryQuery query,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      InventoryApiPaths.assets,
      queryParameters: _queryParams(query),
    );
    return InventoryAssetsResponseDto.fromJson(_responseMap(response));
  }

  Future<InventoryCategoriesResponseDto> fetchCategories({
    required RepositoryQuery query,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      InventoryApiPaths.categories,
      queryParameters: _queryParams(query),
    );
    return InventoryCategoriesResponseDto.fromJson(_responseMap(response));
  }

  Future<InventoryAllocationsResponseDto> fetchAllocations({
    required RepositoryQuery query,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      InventoryApiPaths.allocations,
      queryParameters: _queryParams(query),
    );
    return InventoryAllocationsResponseDto.fromJson(_responseMap(response));
  }

  Future<InventoryMaintenanceResponseDto> fetchMaintenanceRecords({
    required RepositoryQuery query,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      InventoryApiPaths.maintenance,
      queryParameters: _queryParams(query),
    );
    return InventoryMaintenanceResponseDto.fromJson(_responseMap(response));
  }

  Future<InventoryProcurementResponseDto> fetchProcurementOrders({
    required RepositoryQuery query,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      InventoryApiPaths.procurement,
      queryParameters: _queryParams(query),
    );
    return InventoryProcurementResponseDto.fromJson(_responseMap(response));
  }

  Future<InventoryVendorsResponseDto> fetchVendors({
    required RepositoryQuery query,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      InventoryApiPaths.vendors,
      queryParameters: _queryParams(query),
    );
    return InventoryVendorsResponseDto.fromJson(_responseMap(response));
  }

  Future<InventoryReportsResponseDto> fetchReports({
    required RepositoryQuery query,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      InventoryApiPaths.reports,
      queryParameters: _queryParams(query),
    );
    return InventoryReportsResponseDto.fromJson(_responseMap(response));
  }

  Future<Map<String, dynamic>> fetchInventoryCopilot({required RepositoryQuery query}) async {
    final response = await _dio.get<Map<String, dynamic>>(
      InventoryApiPaths.intelligenceCopilot,
      queryParameters: _queryParams(query),
    );
    return _requireData(response);
  }

  Future<Map<String, dynamic>> fetchAssetLifecycle({required RepositoryQuery query}) async {
    final response = await _dio.get<Map<String, dynamic>>(
      InventoryApiPaths.intelligenceLifecycle,
      queryParameters: _queryParams(query),
    );
    return _requireData(response);
  }

  Future<Map<String, dynamic>> fetchProcurementWorkflow({required RepositoryQuery query}) async {
    final response = await _dio.get<Map<String, dynamic>>(
      InventoryApiPaths.intelligenceProcurementWorkflow,
      queryParameters: _queryParams(query),
    );
    return _requireData(response);
  }

  Future<Map<String, dynamic>> recordAssetLifecycleEvent({
    required RepositoryQuery query,
    required Map<String, dynamic> body,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      InventoryApiPaths.intelligenceLifecycleEvents,
      queryParameters: _queryParams(query),
      data: body,
    );
    return _requireData(response);
  }

  Map<String, dynamic> _requireData(Response<Map<String, dynamic>> response) {
    return ApiEnvelopeDto.fromJson(_responseMap(response)).requireData();
  }

  Map<String, dynamic> _queryParams(RepositoryQuery query) {
    return {
      'tenantId': query.tenantId,
      if (query.schoolId != null) 'schoolId': query.schoolId,
      if (query.organizationId != null) 'organizationId': query.organizationId,
    };
  }

  Map<String, dynamic> _responseMap(Response<Map<String, dynamic>> response) {
    return response.data ?? const {};
  }
}
