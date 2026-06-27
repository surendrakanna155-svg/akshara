// Client models for the in-app legal acceptance gate. Mirrors the backend
// `_shared/legal/legal_catalog.ts` payload shape.

/// A single legal policy the user may need to read and accept.
class LegalPolicy {
  const LegalPolicy({
    required this.key,
    required this.title,
    required this.version,
    required this.summary,
    required this.path,
  });

  /// Stable identifier, e.g. `privacy`, `user_terms`.
  final String key;
  final String title;

  /// Catalog version the user is being asked to accept, e.g. `2.0`.
  final String version;

  /// Plain-language one-line description for the acceptance card.
  final String summary;

  /// Public sub-path the full document lives at once hosted, e.g. `/privacy`.
  final String path;

  factory LegalPolicy.fromJson(Map<String, dynamic> json) {
    return LegalPolicy(
      key: json['key'] as String? ?? '',
      title: json['title'] as String? ?? '',
      version: json['version'] as String? ?? '',
      summary: json['summary'] as String? ?? '',
      path: json['path'] as String? ?? '',
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LegalPolicy &&
          key == other.key &&
          version == other.version;

  @override
  int get hashCode => Object.hash(key, version);
}

/// The legal status for the current user: which policies apply, and which are
/// still outstanding at the current version.
class LegalStatus {
  const LegalStatus({
    required this.policies,
    required this.outstanding,
    required this.satisfied,
  });

  /// Every policy that applies to this user's role.
  final List<LegalPolicy> policies;

  /// Policies the user has NOT yet accepted at the current version.
  final List<LegalPolicy> outstanding;

  /// True when nothing is outstanding (the user is allowed through).
  final bool satisfied;

  static List<LegalPolicy> _parseList(Object? raw) {
    if (raw is! List) return const [];
    return raw
        .whereType<Map<String, dynamic>>()
        .map(LegalPolicy.fromJson)
        .toList(growable: false);
  }

  /// Parses the standard `{ data: {...}, error: null }` envelope.
  factory LegalStatus.fromEnvelope(Map<String, dynamic>? body) {
    final data = body?['data'];
    final map = data is Map<String, dynamic> ? data : const <String, dynamic>{};
    final outstanding = _parseList(map['outstanding']);
    return LegalStatus(
      policies: _parseList(map['policies']),
      outstanding: outstanding,
      // Trust the server's flag, but fall back to the outstanding list so an
      // older payload without `satisfied` still behaves correctly.
      satisfied: (map['satisfied'] as bool?) ?? outstanding.isEmpty,
    );
  }
}
