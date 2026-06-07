import 'package:akshara_erp/core/audit/audit_event.dart';
import 'package:akshara_erp/core/audit/audit_provider.dart';
import 'package:akshara_erp/core/security/server_permission_provider.dart';
import 'package:akshara_erp/core/network/api_config.dart';
import 'package:akshara_erp/core/network/interceptors/tenant_interceptor.dart';
import 'package:akshara_erp/core/repositories/api/auth/remote/auth_api_paths.dart';
import 'package:akshara_erp/core/security/erp_role.dart';
import 'package:akshara_erp/core/security/permissions.dart';
import 'package:akshara_erp/core/tenant/tenant_context.dart';
import 'package:akshara_erp/features/auth/auth_provider.dart';
import 'package:akshara_erp/features/auth/staff/staff_login_provider.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../contracts/auth/auth_fixture_builder.dart';
import '../../helpers/fake_dio_interceptor.dart';
import '../../helpers/provider_test_overrides.dart';

const _fixtures = AuthFixtureBuilder();

void main() {
  group('Auth flow integration', () {
    setUp(() async {
      await initProviderTestPrefs();
    });

    test('staff login issues session and tokens', () async {
      final container = createProviderTestContainer();
      addTearDown(container.dispose);

      final login = container.read(staffLoginProvider.notifier);
      await login.sendOtp('staff@school.edu');
      final result = await login.verifyOtp(MockStaffOtpWorkflow.validOtp);
      expect(result, isNotNull);

      await container.read(authProvider.notifier).completeStaffLogin(result!);

      final auth = container.read(authProvider);
      expect(auth.isAuthenticated, isTrue);
      expect(auth.role?.name, 'staff');
      expect(auth.claims?.erpRole, ErpRole.superAdmin);
    });

    test('resolveSession restores staff session', () async {
      final container = createProviderTestContainer();
      addTearDown(container.dispose);

      final login = container.read(staffLoginProvider.notifier);
      await login.sendOtp('staff@school.edu');
      final result = await login.verifyOtp(MockStaffOtpWorkflow.validOtp);
      await container.read(authProvider.notifier).completeStaffLogin(result!);

      final fresh = createProviderTestContainer();
      addTearDown(fresh.dispose);
      await fresh.read(authProvider.notifier).resolveSession();

      final auth = fresh.read(authProvider);
      expect(auth.isAuthenticated, isTrue);
    });

    test('logout clears session', () async {
      final container = createProviderTestContainer();
      addTearDown(container.dispose);

      await container.read(authProvider.notifier).signInStaff(
            phoneNumber: '9876543210',
            displayName: 'Staff User',
          );
      await container.read(authProvider.notifier).logout();

      expect(container.read(authProvider).isAuthenticated, isFalse);
    });

    test('tenant interceptor propagates user and organization headers', () {
      final interceptor = TenantInterceptor(
        tenantAccessor: () => TenantContext.demo,
      );
      final options = RequestOptions(path: '/auth/me');
      RequestOptions? captured;

      interceptor.onRequest(
        options,
        _CaptureHandler((o) => captured = o),
      );

      expect(captured, isNotNull);
      expect(captured!.headers[ApiConfig.tenantIdHeader], isNotNull);
      expect(captured!.headers[ApiConfig.userIdHeader], isNotNull);
      expect(captured!.headers[ApiConfig.organizationIdHeader], isNotNull);
    });

    test('login writes audit event', () async {
      final container = createProviderTestContainer();
      addTearDown(container.dispose);

      await container.read(authProvider.notifier).signInStaff(
            phoneNumber: '9876543210',
            displayName: 'Staff User',
          );

      final events = await container.read(auditEventsProvider.future);
      expect(events.any((e) => e.type == AuditEventType.login), isTrue);
    });

    test('api staff login syncs server permissions', () async {
      final dio = createFakeDio((options) {
        switch (options.path) {
          case AuthApiPaths.login:
            return _fixtures.loginEnvelope();
          case AuthApiPaths.verifyOtp:
            return _fixtures.verifyOtpEnvelope(role: ErpRole.financeAdmin);
          case AuthApiPaths.permissions:
            return _fixtures.permissionsEnvelope();
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

      final auth = container.read(authProvider);
      expect(auth.isAuthenticated, isTrue);
      expect(auth.claims?.erpRole, ErpRole.financeAdmin);

      final sync = container.read(serverPermissionSyncProvider);
      expect(sync.snapshot, isNotNull);
      expect(
        sync.snapshot!.policy.effectivePermissions,
        contains(Permission.viewFinance),
      );
    });
  });
}

class _CaptureHandler extends RequestInterceptorHandler {
  _CaptureHandler(this.onCapture);

  final void Function(RequestOptions options) onCapture;

  @override
  void next(RequestOptions options) => onCapture(options);
}
