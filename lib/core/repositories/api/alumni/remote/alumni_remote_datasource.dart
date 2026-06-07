// ignore_for_file: unused_field
import 'package:dio/dio.dart';

import '../dto/alumni_dashboard_dto.dart';

/// Dio-backed remote data source for Alumni (scaffolding only).
class AlumniRemoteDataSource {
  AlumniRemoteDataSource(this._dio);

  final Dio _dio;

  Future<AlumniDashboardDto> fetchDashboard() async {
    throw UnimplementedError('AlumniRemoteDataSource.fetchDashboard not connected');
    // ignore: dead_code
    // final response = await _dio.get('/alumni/dashboard');
    // return AlumniDashboardDto.fromJson(response.data['data'] as Map<String, dynamic>);
  }
}
