import 'package:dio/dio.dart';

import '../../../school_config/school_configuration_models.dart';
import '../admissions/dto/api_envelope_dto.dart';

/// Tenant-authoritative persistence for per-school capability gating (B1).
///
/// Talks to `GET/PUT /school-config` (school scope, gated on
/// `viewSchoolSetup` / `manageSchoolSetup`). A GET that finds no row returns
/// `null` so the caller can fall back to its local default.
class SchoolConfigApiRepository {
  SchoolConfigApiRepository(this._dio);

  final Dio _dio;

  /// Fetches the school's stored configuration, or `null` if none persisted.
  Future<SchoolConfiguration?> fetch() async {
    final response = await _dio.get<Map<String, dynamic>>('/school-config');
    final data = ApiEnvelopeDto.fromJson(response.data ?? const {}).requireData();
    final raw = data['configuration'];
    if (raw is! Map<String, dynamic>) return null;
    return _fromApi(raw);
  }

  /// Upserts the configuration and returns the persisted value.
  Future<SchoolConfiguration> save(SchoolConfiguration config) async {
    final response = await _dio.put<Map<String, dynamic>>(
      '/school-config',
      data: _toApi(config),
    );
    final data = ApiEnvelopeDto.fromJson(response.data ?? const {}).requireData();
    final raw = data['configuration'];
    if (raw is Map<String, dynamic>) return _fromApi(raw);
    return config;
  }

  static Map<String, dynamic> _toApi(SchoolConfiguration config) => {
        'schoolType': config.schoolType.storageKey,
        'curriculum': config.curriculum.storageKey,
        'operationsModel': config.operationsModel.storageKey,
        'branchCount': config.branchCount,
        'capabilities': config.capabilities.toJson(),
      };

  static SchoolConfiguration _fromApi(Map<String, dynamic> raw) {
    return SchoolConfiguration(
      schoolType: SchoolType.fromStorageKey(raw['schoolType'] as String?),
      curriculum: SchoolCurriculum.fromStorageKey(raw['curriculum'] as String?),
      capabilities: SchoolCapabilities.fromJson(
        (raw['capabilities'] as Map?)?.cast<String, dynamic>() ?? const {},
      ),
      operationsModel: SchoolOperationsModel.fromStorageKey(
        raw['operationsModel'] as String?,
      ),
      branchCount: (raw['branchCount'] as num?)?.toInt() ?? 1,
      configuredAt: raw['configuredAt'] != null
          ? DateTime.tryParse(raw['configuredAt'] as String)
          : null,
    );
  }
}
