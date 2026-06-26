import 'package:akshara_erp/core/errors/api_failure.dart';
import 'package:akshara_erp/core/security/erp_role.dart';
import 'package:akshara_erp/core/security/rbac_service.dart';
import 'package:akshara_erp/core/security/user_permissions.dart';
import 'package:akshara_erp/features/inventory/inventory_mutations_provider.dart';
import 'package:akshara_erp/features/inventory/inventory_requests.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/provider_test_overrides.dart';

void main() {
  setUpAll(() async {
    await initProviderTestPrefs();
  });

  group('P1-INV-008 inventory procurement RBAC', () {
    test('storekeeper can create PO but cannot receive goods', () async {
      final container = ProviderContainer(
        overrides: [
          ...providerTestOverrides(),
          userPermissionsProvider.overrideWithValue(
            UserPermissions.forRole(ErpRole.storekeeper),
          ),
        ],
      );
      addTearDown(container.dispose);

      final created = await container
          .read(createProcurementOrderProvider.notifier)
          .execute(
            const CreateInventoryProcurementOrderRequest(
              vendorId: 'vendor_if_1',
              vendorName: 'Vendor A',
              items: 'Notebooks',
              totalAmount: '25000',
              requestedBy: 'Storekeeper',
              expectedDelivery: '20 Jun 2026',
            ),
          );
      expect(created, isNotNull);

      await container
          .read(receiveProcurementHandoffProvider.notifier)
          .execute(created!);

      expect(container.read(receiveProcurementHandoffProvider).hasError, isTrue);
      final error = container.read(receiveProcurementHandoffProvider).error;
      expect(error, isA<ApiFailureException>());
    });
  });
}
