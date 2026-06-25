import 'package:dio/dio.dart';

import '../../repository_query.dart';
import '../admissions/dto/api_envelope_dto.dart';

class Phase5RemoteDataSource {
  Phase5RemoteDataSource(this._dio);

  final Dio _dio;

  Map<String, dynamic> _data(Response<Map<String, dynamic>> response) =>
      ApiEnvelopeDto.fromJson(response.data ?? const {}).requireData();

  Map<String, dynamic> _params(RepositoryQuery query) => {
        if (query.page > 1) 'page': query.page,
        if (query.pageSize != 20) 'pageSize': query.pageSize,
      };

  Future<Map<String, dynamic>> fetchParentExperienceHub({
    required RepositoryQuery query,
    required String studentId,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/parent/experience/hub',
      queryParameters: {..._params(query), 'studentId': studentId},
    );
    return _data(response);
  }

  Future<void> acknowledgeParentItem({
    required RepositoryQuery query,
    required Map<String, dynamic> body,
  }) async {
    await _dio.post<Map<String, dynamic>>(
      '/parent/experience/acknowledge',
      queryParameters: _params(query),
      data: body,
    );
  }

  Future<Map<String, dynamic>> fetchEmployee360({
    required RepositoryQuery query,
    required String employeeId,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/employees/$employeeId/360',
      queryParameters: _params(query),
    );
    return _data(response);
  }

  Future<Map<String, dynamic>> fetchEmployeeIntelligenceDashboard({
    required RepositoryQuery query,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/employees/intelligence/dashboard',
      queryParameters: _params(query),
    );
    return _data(response);
  }

  Future<Map<String, dynamic>> fetchOperationsHub(
      {required RepositoryQuery query}) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/operations/hub',
      queryParameters: _params(query),
    );
    return _data(response);
  }

  Future<void> dismissOperationsAlert({
    required RepositoryQuery query,
    required String alertId,
  }) async {
    await _dio.post<Map<String, dynamic>>(
      '/operations/hub/alerts/$alertId/dismiss',
      queryParameters: _params(query),
    );
  }

  Future<void> completeOperationsAction({
    required RepositoryQuery query,
    required String actionId,
  }) async {
    await _dio.post<Map<String, dynamic>>(
      '/operations/hub/actions/$actionId/complete',
      queryParameters: _params(query),
    );
  }

  Future<Map<String, dynamic>> fetchDistributionReports(
      {required RepositoryQuery query}) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/inventory/distribution/reports',
      queryParameters: _params(query),
    );
    return _data(response);
  }

  Future<List<Map<String, dynamic>>> fetchMemoryEvents({
    required RepositoryQuery query,
    String? category,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/memories/events',
      queryParameters: {
        ..._params(query),
        if (category != null) 'category': category
      },
    );
    final data = _data(response);
    return (data['items'] as List<dynamic>? ?? const [])
        .cast<Map<String, dynamic>>();
  }

  Future<Map<String, dynamic>> fetchMemoryEvent({
    required RepositoryQuery query,
    required String eventId,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/memories/events/$eventId',
      queryParameters: _params(query),
    );
    return _data(response);
  }

  Future<Map<String, dynamic>> createMemoryEvent({
    required RepositoryQuery query,
    required Map<String, dynamic> body,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/memories/events',
      queryParameters: _params(query),
      data: body,
    );
    return _data(response);
  }

  Future<Map<String, dynamic>> publishMemoryEvent({
    required RepositoryQuery query,
    required String eventId,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/memories/events/$eventId/publish',
      queryParameters: _params(query),
    );
    return _data(response);
  }

  Future<Map<String, dynamic>> presignMemoryUpload({
    required RepositoryQuery query,
    required String eventId,
    required Map<String, dynamic> body,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/memories/events/$eventId/upload/presign',
      queryParameters: _params(query),
      data: body,
    );
    return _data(response);
  }

  Future<Map<String, dynamic>> confirmMemoryUpload({
    required RepositoryQuery query,
    required String eventId,
    required Map<String, dynamic> body,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/memories/events/$eventId/upload/confirm',
      queryParameters: _params(query),
      data: body,
    );
    return _data(response);
  }

  Future<Map<String, dynamic>> fetchMemoryDownloadUrl({
    required RepositoryQuery query,
    required String mediaId,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/memories/media/$mediaId/download',
      queryParameters: _params(query),
    );
    return _data(response);
  }

  Future<Map<String, dynamic>> fetchMemoryShareLink({
    required RepositoryQuery query,
    required String shareToken,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/memories/share/$shareToken',
      queryParameters: _params(query),
    );
    return _data(response);
  }

  /// PUT file bytes to Supabase signed upload URL (separate host from API).
  Future<void> putSignedUpload({
    required String signedUrl,
    required List<int> bytes,
    required String contentType,
  }) async {
    final uploadClient = Dio(
      BaseOptions(
        headers: {'Content-Type': contentType},
        validateStatus: (status) => status != null && status < 500,
      ),
    );
    final response = await uploadClient.put<List<int>>(
      signedUrl,
      data: bytes,
      options: Options(responseType: ResponseType.bytes),
    );
    if (response.statusCode == null || response.statusCode! >= 400) {
      throw DioException(
        requestOptions: response.requestOptions,
        response: response,
        message: 'Upload failed (${response.statusCode})',
      );
    }
  }

  Future<List<Map<String, dynamic>>> fetchPromotions({
    required RepositoryQuery query,
    String? status,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/promotions',
      queryParameters: {
        ..._params(query),
        if (status != null) 'status': status
      },
    );
    final data = _data(response);
    return (data['items'] as List<dynamic>? ?? const [])
        .cast<Map<String, dynamic>>();
  }

  Future<Map<String, dynamic>> createPromotion({
    required RepositoryQuery query,
    required Map<String, dynamic> body,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/promotions',
      queryParameters: _params(query),
      data: body,
    );
    return _data(response);
  }

  Future<Map<String, dynamic>> generatePromotionAssets({
    required RepositoryQuery query,
    required String promotionId,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/promotions/$promotionId/generate',
      queryParameters: _params(query),
    );
    return _data(response);
  }

  Future<Map<String, dynamic>> approvePromotion({
    required RepositoryQuery query,
    required String promotionId,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/promotions/$promotionId/approve',
      queryParameters: _params(query),
    );
    return _data(response);
  }

  Future<Map<String, dynamic>> publishPromotion({
    required RepositoryQuery query,
    required String promotionId,
    List<String> destinations = const [],
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/promotions/$promotionId/publish',
      queryParameters: _params(query),
      data: {'destinations': destinations},
    );
    return _data(response);
  }

  Future<void> trackPromotionMetric({
    required RepositoryQuery query,
    required String promotionId,
    required String metric,
  }) async {
    await _dio.post<Map<String, dynamic>>(
      '/promotions/$promotionId/track',
      queryParameters: _params(query),
      data: {'metric': metric},
    );
  }
}
