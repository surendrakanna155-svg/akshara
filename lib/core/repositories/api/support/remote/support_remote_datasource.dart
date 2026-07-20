import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../../../repository_query.dart';
import '../../admissions/dto/api_envelope_dto.dart';
import '../dto/support_dtos.dart';
import 'support_api_paths.dart';

/// Dio-backed remote data source for the `/support` module.
///
/// The binary upload (presign → PUT → confirm) is genuinely net-new for the
/// client — today every "attachment" is a metadata-only reference. The raw PUT
/// to the presigned Storage URL uses a **bare** Dio (no auth/tenant/idempotency
/// interceptors) because the signed URL is an absolute, self-authorizing Storage
/// endpoint that must receive only the bytes + content-type.
class SupportRemoteDataSource {
  SupportRemoteDataSource(this._dio, {Dio? uploadDio})
      : _uploadDio = uploadDio ?? Dio();

  final Dio _dio;
  final Dio _uploadDio;

  Future<SupportIncidentDto> createIncident({
    required RepositoryQuery query,
    required Map<String, dynamic> body,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      SupportApiPaths.incidents,
      queryParameters: _queryParams(query),
      data: body,
    );
    return SupportIncidentDto.fromJson(_writeData(response));
  }

  Future<SupportIncidentListDto> listIncidents({
    required RepositoryQuery query,
    String? status,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      SupportApiPaths.incidents,
      queryParameters: {
        ..._queryParams(query),
        'page': query.page,
        'pageSize': query.pageSize,
        if (status != null) 'status': status,
      },
    );
    return SupportIncidentListDto.fromJson(_writeData(response));
  }

  Future<SupportIncidentDetailDto> getIncident({
    required RepositoryQuery query,
    required String incidentId,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      SupportApiPaths.incident(incidentId),
      queryParameters: _queryParams(query),
    );
    return SupportIncidentDetailDto.fromJson(_writeData(response));
  }

  Future<SupportMessageDto> postMessage({
    required RepositoryQuery query,
    required String incidentId,
    required String body,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      SupportApiPaths.messages(incidentId),
      queryParameters: _queryParams(query),
      data: {'body': body},
    );
    return SupportMessageDto.fromJson(_writeData(response));
  }

  Future<SupportPresignDto> presignAttachment({
    required RepositoryQuery query,
    required String incidentId,
    required String kind,
    required String fileName,
    required String contentType,
    required int sizeBytes,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      SupportApiPaths.presignAttachment(incidentId),
      queryParameters: _queryParams(query),
      data: {
        'kind': kind,
        'fileName': fileName,
        'contentType': contentType,
        'sizeBytes': sizeBytes,
      },
    );
    return SupportPresignDto.fromJson(_writeData(response));
  }

  /// Raw byte PUT to the absolute presigned Storage URL.
  Future<void> putBytes({
    required String signedUrl,
    required List<int> bytes,
    required String contentType,
  }) async {
    final data = Uint8List.fromList(bytes);
    await _uploadDio.putUri<void>(
      Uri.parse(signedUrl),
      data: Stream<List<int>>.fromIterable([data]),
      options: Options(
        headers: {
          Headers.contentLengthHeader: data.length,
        },
        contentType: contentType,
      ),
    );
  }

  Future<SupportAttachmentDto> confirmAttachment({
    required RepositoryQuery query,
    required String incidentId,
    required String kind,
    required String storagePath,
    required String fileName,
    required String contentType,
    required int sizeBytes,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      SupportApiPaths.confirmAttachment(incidentId),
      queryParameters: _queryParams(query),
      data: {
        'kind': kind,
        'storagePath': storagePath,
        'fileName': fileName,
        'contentType': contentType,
        'sizeBytes': sizeBytes,
      },
    );
    return SupportAttachmentDto.fromJson(_writeData(response));
  }

  Map<String, dynamic> _queryParams(RepositoryQuery query) {
    return {
      'tenantId': query.tenantId,
      if (query.schoolId != null) 'schoolId': query.schoolId,
      if (query.organizationId != null) 'organizationId': query.organizationId,
    };
  }

  /// Unwraps the `{data, error}` envelope returned by every `/support` endpoint.
  Map<String, dynamic> _writeData(Response<Map<String, dynamic>> response) {
    return ApiEnvelopeDto.fromJson(response.data ?? const {}).requireData();
  }
}
