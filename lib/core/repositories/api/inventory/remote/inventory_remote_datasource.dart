// ignore_for_file: unused_field
import 'package:dio/dio.dart';

import '../dto/inventory_dashboard_dto.dart';

/// Dio-backed remote data source for Inventory (scaffolding only).
class InventoryRemoteDataSource {
  InventoryRemoteDataSource(this._dio);

  final Dio _dio;

  Future<InventoryDashboardDto> fetchDashboard() async {
    throw UnimplementedError('InventoryRemoteDataSource.fetchDashboard not connected');
    // ignore: dead_code
    // final response = await _dio.get('/inventory/dashboard');
    // return InventoryDashboardDto.fromJson(response.data['data'] as Map<String, dynamic>);
  }
}
