import 'package:flutter/foundation.dart';

import '../repositories/repository_query.dart';

/// Tenant-scoped identity for the active session.
@immutable
class TenantContext {
  const TenantContext({
    required this.tenantId,
    this.schoolId,
    this.organizationId,
    required this.userId,
  });

  final String tenantId;
  final String? schoolId;
  final String? organizationId;
  final String userId;

  static const demo = TenantContext(
    tenantId: 'tenant_demo_001',
    schoolId: 'school_akshara_001',
    organizationId: 'org_akshara_001',
    userId: 'user_demo_001',
  );

  RepositoryQuery toQuery() => RepositoryQuery(
        tenantId: tenantId,
        schoolId: schoolId,
        organizationId: organizationId,
      );

  TenantContext copyWith({
    String? tenantId,
    String? schoolId,
    String? organizationId,
    String? userId,
  }) {
    return TenantContext(
      tenantId: tenantId ?? this.tenantId,
      schoolId: schoolId ?? this.schoolId,
      organizationId: organizationId ?? this.organizationId,
      userId: userId ?? this.userId,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TenantContext &&
          tenantId == other.tenantId &&
          schoolId == other.schoolId &&
          organizationId == other.organizationId &&
          userId == other.userId;

  @override
  int get hashCode =>
      Object.hash(tenantId, schoolId, organizationId, userId);
}

/// Combined user + tenant snapshot for repository and RBAC layers.
@immutable
class CurrentUserContext {
  const CurrentUserContext({
    required this.tenant,
    required this.displayName,
    this.phoneNumber,
  });

  final TenantContext tenant;
  final String displayName;
  final String? phoneNumber;

  String get tenantId => tenant.tenantId;
  String? get schoolId => tenant.schoolId;
  String? get organizationId => tenant.organizationId;
  String get userId => tenant.userId;

  RepositoryQuery toRepositoryQuery() => tenant.toQuery();
}
