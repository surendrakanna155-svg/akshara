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

  test('stale server cache falls back to JWT claims permissions', () async {
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
              ],
            ),
          ),
        ),
      ]),
    );
    addTearDown(container.dispose);

    final now = DateTime.now();
    final staleSnapshot = CachedPermissionSnapshot(
      policy: ServerPermissionPolicy(
        version: 1,
        syncedAt: now.subtract(const Duration(hours: 13)),
        userId: 'staff_001',
        grants: [
          PermissionGrant(
            permission: Permission.viewAdmissions,
            grantedAt: now,
          ),
        ],
        revocations: const [],
      ),
      cachedAt: now.subtract(const Duration(hours: 13)),
      expiresAt: now.subtract(const Duration(minutes: 1)),
    );

    container.read(serverPermissionSyncProvider.notifier).state =
        ServerPermissionSyncState(snapshot: staleSnapshot);

    final rbac = container.read(rbacServiceProvider);
    expect(rbac.hasPermission(Permission.viewFinance), isTrue);
    expect(rbac.hasManagePermission(Permission.manageFinance), isTrue);
    expect(rbac.hasPermission(Permission.viewAdmissions), isFalse);
  });

  test('fresh server cache overrides JWT claims', () async {
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
              ],
            ),
          ),
        ),
      ]),
    );
    addTearDown(container.dispose);

    final snapshot = await container.read(permissionCacheServiceProvider).savePolicy(
          ServerPermissionPolicy(
            version: 1,
            syncedAt: DateTime.now(),
            userId: 'staff_001',
            grants: [
              PermissionGrant(
                permission: Permission.viewFinance,
                grantedAt: DateTime.now(),
              ),
              PermissionGrant(
                permission: Permission.manageFinance,
                grantedAt: DateTime.now(),
              ),
            ],
            revocations: const [],
          ),
        );
    container.read(serverPermissionSyncProvider.notifier).state =
        ServerPermissionSyncState(snapshot: snapshot);

    final rbac = container.read(rbacServiceProvider);
    expect(rbac.hasManagePermission(Permission.manageFinance), isTrue);
  });
}
