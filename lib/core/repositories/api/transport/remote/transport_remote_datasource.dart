// ignore_for_file: unused_field
import 'package:dio/dio.dart';

import '../dto/transport_dashboard_dto.dart';

/// Dio-backed remote data source for Transport (scaffolding only).
class TransportRemoteDataSource {
  TransportRemoteDataSource(this._dio);

  final Dio _dio;

  Future<TransportDashboardDto> fetchDashboard() async {
    throw UnimplementedError('TransportRemoteDataSource.fetchDashboard not connected');
    // ignore: dead_code
    // final response = await _dio.get('/transport/dashboard');
    // return TransportDashboardDto.fromJson(response.data['data'] as Map<String, dynamic>);
  }
}
