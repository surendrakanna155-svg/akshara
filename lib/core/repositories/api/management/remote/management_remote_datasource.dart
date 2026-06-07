// ignore_for_file: unused_field
import 'package:dio/dio.dart';

import '../dto/management_dashboard_dto.dart';

/// Dio-backed remote data source for Management (scaffolding only).
class ManagementRemoteDataSource {
  ManagementRemoteDataSource(this._dio);

  final Dio _dio;

  Future<ManagementDashboardDto> fetchDashboard() async {
    throw UnimplementedError('ManagementRemoteDataSource.fetchDashboard not connected');
    // ignore: dead_code
    // final response = await _dio.get('/management/dashboard');
    // return ManagementDashboardDto.fromJson(response.data['data'] as Map<String, dynamic>);
  }
}
