import 'package:akshara_erp/core/repositories/api/auth/remote/auth_api_paths.dart';
import 'package:akshara_erp/core/security/permission_sync_service.dart';
import 'package:akshara_erp/core/security/permissions.dart';
import 'package:akshara_erp/core/security/server_permission_models.dart';
import 'package:akshara_erp/core/security/server_permission_provider.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../contracts/auth/auth_fixture_builder.dart';
import '../../helpers/fake_dio_interceptor.dart';
import '../../helpers/provider_test_overrides.dart';

const _fixtures = AuthFixtureBuilder();

void main() {
  group('PermissionSyncService', () {
    setUp(() async {
      await initProviderTestPrefs();
    });

    test('fetchAndCache stores policy for user', () async {
      final container = createProviderTestContainer(
        authApiEnabled: true,
        apiAuthDio: createFakeDio((options) {
          if (options.path == AuthApiPaths.permissions) {
            return _fixtures.permissionsEnvelope(
              permissions: const [
                Permission.viewFinance,
                Permission.manageFinance,
              ],
            );
          }
          return const {'data': {}};
        }),
      );
      addTearDown(container.dispose);

      final result = await container
          .read(permissionSyncServiceProvider)
          .fetchAndCache(
            userId: 'staff_api_001',
            tenantId: 'tenant_demo_001',
          );

      expect(result.isSuccess, isTrue);
      expect(
        result.snapshot!.policy.effectivePermissions,
        containsAll([
          Permission.viewFinance,
          Permission.manageFinance,
        ]),
      );
      expect(result.snapshot!.policy.userId, 'staff_api_001');
    });

    test('loadCachedServerPermissionsHook hydrates sync state', () async {
      final container = createProviderTestContainer(
        authApiEnabled: true,
        apiAuthDio: createFakeDio((options) {
          if (options.path == AuthApiPaths.permissions) {
            return _fixtures.permissionsEnvelope();
          }
          return const {'data': {}};
        }),
      );
      addTearDown(container.dispose);

      final result = await container
          .read(permissionSyncServiceProvider)
          .fetchAndCache(
            userId: 'staff_api_001',
            tenantId: 'tenant_demo_001',
          );
      expect(result.isSuccess, isTrue);

      container.read(serverPermissionSyncProvider.notifier).state =
          const ServerPermissionSyncState();

      final snapshot = await container.read(permissionCacheServiceProvider).read();
      container.read(serverPermissionSyncProvider.notifier).state =
          ServerPermissionSyncState(snapshot: snapshot);

      final sync = container.read(serverPermissionSyncProvider);
      expect(sync.snapshot, isNotNull);
      expect(sync.snapshot!.policy.userId, 'staff_api_001');
    });
  });
}
