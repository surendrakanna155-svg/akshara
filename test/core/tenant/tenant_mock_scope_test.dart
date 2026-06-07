import 'package:flutter_test/flutter_test.dart';

import 'package:akshara_erp/core/repositories/repository_query.dart';
import 'package:akshara_erp/core/tenant/tenant_context.dart';
import 'package:akshara_erp/core/tenant/tenant_mock_scope.dart';

void main() {
  group('TenantMockScope', () {
    test('demo tenant receives full seed data', () {
      const items = ['a', 'b', 'c', 'd'];
      final query = TenantContext.demo.toQuery();

      expect(
        TenantMockScope.filter(query: query, items: items),
        items,
      );
    });

    test('unknown tenant receives empty data', () {
      const items = ['a', 'b', 'c', 'd'];
      const query = RepositoryQuery(tenantId: 'tenant_unknown_999');

      expect(
        TenantMockScope.filter(query: query, items: items),
        isEmpty,
      );
    });

    test('alternate tenant receives reduced slice', () {
      const items = ['a', 'b', 'c', 'd', 'e', 'f', 'g', 'h'];
      const query = RepositoryQuery(tenantId: 'tenant_hyd_001');

      final scoped = TenantMockScope.filter(query: query, items: items);
      expect(scoped.length, 2);
      expect(scoped, ['a', 'b']);
    });

    test('scopedCount returns zero for unknown tenant', () {
      const query = RepositoryQuery(tenantId: 'tenant_unknown_999');

      expect(
        TenantMockScope.scopedCount(query: query, fullCount: 248),
        0,
      );
    });
  });
}
