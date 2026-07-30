import 'package:dio/dio.dart';

import '../../core/repositories/repository_query.dart';

/// The per-school attendance geofence — the FIRST gate of the attendance chain
/// (docs/ATTENDANCE_AUTH_DESIGN_DECISION.md §4). The server refuses EVERY
/// face-match check-in with `STAFF_ATTENDANCE_GEOFENCE_NOT_CONFIGURED` until a
/// school administrator has stored one of these, so this is not an optional
/// nicety — nothing in staff attendance works without it.
///
/// Field bounds mirror the server's `parseGeofenceBody`
/// (supabase/functions/_shared/staff_attendance/staff_attendance_handlers.ts)
/// AND the DB CHECK constraints (migration 20260820000000) exactly, so the
/// client never posts a payload the server will 422.
class SchoolGeofence {
  const SchoolGeofence({
    required this.centerLatitude,
    required this.centerLongitude,
    this.radiusM = defaultRadiusM,
    this.maxAccuracyM = defaultMaxAccuracyM,
    this.maxLocationAgeS = defaultMaxLocationAgeS,
  });

  /// Server/DB default when a field is omitted (see `parseGeofenceBody`).
  static const int defaultRadiusM = 100;
  static const int defaultMaxAccuracyM = 50;
  static const int defaultMaxLocationAgeS = 60;

  /// `geofence_radius_check CHECK (radius_m BETWEEN 25 AND 1000)`.
  static const int minRadiusM = 25;
  static const int maxRadiusM = 1000;

  /// `geofence_accuracy_check CHECK (max_accuracy_m BETWEEN 5 AND 200)`.
  static const int minAccuracyM = 5;
  static const int maxAccuracyLimitM = 200;

  /// The server silently falls back to 60s outside 10..600 — clamp client-side
  /// so what the admin sees saved is what actually got saved.
  static const int minLocationAgeS = 10;
  static const int maxLocationAgeS_ = 600;

  /// The radii the design decision names (§4: "default 100 m, e.g. 50 / 100 /
  /// 150 / 200 / 300 m").
  static const List<int> radiusChoices = [50, 100, 150, 200, 300];

  final double centerLatitude;
  final double centerLongitude;
  final int radiusM;
  final int maxAccuracyM;
  final int maxLocationAgeS;

  SchoolGeofence copyWith({
    double? centerLatitude,
    double? centerLongitude,
    int? radiusM,
    int? maxAccuracyM,
    int? maxLocationAgeS,
  }) {
    return SchoolGeofence(
      centerLatitude: centerLatitude ?? this.centerLatitude,
      centerLongitude: centerLongitude ?? this.centerLongitude,
      radiusM: radiusM ?? this.radiusM,
      maxAccuracyM: maxAccuracyM ?? this.maxAccuracyM,
      maxLocationAgeS: maxLocationAgeS ?? this.maxLocationAgeS,
    );
  }

  Map<String, dynamic> toJson() => {
        'centerLatitude': centerLatitude,
        'centerLongitude': centerLongitude,
        'radiusM': radiusM,
        'maxAccuracyM': maxAccuracyM,
        'maxLocationAgeS': maxLocationAgeS,
      };

  factory SchoolGeofence.fromJson(Map<String, dynamic> json) {
    double asDouble(dynamic v, double fallback) =>
        v is num ? v.toDouble() : (double.tryParse('$v') ?? fallback);
    int asInt(dynamic v, int fallback) =>
        v is num ? v.round() : (int.tryParse('$v') ?? fallback);

    return SchoolGeofence(
      centerLatitude: asDouble(json['centerLatitude'] ?? json['center_latitude'], 0),
      centerLongitude:
          asDouble(json['centerLongitude'] ?? json['center_longitude'], 0),
      radiusM: asInt(json['radiusM'] ?? json['radius_m'], defaultRadiusM),
      maxAccuracyM:
          asInt(json['maxAccuracyM'] ?? json['max_accuracy_m'], defaultMaxAccuracyM),
      maxLocationAgeS: asInt(
        json['maxLocationAgeS'] ?? json['max_location_age_s'],
        defaultMaxLocationAgeS,
      ),
    );
  }

  /// The first bound this configuration violates, or null when it is valid.
  /// Deliberately the SAME predicates the server enforces — a NaN latitude
  /// fails here too (`!(x >= -90 && x <= 90)` rejects NaN, where
  /// `x < -90 || x > 90` would let it through).
  String? validationError() {
    if (!(centerLatitude >= -90 && centerLatitude <= 90) ||
        !(centerLongitude >= -180 && centerLongitude <= 180)) {
      return 'Enter a valid latitude (-90..90) and longitude (-180..180).';
    }
    if (!(radiusM >= minRadiusM && radiusM <= maxRadiusM)) {
      return 'Radius must be between $minRadiusM m and $maxRadiusM m.';
    }
    if (!(maxAccuracyM >= minAccuracyM && maxAccuracyM <= maxAccuracyLimitM)) {
      return 'Accuracy limit must be between $minAccuracyM m and '
          '$maxAccuracyLimitM m.';
    }
    if (!(maxLocationAgeS >= minLocationAgeS &&
        maxLocationAgeS <= maxLocationAgeS_)) {
      return 'Location freshness must be between $minLocationAgeS s and '
          '$maxLocationAgeS_ s.';
    }
    return null;
  }
}

