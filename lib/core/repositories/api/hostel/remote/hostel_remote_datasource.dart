// ignore_for_file: unused_field
import 'package:dio/dio.dart';

import '../dto/hostel_dashboard_dto.dart';

/// Dio-backed remote data source for Hostel (scaffolding only).
class HostelRemoteDataSource {
  HostelRemoteDataSource(this._dio);

  final Dio _dio;

  Future<HostelDashboardDto> fetchDashboard() async {
    throw UnimplementedError('HostelRemoteDataSource.fetchDashboard not connected');
    // ignore: dead_code
    // final response = await _dio.get('/hostel/dashboard');
    // return HostelDashboardDto.fromJson(response.data['data'] as Map<String, dynamic>);
  }
}
