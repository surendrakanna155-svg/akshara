import 'package:dio/dio.dart';

import 'legal_models.dart';

/// REST paths for the legal acceptance API module.
abstract final class LegalApiPaths {
  static const String base = '/legal';
  static const String status = '$base/status';
  static const String accept = '$base/accept';
}

/// Dio-backed remote data source for the legal acceptance gate.
class LegalRemoteDataSource {
  LegalRemoteDataSource(this._dio);

  final Dio _dio;

  /// GET /legal/status — what the current user must accept / has accepted.
  Future<LegalStatus> fetchStatus() async {
    final response =
        await _dio.get<Map<String, dynamic>>(LegalApiPaths.status);
    return LegalStatus.fromEnvelope(response.data);
  }

  /// POST /legal/accept — records acceptance of [policies] (server captures the
  /// user, role, timestamp and IP; [deviceId] is included when known).
  Future<LegalStatus> accept({
    required List<LegalPolicy> policies,
    String? deviceId,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      LegalApiPaths.accept,
      data: {
        'acceptances': [
          for (final p in policies) {'key': p.key, 'version': p.version},
        ],
        if (deviceId != null) 'device_id': deviceId,
      },
    );
    return LegalStatus.fromEnvelope(response.data);
  }
}
