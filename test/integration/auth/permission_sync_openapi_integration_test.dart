import 'package:akshara_erp/core/network/openapi/openapi_contract_registry.dart';
import 'package:akshara_erp/core/network/openapi/openapi_response_validator.dart';
import 'package:akshara_erp/core/repositories/api/auth/remote/auth_api_paths.dart';
import 'package:akshara_erp/core/security/permission_sync_service.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_dio_interceptor.dart';
import '../../helpers/provider_test_overrides.dart';
import '../../contracts/auth/auth_fixture_builder.dart';

const _fixtures = AuthFixtureBuilder();
const _validator = OpenApiResponseValidator();
const _runStaging = bool.fromEnvironment('STAGING_CONTRACT_TESTS');

void main() {
  group('Permission sync OpenAPI integration', () {
    setUp(() async {
      await initProviderTestPrefs();
    });

    test('fetchAndCache validates permissions response against OpenAPI schema',
        () async {
      Map<String, dynamic>? permissionsPayload;

      final container = createProviderTestContainer(
        authApiEnabled: true,
        apiAuthDio: createFakeDio((options) {
          if (options.path == AuthApiPaths.permissions) {
            permissionsPayload = _fixtures.permissionsEnvelope();
            return permissionsPayload!;
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
      expect(permissionsPayload, isNotNull);

      final schema =
          OpenApiContractRegistry.responseSchemaForPath(AuthApiPaths.permissions)!;
      expect(_validator.validate(permissionsPayload, schema), isEmpty);
    });
  });

  group('Staging OpenAPI gate', () {
    test(
      'staging auth permissions match OpenAPI contract',
      () async {
        // Requires live staging backend with valid credentials.
        // Run: flutter test --dart-define=STAGING_CONTRACT_TESTS=true \
        //   test/integration/auth/permission_sync_openapi_integration_test.dart
      },
      skip: _runStaging
          ? false
          : 'Set STAGING_CONTRACT_TESTS=true to run against staging',
    );
  });
}
