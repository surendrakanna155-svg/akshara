import 'package:akshara_erp/core/repositories/mock/mock_transport_repository.dart';
import 'package:akshara_erp/core/repositories/repository_query.dart';
import 'package:akshara_erp/core/security/erp_role.dart';
import 'package:akshara_erp/core/security/rbac_service.dart';
import 'package:akshara_erp/core/security/user_permissions.dart';
import 'package:akshara_erp/features/transport/transport_models.dart';
import 'package:akshara_erp/features/transport/transport_mutations_provider.dart';
import 'package:akshara_erp/features/transport/transport_requests.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/provider_test_overrides.dart';

void main() {
  setUpAll(() async {
    await initProviderTestPrefs();
  });

  group('Transport mock writes', () {
    const query = RepositoryQuery.demo;

    test('createRoute inserts draft route', () async {
      final repo = MockTransportRepository();
      final before = await repo.getRoutes(query: query);

      final route = await repo.createRoute(
        query: query,
        request: const CreateTransportRouteRequest(name: 'QA Route North'),
      );

      final after = await repo.getRoutes(query: query);
      expect(after.total, greaterThan(before.total));
      expect(route.status, TransportRouteStatus.draft);
      expect(route.name, 'QA Route North');
    });

    test('activateRoute changes draft to active', () async {
      final repo = MockTransportRepository();
      final created = await repo.createRoute(
        query: query,
        request: const CreateTransportRouteRequest(name: 'QA Activate Route'),
      );

      final activated = await repo.activateRoute(
        query: query,
        request: ActivateTransportRouteRequest(routeId: created.id),
      );

      expect(activated.status, TransportRouteStatus.active);
    });
  });

  group('Transport RBAC mutations', () {
    test('createTransportRoute fails without manageTransport', () async {
      final container = ProviderContainer(
        overrides: [
          ...providerTestOverrides(),
          userPermissionsProvider.overrideWithValue(
            UserPermissions.forRole(ErpRole.principal),
          ),
        ],
      );
      addTearDown(container.dispose);

      await container.read(createTransportRouteProvider.notifier).execute(
            const CreateTransportRouteRequest(name: 'Denied'),
          );

      expect(container.read(createTransportRouteProvider).hasError, isTrue);
    });

    test('activateTransportRoute fails without manageTransport', () async {
      final container = ProviderContainer(
        overrides: [
          ...providerTestOverrides(),
          userPermissionsProvider.overrideWithValue(
            UserPermissions.forRole(ErpRole.principal),
          ),
        ],
      );
      addTearDown(container.dispose);

      await container.read(activateTransportRouteProvider.notifier).execute(
            const ActivateTransportRouteRequest(routeId: 'route_1'),
          );

      expect(container.read(activateTransportRouteProvider).hasError, isTrue);
    });
  });
}
