// ignore_for_file: unused_field
import 'package:dio/dio.dart';

import '../dto/library_dashboard_dto.dart';

/// Dio-backed remote data source for Library (scaffolding only).
class LibraryRemoteDataSource {
  LibraryRemoteDataSource(this._dio);

  final Dio _dio;

  Future<LibraryDashboardDto> fetchDashboard() async {
    throw UnimplementedError('LibraryRemoteDataSource.fetchDashboard not connected');
    // ignore: dead_code
    // final response = await _dio.get('/library/dashboard');
    // return LibraryDashboardDto.fromJson(response.data['data'] as Map<String, dynamic>);
  }
}
