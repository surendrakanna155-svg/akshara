/// A persisted snapshot of a successful read response, served back when the
/// device is offline so previously-loaded screens still render (QA-X-004).
///
/// The reliability platform already persists *writes* (the outbox) and
/// in-progress forms (drafts). [CacheRecord] is the read-side counterpart: the
/// last good body for an idempotent `GET`, keyed by method + path + query +
/// tenant scope, kept in the same encrypted on-device store and wiped on
/// logout / user switch alongside drafts and the outbox.
class CacheRecord {
  const CacheRecord({
    required this.key,
    required this.json,
    required this.updatedAt,
    this.scope,
  });

  /// Stable request-scoped key, e.g. `GET /student/dashboard?studentId=…`,
  /// prefixed with the tenant scope so two tenants never share an entry.
  final String key;

  /// Optional tenant/user scope kept for debugging and eviction; isolation is
  /// primarily enforced by wiping the whole cache on logout (see `clear`).
  final String? scope;

  /// The cached response body — exactly what the remote data source parses.
  final Map<String, dynamic> json;

  /// When the snapshot was captured. Drives staleness display and LRU eviction.
  final DateTime updatedAt;

  CacheRecord copyWith({
    Map<String, dynamic>? json,
    DateTime? updatedAt,
  }) {
    return CacheRecord(
      key: key,
      scope: scope,
      json: json ?? this.json,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'key': key,
        'scope': scope,
        'json': json,
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory CacheRecord.fromJson(Map<String, dynamic> json) {
    return CacheRecord(
      key: json['key'] as String,
      scope: json['scope'] as String?,
      json: (json['json'] as Map?)?.cast<String, dynamic>() ??
          const <String, dynamic>{},
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }
}
