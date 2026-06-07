import 'dart:io';

import 'package:akshara_erp/core/repositories/repository_query.dart';
import 'package:akshara_erp/core/tenant/tenant_api_propagation_registry.dart';
import 'package:akshara_erp/core/tenant/tenant_context.dart';
import 'package:akshara_erp/core/tenant/tenant_mock_scope.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Tenant isolation validation suite', () {
    test('demo tenant receives full mock data', () {
      const items = ['a', 'b', 'c'];
      expect(
        TenantMockScope.filter(
          query: TenantContext.demo.toQuery(),
          items: items,
        ),
        items,
      );
    });

    test('unknown tenant receives empty mock data', () {
      const query = RepositoryQuery(tenantId: 'tenant_unknown');
      expect(
        TenantMockScope.filter(query: query, items: const ['a', 'b']),
        isEmpty,
      );
    });

    test('all live remote datasources reference tenantId in query params', () {
      const base = 'lib/core/repositories/api/';
      const headerOnly = {
        'auth/remote/auth_remote_datasource.dart',
        'audit/remote/audit_remote_datasource.dart',
      };
      for (final relative in TenantApiPropagationRegistry.liveRemoteDatasources) {
        if (headerOnly.contains(relative)) continue;
        final file = File('$base$relative');
        expect(file.existsSync(), isTrue, reason: relative);
        final content = file.readAsStringSync();
        expect(
          content.contains('tenantId'),
          isTrue,
          reason: '$relative must propagate tenantId',
        );
      }
    });

    test('shared Dio applies tenant accessor for header propagation', () {
      final dioClient = File('lib/core/network/dio_client.dart');
      final dioProvider = File('lib/core/network/dio_provider.dart');
      expect(dioClient.readAsStringSync(), contains('TenantInterceptor'));
      expect(dioProvider.readAsStringSync(), contains('tenantAccessor'));
    });

    test('tenant interceptor header keys are defined in ApiConfig usage', () {
      final tenantInterceptor = File(
        'lib/core/network/interceptors/tenant_interceptor.dart',
      );
      final apiConfig = File('lib/core/network/api_config.dart');
      expect(tenantInterceptor.readAsStringSync(), contains('tenantIdHeader'));
      expect(apiConfig.readAsStringSync(), contains('tenantIdHeader'));
    });
  });
}
