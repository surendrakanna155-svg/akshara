import 'package:akshara_erp/core/auth/auth_providers.dart';
import 'package:akshara_erp/core/repositories/api/auth/api_auth_repository.dart';
import 'package:akshara_erp/core/repositories/api/auth/mapper/auth_mapper.dart';
import 'package:akshara_erp/core/repositories/interfaces/auth_repository.dart';
import 'package:akshara_erp/core/repositories/mock/mock_auth_repository.dart';
import 'package:akshara_erp/core/security/permissions.dart';
import 'package:akshara_erp/core/security/rbac_service.dart';
import 'package:akshara_erp/core/security/server_permission_models.dart';
import 'package:akshara_erp/core/security/server_permission_provider.dart';
import 'package:akshara_erp/features/auth/auth_claims.dart';
import 'package:akshara_erp/features/auth/auth_models.dart';
import 'package:akshara_erp/features/auth/auth_provider.dart';
import 'package:akshara_erp/core/security/erp_role.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/provider_test_overrides.dart';

void main() {
  group('F1 API mode RBAC fail-closed', () {
    setUp(() async {
      await initProviderTestPrefs();
    });

    test('auth repository uses API implementation when auth API enabled', () {
      final container = createProviderTestContainer(authApiEnabled: true);
      addTearDown(container.dispose);

      expect(container.read(authRepositoryProvider), isA<ApiAuthRepository>());
    });

    test('auth repository uses mock when API mode disabled', () {
      final container = createProviderTestContainer();
      addTearDown(container.dispose);

      expect(container.read(authRepositoryProvider), isA<MockAuthRepository>());
    });

    test('API mode without permission snapshot denies manage permissions', () {
      final container = createProviderTestContainer(authApiEnabled: true);
      addTearDown(container.dispose);

      container.read(authProvider.notifier).state = AuthState(
        status: AuthStatus.authenticated,
        role: UserRole.staff,
        claims: AuthClaims(
          userId: 'staff_001',
          erpRole: ErpRole.superAdmin,
          tenantId: 'tenant_demo_001',
        ),
      );
      container.read(serverPermissionSyncProvider.notifier).state =
          const ServerPermissionSyncState();

      final rbac = container.read(rbacServiceProvider);
      expect(rbac.hasPermission(Permission.manageFinance), isFalse);
      expect(rbac.hasPermission(Permission.viewFinance), isFalse);
    });

    test('API mode uses synced server snapshot when present', () async {
      final container = createProviderTestContainer(authApiEnabled: true);
      addTearDown(container.dispose);

      container.read(authProvider.notifier).state = AuthState(
        status: AuthStatus.authenticated,
        role: UserRole.staff,
        claims: AuthClaims(
          userId: 'staff_001',
          erpRole: ErpRole.financeAdmin,
          tenantId: 'tenant_demo_001',
        ),
      );

      final policy = const AuthMapper().toPermissionPolicy(
        permissions: const [
          ServerPermission(permission: Permission.viewFinance),
        ],
        userId: 'staff_001',
        tenantId: 'tenant_demo_001',
      );
      final snapshot = await container
          .read(permissionCacheServiceProvider)
          .savePolicy(policy);
      container.read(serverPermissionSyncProvider.notifier).state =
          ServerPermissionSyncState(snapshot: snapshot);

      final rbac = container.read(rbacServiceProvider);
      expect(rbac.hasPermission(Permission.viewFinance), isTrue);
      expect(rbac.hasPermission(Permission.manageFinance), isFalse);
    });
  });
}
