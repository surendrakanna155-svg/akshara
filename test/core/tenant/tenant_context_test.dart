import 'package:akshara_erp/core/repositories/repository_query.dart';
import 'package:akshara_erp/core/tenant/tenant_context.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('TenantContext', () {
    test('demo constant has expected identifiers', () {
      expect(TenantContext.demo.tenantId, 'tenant_demo_001');
      expect(TenantContext.demo.schoolId, 'school_akshara_001');
      expect(TenantContext.demo.organizationId, 'org_akshara_001');
    });

    test('toQuery maps tenant fields', () {
      const tenant = TenantContext(
        tenantId: 't1',
        schoolId: 's1',
        organizationId: 'o1',
        userId: 'u1',
      );
      final query = tenant.toQuery();
      expect(query.tenantId, 't1');
      expect(query.schoolId, 's1');
      expect(query.organizationId, 'o1');
    });

    test('copyWith preserves unspecified fields', () {
      final updated = TenantContext.demo.copyWith(userId: 'user_new');
      expect(updated.userId, 'user_new');
      expect(updated.tenantId, TenantContext.demo.tenantId);
    });

    test('RepositoryQuery.demo aligns with TenantContext.demo', () {
      final query = TenantContext.demo.toQuery();
      expect(query.tenantId, RepositoryQuery.demo.tenantId);
      expect(query.schoolId, RepositoryQuery.demo.schoolId);
    });
  });
}
