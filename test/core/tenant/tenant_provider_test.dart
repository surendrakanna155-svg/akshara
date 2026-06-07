import 'package:akshara_erp/core/repositories/repository_query.dart';
import 'package:akshara_erp/core/security/erp_role.dart';
import 'package:akshara_erp/core/tenant/tenant_context.dart';
import 'package:akshara_erp/core/tenant/tenant_provider.dart';
import 'package:akshara_erp/features/auth/auth_claims.dart';
import 'package:akshara_erp/features/auth/auth_models.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/auth_test_overrides.dart';

void main() {
  group('tenantContextProvider', () {
    test('uses claims tenant when authenticated', () {
      const claims = AuthClaims(
        userId: 'user_99',
        erpRole: ErpRole.superAdmin,
        tenantId: 'tenant_prod_42',
        schoolId: 'school_99',
        organizationId: 'org_99',
      );

      final container = ProviderContainer(
        overrides: [
          authStateOverride(
            const AuthState(
              status: AuthStatus.authenticated,
              phoneNumber: '9876543210',
              displayName: 'Staff',
              role: UserRole.staff,
              claims: claims,
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      final tenant = container.read(tenantContextProvider);
      expect(tenant.tenantId, 'tenant_prod_42');
      expect(tenant.schoolId, 'school_99');
      expect(tenant.organizationId, 'org_99');
      expect(tenant.userId, 'user_99');
    });

    test('repositoryQueryProvider mirrors tenant context', () {
      final container = ProviderContainer(
        overrides: [
          authStateOverride(
            AuthState(
              status: AuthStatus.authenticated,
              phoneNumber: '9876543210',
              displayName: 'Staff',
              role: UserRole.staff,
              claims: AuthClaims.demoForRole(erpRole: ErpRole.superAdmin),
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      final query = container.read(repositoryQueryProvider);
      expect(query.tenantId, TenantContext.demo.tenantId);
      expect(query.schoolId, RepositoryQuery.demo.schoolId);
      expect(query.organizationId, RepositoryQuery.demo.organizationId);
    });
  });
}
