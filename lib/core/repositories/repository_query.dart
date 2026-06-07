import 'package:flutter/foundation.dart';

/// Tenant-scoped query passed to all repository methods.
@immutable
class RepositoryQuery {
  const RepositoryQuery({
    required this.tenantId,
    this.schoolId,
    this.organizationId,
  });

  final String tenantId;
  final String? schoolId;
  final String? organizationId;

  /// Default demo tenant for mock repositories and tests.
  static const demo = RepositoryQuery(
    tenantId: 'tenant_demo_001',
    schoolId: 'school_akshara_001',
    organizationId: 'org_akshara_001',
  );
}