/// Raised when the SERVER rejects a geofence read/write. [code] is the raw
/// `STAFF_ATTENDANCE_*` code (422 GEOFENCE_INVALID) or `FORBIDDEN` (403 — the
/// caller does not hold `manageSchoolGeofence`, which the server is the
/// authority on).
class SchoolGeofenceRejected implements Exception {
  const SchoolGeofenceRejected(this.code, this.message);
  final String code;
  final String message;

  bool get isForbidden => code == 'FORBIDDEN' || code == 'PERMISSION_DENIED';

  @override
  String toString() => 'SchoolGeofenceRejected($code): $message';
}

/// Reads and writes the school attendance geofence.
///
///   GET /staff-attendance/geofence   read the active config (404 when unset)
///   PUT /staff-attendance/geofence   set it (`manageSchoolGeofence`-gated)
///
/// Same direct-Dio, tenant-scoped shape as [FaceEnrollmentDataSource]: a rare,
/// deliberate administrative action — never offline-queued.
class SchoolGeofenceDataSource {
  SchoolGeofenceDataSource({required Dio dio, required RepositoryQuery query})
      : _dio = dio,
        _query = query;

  final Dio _dio;
  final RepositoryQuery _query;

  static const String _path = '/staff-attendance/geofence';

  /// The school's active geofence, or null when it has never been configured
  /// (server 404 `STAFF_ATTENDANCE_GEOFENCE_NOT_CONFIGURED`). "Not configured"
  /// is a legitimate state, not an error — it is exactly what the admin is
  /// here to fix.
  Future<SchoolGeofence?> fetch() async {
    try {
      final response = await _dio.request<Map<String, dynamic>>(
        _path,
        queryParameters: _scope(),
        options: Options(method: 'GET'),
      );
      final data = response.data ?? const <String, dynamic>{};
      final inner = (data['data'] as Map<String, dynamic>?) ?? data;
      if (inner.isEmpty) return null;
      return SchoolGeofence.fromJson(inner);
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) return null;
      final rejection = _asRejection(e);
      if (rejection != null) throw rejection;
      rethrow;
    }
  }

  /// Stores [geofence]. Client-side bound checking runs FIRST so an obviously
  /// invalid form never reaches the network; the server re-validates regardless
  /// (it is the authority).
  Future<SchoolGeofence> save(SchoolGeofence geofence) async {
    final invalid = geofence.validationError();
    if (invalid != null) {
      throw SchoolGeofenceRejected('STAFF_ATTENDANCE_GEOFENCE_INVALID', invalid);
    }
    try {
      final response = await _dio.request<Map<String, dynamic>>(
        _path,
        data: geofence.toJson(),
        queryParameters: _scope(),
        options: Options(method: 'PUT'),
      );
      final data = response.data ?? const <String, dynamic>{};
      final inner = (data['data'] as Map<String, dynamic>?) ?? data;
      // The server echoes the stored config; fall back to what we sent when a
      // deployment returns an empty envelope.
      return inner.isEmpty ? geofence : SchoolGeofence.fromJson(inner);
    } on DioException catch (e) {
      final rejection = _asRejection(e);
      if (rejection != null) throw rejection;
      rethrow;
    }
  }

  /// Maps a 422 (bad payload) or 403 (missing `manageSchoolGeofence`) envelope
  /// to a typed rejection; else null.
  SchoolGeofenceRejected? _asRejection(DioException e) {
    final status = e.response?.statusCode;
    if (status != 422 && status != 403) return null;
    if (status == 403) {
      return const SchoolGeofenceRejected(
        'FORBIDDEN',
        'You do not have permission to change the school geofence.',
      );
    }
    final data = e.response?.data;
    if (data is Map) {
      final error = data['error'];
      if (error is Map) {
        final code = (error['code'] ?? '').toString();
        if (code.isNotEmpty) {
          return SchoolGeofenceRejected(
            code,
            (error['message'] ?? 'Geofence rejected').toString(),
          );
        }
      }
    }
    return null;
  }

  Map<String, dynamic> _scope() => {
        'tenantId': _query.tenantId,
        if (_query.schoolId != null) 'schoolId': _query.schoolId,
        if (_query.organizationId != null) 'organizationId': _query.organizationId,
      };
}
