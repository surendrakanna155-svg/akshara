import 'package:flutter/foundation.dart';

import '../../core/security/erp_role.dart';
import '../../core/security/permissions.dart';
import '../../core/tenant/tenant_context.dart';

/// Mock JWT claims persisted with the auth session (v1.6).
@immutable
class AuthClaims {
  const AuthClaims({
    required this.userId,
    required this.erpRole,
    required this.tenantId,
    this.schoolId,
    this.organizationId,
    this.permissions = const [],
    this.accessTokenExpiresAt,
  });

  final String userId;
  final ErpRole erpRole;
  final String tenantId;
  final String? schoolId;
  final String? organizationId;
  final List<Permission> permissions;

  /// Access token expiry from the auth server (mock until backend connects).
  final DateTime? accessTokenExpiresAt;

  bool get isTokenExpired {
    if (accessTokenExpiresAt == null) return false;
    return DateTime.now().isAfter(accessTokenExpiresAt!);
  }

  bool get isTokenExpiringSoon {
    if (accessTokenExpiresAt == null) return false;
    return DateTime.now().isAfter(
      accessTokenExpiresAt!.subtract(const Duration(minutes: 5)),
    );
  }

  factory AuthClaims.demoForRole({
    required ErpRole erpRole,
    String? userId,
    Iterable<Permission>? permissions,
    DateTime? accessTokenExpiresAt,
  }) {
    return AuthClaims(
      userId: userId ?? 'user_demo_${erpRole.name}',
      erpRole: erpRole,
      tenantId: TenantContext.demo.tenantId,
      schoolId: TenantContext.demo.schoolId,
      organizationId: TenantContext.demo.organizationId,
      permissions: permissions?.toList(growable: false) ?? const [],
      accessTokenExpiresAt: accessTokenExpiresAt,
    );
  }

  factory AuthClaims.fromJson(Map<String, dynamic> json) {
    final permissionNames =
        (json['permissions'] as List<dynamic>? ?? const <dynamic>[])
            .cast<String>();
    final permissions = <Permission>[];
    for (final name in permissionNames) {
      for (final p in Permission.values) {
        if (p.name == name) {
          permissions.add(p);
          break;
        }
      }
    }

    return AuthClaims(
      userId: json['userId'] as String? ?? '',
      erpRole: ErpRole.fromName(json['role'] as String?) ?? ErpRole.parent,
      tenantId: json['tenantId'] as String? ?? TenantContext.demo.tenantId,
      schoolId: json['schoolId'] as String?,
      organizationId: json['organizationId'] as String?,
      permissions: permissions,
      accessTokenExpiresAt: DateTime.tryParse(
        json['accessTokenExpiresAt'] as String? ?? '',
      ),
    );
  }

  Map<String, dynamic> toJson() => {
        'userId': userId,
        'role': erpRole.name,
        'tenantId': tenantId,
        if (schoolId != null) 'schoolId': schoolId,
        if (organizationId != null) 'organizationId': organizationId,
        if (permissions.isNotEmpty)
          'permissions': permissions.map((p) => p.name).toList(),
        if (accessTokenExpiresAt != null)
          'accessTokenExpiresAt': accessTokenExpiresAt!.toIso8601String(),
      };

  bool get isValid =>
      userId.isNotEmpty && tenantId.isNotEmpty && ErpRole.fromName(erpRole.name) != null;

  AuthClaims copyWith({
    String? userId,
    ErpRole? erpRole,
    String? tenantId,
    String? schoolId,
    String? organizationId,
    List<Permission>? permissions,
    DateTime? accessTokenExpiresAt,
  }) {
    return AuthClaims(
      userId: userId ?? this.userId,
      erpRole: erpRole ?? this.erpRole,
      tenantId: tenantId ?? this.tenantId,
      schoolId: schoolId ?? this.schoolId,
      organizationId: organizationId ?? this.organizationId,
      permissions: permissions ?? this.permissions,
      accessTokenExpiresAt:
          accessTokenExpiresAt ?? this.accessTokenExpiresAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AuthClaims &&
          userId == other.userId &&
          erpRole == other.erpRole &&
          tenantId == other.tenantId &&
          schoolId == other.schoolId &&
          organizationId == other.organizationId &&
          listEquals(permissions, other.permissions) &&
          accessTokenExpiresAt == other.accessTokenExpiresAt;

  @override
  int get hashCode => Object.hash(
        userId,
        erpRole,
        tenantId,
        schoolId,
        organizationId,
        permissions,
        accessTokenExpiresAt,
      );
}
