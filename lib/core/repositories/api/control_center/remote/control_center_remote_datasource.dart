// ignore_for_file: unused_field
import 'package:dio/dio.dart';

import '../dto/control_center_dashboard_dto.dart';

/// Dio-backed remote data source for ControlCenter (scaffolding only).
class ControlCenterRemoteDataSource {
  ControlCenterRemoteDataSource(this._dio);

  final Dio _dio;

  Future<ControlCenterDashboardDto> fetchDashboard() async {
    throw UnimplementedError('ControlCenterRemoteDataSource.fetchDashboard not connected');
    // ignore: dead_code
    // final response = await _dio.get('/control-center/dashboard');
    // return ControlCenterDashboardDto.fromJson(response.data['data'] as Map<String, dynamic>);
  }
}
