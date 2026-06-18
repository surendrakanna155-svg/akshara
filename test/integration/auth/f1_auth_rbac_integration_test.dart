import 'package:akshara_erp/core/auth/auth_providers.dart';
import 'package:akshara_erp/core/repositories/api/auth/remote/auth_api_paths.dart';
import 'package:akshara_erp/core/security/erp_role.dart';
import 'package:akshara_erp/core/security/permissions.dart';
import 'package:akshara_erp/core/security/server_permission_provider.dart';
import 'package:akshara_erp/features/auth/auth_provider.dart';
import 'package:akshara_erp/features/auth/staff/staff_login_provider.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../contracts/auth/auth_fixture_builder.dart';
import '../../helpers/fake_dio_interceptor.dart';
import '../../helpers/provider_test_overrides.dart';

const _fixtures = AuthFixtureBuilder();

void main() {
  group('F1 auth + RBAC integration', () {
    setUp(() async {
      await initProviderTestPrefs();
    });

    test('login → verify → permissions sync → refresh path', () async {
      var refreshCalls = 0;
      final dio = createFakeDio((options) {
        switch (options.path) {
          case AuthApiPaths.login:
            return _fixtures.loginEnvelope();
          case AuthApiPaths.verifyOtp:
            return _fixtures.verifyOtpEnvelope(
              role: ErpRole.principal,
              permissions: const [
                Permission.viewManagement,
                Permission.approveRefunds,
              ],
            );
          case AuthApiPaths.permissions:
            return _fixtures.permissionsEnvelope(
              permissions: const [
                Permission.viewManagement,
                Permission.approveRefunds,
              ],
              permissionsVersion: 7,
            );
          case AuthApiPaths.refresh:
            refreshCalls++;
            return _fixtures.tokensEnvelope(
              refreshToken: options.data['refreshToken'] as String? ?? '',
            );
          case AuthApiPaths.me:
            return _fixtures.userEnvelope(role: ErpRole.principal);
          default:
            return const {'data': {}};
        }
      });

      final container = createProviderTestContainer(
        apiAuthDio: dio,
        authApiEnabled: true,
      );
      addTearDown(container.dispose);

      final login = container.read(staffLoginProvider.notifier);
      await login.sendOtp('staff@school.edu');
      final result = await login.verifyOtp('123456');
      expect(result, isNotNull);

      await container.read(authProvider.notifier).completeStaffLogin(result!);

      final sync = container.read(serverPermissionSyncProvider);
      expect(sync.snapshot, isNotNull);
      expect(sync.snapshot!.policy.version, 7);
      expect(
        sync.snapshot!.policy.effectivePermissions,
        contains(Permission.approveRefunds),
      );

      final refreshed = await container.read(tokenRefreshCallbackProvider)?.call(
            result.tokens.refreshToken,
          );
      expect(refreshed, isNotNull);
      expect(refreshCalls, 1);
    });
  });
}
