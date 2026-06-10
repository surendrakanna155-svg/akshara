import 'package:flutter/foundation.dart';

import 'paginated_result.dart';

/// Tenant-scoped query passed to all repository methods.
@immutable
class RepositoryQuery {
  const RepositoryQuery({
    required this.tenantId,
    this.schoolId,
    this.organizationId,
    this.page = 1,
    this.pageSize = kDefaultRepositoryPageSize,
    this.additionalQueryParams = const {},
  });

  final String tenantId;
  final String? schoolId;
  final String? organizationId;
  final int page;
  final int pageSize;

  /// Module-specific query params (e.g. SIS list filters) — not sent as tenant scope.
  final Map<String, String> additionalQueryParams;

  /// Default demo tenant for mock repositories and tests.
  static const demo = RepositoryQuery(
    tenantId: 'tenant_demo_001',
    schoolId: 'school_akshara_001',
    organizationId: 'org_akshara_001',
  );

  RepositoryQuery withPage(int page, {int? pageSize}) {
    return RepositoryQuery(
      tenantId: tenantId,
      schoolId: schoolId,
      organizationId: organizationId,
      page: page,
      pageSize: pageSize ?? this.pageSize,
      additionalQueryParams: additionalQueryParams,
    );
  }

  RepositoryQuery withAdditionalParams(Map<String, String> params) {
    return RepositoryQuery(
      tenantId: tenantId,
      schoolId: schoolId,
      organizationId: organizationId,
      page: page,
      pageSize: pageSize,
      additionalQueryParams: {...additionalQueryParams, ...params},
    );
  }

  Map<String, dynamic> paginationQueryParams() => {
        'page': page,
        'pageSize': pageSize,
        ...additionalQueryParams,
      };
}
