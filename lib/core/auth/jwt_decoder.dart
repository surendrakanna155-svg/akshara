import 'dart:convert';

/// Parsed JWT payload fields used by the client session layer.
class JwtClaims {
  const JwtClaims({
    this.subject,
    this.tenantId,
    this.schoolId,
    this.organizationId,
    this.role,
    this.permissions = const [],
    this.expiresAt,
    this.issuedAt,
  });

  final String? subject;
  final String? tenantId;
  final String? schoolId;
  final String? organizationId;
  final String? role;
  final List<String> permissions;
  final DateTime? expiresAt;
  final DateTime? issuedAt;

  bool get isExpired {
    if (expiresAt == null) return false;
    return DateTime.now().isAfter(expiresAt!);
  }

  bool get isExpiringSoon {
    if (expiresAt == null) return false;
    return DateTime.now().isAfter(
      expiresAt!.subtract(const Duration(minutes: 5)),
    );
  }
}

/// Decodes JWT payloads without signature verification (client-side only).
class JwtDecoder {
  const JwtDecoder();

  /// Returns `true` when [token] has three base64url segments.
  bool isJwtFormat(String token) {
    final parts = token.split('.');
    return parts.length == 3 && parts.every((part) => part.isNotEmpty);
  }

  /// Decodes the payload segment of a JWT access token.
  JwtClaims? decode(String token) {
    if (!isJwtFormat(token)) return null;

    try {
      final payload = token.split('.')[1];
      final normalized = base64Url.normalize(payload);
      final decoded = utf8.decode(base64Url.decode(normalized));
      final json = jsonDecode(decoded);
      if (json is! Map<String, dynamic>) return null;
      return _mapClaims(json);
    } on Object {
      return null;
    }
  }

  DateTime? expirationFromToken(String token) => decode(token)?.expiresAt;

  bool isExpired(String token) {
    final claims = decode(token);
    return claims?.isExpired ?? false;
  }

  JwtClaims _mapClaims(Map<String, dynamic> json) {
    final permissions = <String>[];
    final rawPermissions = json['permissions'] ?? json['perms'];
    if (rawPermissions is List) {
      for (final item in rawPermissions) {
        if (item is String) permissions.add(item);
      }
    }

    return JwtClaims(
      subject: json['sub'] as String? ?? json['userId'] as String?,
      tenantId: json['tenant_id'] as String? ?? json['tenantId'] as String?,
      schoolId: json['school_id'] as String? ?? json['schoolId'] as String?,
      organizationId:
          json['organization_id'] as String? ?? json['organizationId'] as String?,
      role: json['role'] as String? ?? json['erp_role'] as String?,
      permissions: permissions,
      expiresAt: _parseEpoch(json['exp']),
      issuedAt: _parseEpoch(json['iat']),
    );
  }

  DateTime? _parseEpoch(Object? value) {
    if (value is int) {
      return DateTime.fromMillisecondsSinceEpoch(value * 1000, isUtc: true).toLocal();
    }
    if (value is String) {
      return DateTime.tryParse(value);
    }
    return null;
  }

  /// Builds a mock JWT for tests and demo staff login (unsigned).
  static String buildMockToken({
    required String subject,
    required String tenantId,
    String? schoolId,
    String? organizationId,
    String? role,
    List<String> permissions = const [],
    Duration ttl = const Duration(hours: 1),
  }) {
    final exp = DateTime.now().add(ttl).millisecondsSinceEpoch ~/ 1000;
    final header = base64Url.encode(utf8.encode('{"alg":"none","typ":"JWT"}'));
    final payload = base64Url.encode(
      utf8.encode(
        jsonEncode({
          'sub': subject,
          'tenant_id': tenantId,
          if (schoolId != null) 'school_id': schoolId,
          if (organizationId != null) 'organization_id': organizationId,
          if (role != null) 'role': role,
          if (permissions.isNotEmpty) 'permissions': permissions,
          'exp': exp,
          'iat': DateTime.now().millisecondsSinceEpoch ~/ 1000,
        }),
      ),
    );
    return '$header.$payload.mock_signature';
  }
}

const jwtDecoder = JwtDecoder();
