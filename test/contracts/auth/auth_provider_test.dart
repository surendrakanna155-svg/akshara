import 'package:akshara_erp/core/auth/auth_providers.dart';
import 'package:akshara_erp/core/repositories/api/auth/remote/auth_api_paths.dart';
import 'package:akshara_erp/core/repositories/mock/mock_auth_repository.dart';
import 'package:akshara_erp/features/auth/auth_provider.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_dio_interceptor.dart';
import '../../helpers/provider_test_overrides.dart';
import 'auth_fixture_builder.dart';

const _fixtures = AuthFixtureBuilder();

void main() {
  group('auth provider wiring', () {
    setUp(() async {
      await initProviderTestPrefs();
    });

    test('authRepositoryProvider returns mock by default', () {
      final container = createProviderTestContainer();
      addTearDown(container.dispose);

      expect(container.read(authRepositoryProvider), isA<MockAuthRepository>());
    });

    test('authRepositoryProvider returns api repo when flag enabled', () {
      final container = createProviderTestContainer(
        authApiEnabled: true,
      );
      addTearDown(container.dispose);

      final repo = container.read(authRepositoryProvider);
      expect(repo.runtimeType.toString(), contains('ApiAuthRepository'));
    });

    test('tokenRefreshCallback uses repository in api mode', () async {
      final dio = createFakeDio((options) {
        if (options.path == AuthApiPaths.refresh) {
          return _fixtures.tokensEnvelope(
            refreshToken: options.data['refreshToken'] as String? ?? '',
          );
        }
        return const {'data': {}};
      });

      final container = createProviderTestContainer(
        apiAuthDio: dio,
        authApiEnabled: true,
      );
      addTearDown(container.dispose);

      final callback = container.read(tokenRefreshCallbackProvider);
      expect(callback, isNotNull);

      final tokens = await callback!('refresh_test_token');
      expect(tokens, isNotNull);
      expect(tokens!.accessToken, isNotEmpty);
    });

    test('resolveSession leaves unauthenticated when empty storage', () async {
      final container = createProviderTestContainer();
      addTearDown(container.dispose);

      await container.read(authProvider.notifier).resolveSession();
      expect(container.read(authProvider).isAuthenticated, isFalse);
    });
  });
}
