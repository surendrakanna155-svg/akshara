import 'package:akshara_erp/core/repositories/api/auth/remote/auth_api_paths.dart';
import 'package:akshara_erp/core/repositories/api/auth/remote/auth_remote_datasource.dart';
import 'package:akshara_erp/core/security/erp_role.dart';
import 'package:akshara_erp/core/security/permissions.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_dio_interceptor.dart';
import 'auth_fixture_builder.dart';

const _fixtures = AuthFixtureBuilder();

void main() {
  group('AuthRemoteDataSource', () {
    late AuthRemoteDataSource remote;

    setUp(() {
      final dio = createFakeDio((options) {
        switch (options.path) {
          case AuthApiPaths.login:
            return _fixtures.loginEnvelope();
          case AuthApiPaths.verifyOtp:
            return _fixtures.verifyOtpEnvelope(role: ErpRole.financeAdmin);
          case AuthApiPaths.refresh:
            return _fixtures.tokensEnvelope(
              refreshToken: options.data['refreshToken'] as String? ?? '',
            );
          case AuthApiPaths.logout:
            return const {'data': {'success': true}};
          case AuthApiPaths.me:
            return _fixtures.userEnvelope(role: ErpRole.financeAdmin);
          case AuthApiPaths.permissions:
            return _fixtures.permissionsEnvelope();
          default:
            return const {'data': {}};
        }
      });
      remote = AuthRemoteDataSource(dio);
    });

    test('login posts identifier and type', () async {
      final dto = await remote.login(
        identifier: 'staff@school.edu',
        identifierType: 'email',
      );
      expect(dto.raw['success'], isTrue);
    });

    test('verifyOtp returns token payload', () async {
      final dto = await remote.verifyOtp(
        identifier: 'staff@school.edu',
        otp: '123456',
        identifierType: 'email',
      );
      expect(dto.raw['accessToken'], isNotEmpty);
      expect(dto.raw['user'], isA<Map<String, dynamic>>());
    });

    test('refreshToken returns refreshed tokens', () async {
      final dto = await remote.refreshToken(refreshToken: 'refresh_abc');
      expect(dto.raw['accessToken'], isNotEmpty);
      expect(dto.raw['refreshToken'], 'refresh_abc');
    });

    test('fetchCurrentUser returns profile', () async {
      final dto = await remote.fetchCurrentUser();
      expect(dto.raw['role'], ErpRole.financeAdmin.name);
    });

    test('fetchPermissions returns grants', () async {
      final dto = await remote.fetchPermissions();
      expect(dto.items.length, 2);
      expect(dto.items.first['permission'], Permission.viewFinance.name);
    });

    test('logout completes without error', () async {
      await expectLater(remote.logout(), completes);
    });
  });
}
