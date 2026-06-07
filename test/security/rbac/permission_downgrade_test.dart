import 'package:akshara_erp/core/security/erp_role.dart';
import 'package:akshara_erp/core/security/permissions.dart';
import 'package:akshara_erp/core/security/rbac_service.dart';
import 'package:akshara_erp/core/security/server_permission_models.dart';
import 'package:akshara_erp/core/security/server_permission_provider.dart';
import 'package:akshara_erp/features/auth/auth_claims.dart';
import 'package:akshara_erp/features/auth/auth_models.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/auth_test_overrides.dart';
import '../../helpers/provider_test_overrides.dart';

void main() {
  setUp(() async {
    await initProviderTestPrefs();
  });

  test('server downgrade removes permissions from effective RBAC', () async {
    final container = ProviderContainer(
      overrides: providerTestOverrides([
        authStateOverride(
          AuthState(
            status: AuthStatus.authenticated,
            phoneNumber: '9876543210',
            displayName: 'Finance',
            role: UserRole.staff,
            claims: AuthClaims.demoForRole(
              erpRole: ErpRole.financeAdmin,
              userId: 'staff_001',
              permissions: const [
                Permission.viewFinance,
                Permission.manageFinance,
                Permission.viewAdmissions,
              ],
            ),
          ),
        ),
      ]),
    );
    addTearDown(container.dispose);

    final now = DateTime.now();
    final downgradedPolicy = ServerPermissionPolicy(
      version: 2,
      syncedAt: now,
      userId: 'staff_001',
      grants: [
        PermissionGrant(
          permission: Permission.viewFinance,
          grantedAt: now,
        ),
      ],
      revocations: [
        PermissionRevocation(
          permission: Permission.manageFinance,
          revokedAt: now,
          reason: 'role_change',
        ),
      ],
    );

    final snapshot = await container
        .read(permissionCacheServiceProvider)
        .savePolicy(downgradedPolicy);
    container.read(serverPermissionSyncProvider.notifier).state =
        ServerPermissionSyncState(snapshot: snapshot);

    final rbac = container.read(rbacServiceProvider);
    expect(rbac.hasPermission(Permission.viewFinance), isTrue);
    expect(rbac.hasManagePermission(Permission.manageFinance), isFalse);
    expect(rbac.hasPermission(Permission.viewAdmissions), isFalse);
  });
}
