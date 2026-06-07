import 'package:dio/dio.dart';

import '../../../../audit/audit_event.dart';
import '../../admissions/dto/api_envelope_dto.dart';
import '../dto/audit_batch_upload_dto.dart';
import 'audit_api_paths.dart';

/// Dio-backed remote data source for audit event ingestion.
class AuditRemoteDataSource {
  AuditRemoteDataSource(this._dio);

  final Dio _dio;

  Future<AuditBatchUploadResponseDto> uploadBatch(List<AuditEvent> events) async {
    if (events.isEmpty) {
      return const AuditBatchUploadResponseDto(acceptedCount: 0);
    }

    final response = await _dio.post<Map<String, dynamic>>(
      AuditApiPaths.batch,
      data: AuditBatchUploadRequestDto.fromEvents(events).toJson(),
    );

    final envelope = ApiEnvelopeDto.fromJson(_responseMap(response));
    if (envelope.error != null) {
      throw StateError(
        'Audit upload failed: ${envelope.error!.code} — ${envelope.error!.message}',
      );
    }

    return AuditBatchUploadResponseDto.fromJson(_responseMap(response));
  }

  Map<String, dynamic> _responseMap(Response<Map<String, dynamic>> response) {
    return response.data ?? const {};
  }
}
