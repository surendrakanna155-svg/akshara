import 'package:dio/dio.dart';

import '../../repository_query.dart';
import '../admissions/dto/api_envelope_dto.dart';

class Phase4RemoteDataSource {
  Phase4RemoteDataSource(this._dio);

  final Dio _dio;

  Map<String, dynamic> _data(Response<Map<String, dynamic>> response) =>
      ApiEnvelopeDto.fromJson(response.data ?? const {}).requireData();

  Map<String, dynamic> _params(RepositoryQuery query) => {
        if (query.page > 1) 'page': query.page,
        if (query.pageSize != 20) 'pageSize': query.pageSize,
      };

  Future<Map<String, dynamic>> fetchHomeworkIntelligencePlan({
    required RepositoryQuery query,
    required String className,
    required String subjectName,
    String examType = 'unit_test',
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/intelligence/homework-intelligence/plan',
      queryParameters: {
        ..._params(query),
        'className': className,
        'subjectName': subjectName,
        'examType': examType,
      },
    );
    return _data(response);
  }

  Future<Map<String, dynamic>> generateHomeworkIntelligence({
    required RepositoryQuery query,
    required Map<String, dynamic> body,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/intelligence/homework-intelligence/generate',
      queryParameters: _params(query),
      data: body,
    );
    return _data(response);
  }

  Future<Map<String, dynamic>> fetchStudent360Profile({
    required RepositoryQuery query,
    required String studentId,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/sis/students/$studentId/360',
      queryParameters: _params(query),
    );
    return _data(response);
  }

  Future<List<Map<String, dynamic>>> fetchStudentTimeline({
    required RepositoryQuery query,
    required String studentId,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/sis/students/$studentId/timeline',
      queryParameters: _params(query),
    );
    final data = _data(response);
    return (data['items'] as List<dynamic>? ?? const []).cast<Map<String, dynamic>>();
  }

  Future<Map<String, dynamic>> fetchEmployeeDashboard({required RepositoryQuery query}) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/employees/dashboard',
      queryParameters: _params(query),
    );
    return _data(response);
  }

  Future<List<Map<String, dynamic>>> fetchEmployees({
    required RepositoryQuery query,
    String? search,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/employees',
      queryParameters: {..._params(query), if (search != null) 'search': search},
    );
    final data = _data(response);
    return (data['items'] as List<dynamic>? ?? const []).cast<Map<String, dynamic>>();
  }

  Future<Map<String, dynamic>> fetchEmployee({
    required RepositoryQuery query,
    required String employeeId,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/employees/$employeeId',
      queryParameters: _params(query),
    );
    return _data(response);
  }

  Future<Map<String, dynamic>> assignEmployeeRole({
    required RepositoryQuery query,
    required String employeeId,
    required String roleCode,
    bool isPrimary = false,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/employees/$employeeId/roles',
      queryParameters: _params(query),
      data: {'roleCode': roleCode, 'isPrimary': isPrimary},
    );
    return _data(response);
  }

  Future<Map<String, dynamic>> fetchDistributionDashboard({required RepositoryQuery query}) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/inventory/distribution/dashboard',
      queryParameters: _params(query),
    );
    return _data(response);
  }

  Future<List<Map<String, dynamic>>> fetchDistributionCatalog({
    required RepositoryQuery query,
    String? category,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/inventory/distribution/catalog',
      queryParameters: {..._params(query), if (category != null) 'category': category},
    );
    final data = _data(response);
    return (data['items'] as List<dynamic>? ?? const []).cast<Map<String, dynamic>>();
  }

  Future<List<Map<String, dynamic>>> fetchDistributions({
    required RepositoryQuery query,
    String? studentId,
    String? status,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/inventory/distribution/items',
      queryParameters: {
        ..._params(query),
        if (studentId != null) 'studentId': studentId,
        if (status != null) 'status': status,
      },
    );
    final data = _data(response);
    return (data['items'] as List<dynamic>? ?? const []).cast<Map<String, dynamic>>();
  }

  Future<Map<String, dynamic>> createDistribution({
    required RepositoryQuery query,
    required String studentId,
    required String catalogItemId,
    int quantity = 1,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/inventory/distribution/items',
      queryParameters: _params(query),
      data: {'studentId': studentId, 'catalogItemId': catalogItemId, 'quantity': quantity},
    );
    return _data(response);
  }

  Future<Map<String, dynamic>> transitionDistribution({
    required RepositoryQuery query,
    required String distributionId,
    required String status,
    String? notes,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/inventory/distribution/items/$distributionId/status',
      queryParameters: _params(query),
      data: {'status': status, if (notes != null) 'notes': notes},
    );
    return _data(response);
  }

  Future<Map<String, dynamic>> requestReplacement({
    required RepositoryQuery query,
    required String distributionId,
    String? notes,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/inventory/distribution/items/$distributionId/replacement',
      queryParameters: _params(query),
      data: {if (notes != null) 'notes': notes},
    );
    return _data(response);
  }

  Future<Map<String, dynamic>> fetchDistributionReports({required RepositoryQuery query}) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/inventory/distribution/reports',
      queryParameters: _params(query),
    );
    return _data(response);
  }

  Future<List<Map<String, dynamic>>> fetchReplacementRequests({
    required RepositoryQuery query,
    String? status,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/inventory/distribution/replacements',
      queryParameters: {
        ..._params(query),
        if (status != null) 'status': status,
      },
    );
    final data = _data(response);
    return (data['items'] as List<dynamic>? ?? const []).cast<Map<String, dynamic>>();
  }

  Future<Map<String, dynamic>> approveReplacement({
    required RepositoryQuery query,
    required String requestId,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/inventory/distribution/replacements/$requestId/approve',
      queryParameters: _params(query),
    );
    return _data(response);
  }

  Future<Map<String, dynamic>> fulfillReplacement({
    required RepositoryQuery query,
    required String requestId,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/inventory/distribution/replacements/$requestId/fulfill',
      queryParameters: _params(query),
    );
    return _data(response);
  }

  Future<Map<String, dynamic>> rejectReplacement({
    required RepositoryQuery query,
    required String requestId,
    String? reason,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/inventory/distribution/replacements/$requestId/reject',
      queryParameters: _params(query),
      data: {if (reason != null) 'reason': reason},
    );
    return _data(response);
  }
}
