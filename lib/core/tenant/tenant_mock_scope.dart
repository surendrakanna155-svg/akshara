import '../repositories/repository_query.dart';
import 'tenant_context.dart';

/// Filters mock repository seed data by active tenant for multi-tenant demos.
///
/// Demo tenant ([TenantContext.demo]) receives full seed data. Other tenants
/// receive an empty slice unless explicitly registered in [alternateTenants].
class TenantMockScope {
  const TenantMockScope._();

  static const _alternateTenants = <String>{
    'tenant_hyd_001',
    'tenant_gv_002',
    'tenant_blr_003',
  };

  /// Whether [query] should receive demo seed data.
  static bool isDemoTenant(RepositoryQuery query) =>
      query.tenantId == TenantContext.demo.tenantId;

  /// Returns [items] scoped to the active tenant.
  ///
  /// Non-demo tenants without alternate registration receive an empty list so
  /// cross-tenant data never leaks in mock mode.
  static List<T> filter<T>({
    required RepositoryQuery query,
    required List<T> items,
  }) {
    if (isDemoTenant(query)) return items;
    if (_alternateTenants.contains(query.tenantId)) {
      return items.take((items.length / 4).ceil().clamp(1, items.length)).toList();
    }
    return const [];
  }

  /// Returns a tenant-scoped count for KPI displays.
  static int scopedCount({
    required RepositoryQuery query,
    required int fullCount,
  }) {
    if (isDemoTenant(query)) return fullCount;
    if (_alternateTenants.contains(query.tenantId)) {
      return (fullCount / 4).ceil().clamp(1, fullCount);
    }
    return 0;
  }
}
