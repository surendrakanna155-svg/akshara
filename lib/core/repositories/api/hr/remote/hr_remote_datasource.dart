// ignore_for_file: unused_field
import 'package:dio/dio.dart';

import '../dto/hr_dashboard_dto.dart';

/// Dio-backed remote data source for Hr (scaffolding only).
class HrRemoteDataSource {
  HrRemoteDataSource(this._dio);

  final Dio _dio;

  Future<HrDashboardDto> fetchDashboard() async {
    throw UnimplementedError('HrRemoteDataSource.fetchDashboard not connected');
    // ignore: dead_code
    // final response = await _dio.get('/hr/dashboard');
    // return HrDashboardDto.fromJson(response.data['data'] as Map<String, dynamic>);
  }
}
