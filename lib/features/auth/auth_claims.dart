import 'package:flutter/foundation.dart';

import '../../core/security/erp_role.dart';
import '../../core/security/permissions.dart';
import '../../core/tenant/tenant_context.dart';

/// Mock JWT claims persisted with the auth session (v1.6).
///
/// Multi-role: a user can hold several [ErpRole]s at once (e.g. Teacher +
/// Inventory Manager). [erpRoles] is the source of truth, ordered with the
/// primary role first. The legacy single-role API ([erpRole] getter, the
/// `erpRole:` constructor/copyWith/demoForRole params) keeps working and maps to
/// the primary role, so existing call sites are unaffected.
@immutable
class AuthClaims {
  AuthClaims({
    required this.userId,
    ErpRole? erpRole,
    List<ErpRole>? erpRoles,
    required this.tenantId,
    this.schoolId,
    this.organizationId,
    this.permissions = const [],
    this.accessTokenExpiresAt,
    this.isChainOrganization = false,
  })  : assert(
          erpRole != null || (erpRoles != null && erpRoles.isNotEmpty),
          'Provide erpRole or a non-empty erpRoles',
        ),
        erpRoles = _normalizeRoles(erpRole, erpRoles);

  final String userId;

  /// All roles the user holds, primary first. Never empty.
  final List<ErpRole> erpRoles;

  /// Primary (first) role — backward-compatible single-role accessor.
  ErpRole get erpRole => erpRoles.first;

  /// Whether the user holds [role] among their roles.
  bool hasRole(ErpRole role) => erpRoles.contains(role);

  /// Whether the user holds more than one role (drives the workspace switcher).
  bool get isMultiRole => erpRoles.length > 1;

  final String tenantId;
  final String? schoolId;
  final String? organizationId;
  final List<Permission> permissions;

  /// Whether the signed-in org is a CHAIN (a multi-school tenant). Single
  /// independent schools are not chains. Drives the M3 chain-flag gate that
  /// surfaces franchise / multi-school / organization-builder modules only for
  /// real chains (see [ChainScope]). Backend supplies this; defaults to `false`.
  final bool isChainOrganization;

  /// Dedupes [single]/[many] into an ordered, non-empty role list (primary first).
  static List<ErpRole> _normalizeRoles(ErpRole? single, List<ErpRole>? many) {
    final source = (many != null && many.isNotEmpty)
        ? many
        : (single != null ? <ErpRole>[single] : const <ErpRole>[]);
    final out = <ErpRole>[];
    for (final r in source) {
      if (!out.contains(r)) out.add(r);
    }
    return List.unmodifiable(out);
  }

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
    ErpRole? erpRole,
    Iterable<ErpRole>? erpRoles,
    String? userId,
    Iterable<Permission>? permissions,
    DateTime? accessTokenExpiresAt,
    bool isChainOrganization = false,
  }) {
    final roles = (erpRoles != null && erpRoles.isNotEmpty)
        ? erpRoles.toList(growable: false)
        : <ErpRole>[erpRole ?? ErpRole.parent];
    return AuthClaims(
      userId: userId ?? 'user_demo_${roles.first.name}',
      erpRoles: roles,
      tenantId: TenantContext.demo.tenantId,
      schoolId: TenantContext.demo.schoolId,
      organizationId: TenantContext.demo.organizationId,
      permissions: permissions?.toList(growable: false) ?? const [],
      accessTokenExpiresAt: accessTokenExpiresAt,
      isChainOrganization: isChainOrganization,
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

    // Multi-role: prefer the `roles` array; fall back to the legacy `role` key.
    final roleNames = (json['roles'] as List<dynamic>?)?.cast<String>();
    final roles = <ErpRole>[];
    if (roleNames != null) {
      for (final name in roleNames) {
        final r = ErpRole.fromName(name);
        if (r != null && !roles.contains(r)) roles.add(r);
      }
    }
    if (roles.isEmpty) {
      roles.add(ErpRole.fromName(json['role'] as String?) ?? ErpRole.parent);
    }

    return AuthClaims(
      userId: json['userId'] as String? ?? '',
      erpRoles: roles,
      tenantId: json['tenantId'] as String? ?? TenantContext.demo.tenantId,
      schoolId: json['schoolId'] as String?,
      organizationId: json['organizationId'] as String?,
      permissions: permissions,
      accessTokenExpiresAt: DateTime.tryParse(
        json['accessTokenExpiresAt'] as String? ?? '',
      ),
      isChainOrganization: json['isChainOrganization'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
        'userId': userId,
        // `role` (primary) kept for backward-compatible readers; `roles` is authoritative.
        'role': erpRole.name,
        'roles': erpRoles.map((r) => r.name).toList(),
        'tenantId': tenantId,
        if (schoolId != null) 'schoolId': schoolId,
        if (organizationId != null) 'organizationId': organizationId,
        if (permissions.isNotEmpty)
          'permissions': permissions.map((p) => p.name).toList(),
        if (accessTokenExpiresAt != null)
          'accessTokenExpiresAt': accessTokenExpiresAt!.toIso8601String(),
        if (isChainOrganization) 'isChainOrganization': true,
      };

  bool get isValid =>
      userId.isNotEmpty && tenantId.isNotEmpty && erpRoles.isNotEmpty;

  AuthClaims copyWith({
    String? userId,
    ErpRole? erpRole,
    List<ErpRole>? erpRoles,
    String? tenantId,
    String? schoolId,
    String? organizationId,
    List<Permission>? permissions,
    DateTime? accessTokenExpiresAt,
    bool? isChainOrganization,
  }) {
    return AuthClaims(
      userId: userId ?? this.userId,
      erpRoles: erpRoles ?? (erpRole != null ? <ErpRole>[erpRole] : this.erpRoles),
      tenantId: tenantId ?? this.tenantId,
      schoolId: schoolId ?? this.schoolId,
      organizationId: organizationId ?? this.organizationId,
      permissions: permissions ?? this.permissions,
      accessTokenExpiresAt:
          accessTokenExpiresAt ?? this.accessTokenExpiresAt,
      isChainOrganization: isChainOrganization ?? this.isChainOrganization,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AuthClaims &&
          userId == other.userId &&
          listEquals(erpRoles, other.erpRoles) &&
          tenantId == other.tenantId &&
          schoolId == other.schoolId &&
          organizationId == other.organizationId &&
          listEquals(permissions, other.permissions) &&
          accessTokenExpiresAt == other.accessTokenExpiresAt &&
          isChainOrganization == other.isChainOrganization;

  @override
  int get hashCode => Object.hash(
        userId,
        Object.hashAll(erpRoles),
        tenantId,
        schoolId,
        organizationId,
        permissions,
        accessTokenExpiresAt,
        isChainOrganization,
      );
}
