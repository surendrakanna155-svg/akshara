import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/api_failure.dart';
import '../../../core/errors/api_failure_mapper.dart';
import '../../../core/repositories/repository_providers.dart';
import '../../../core/security/permissions.dart';
import '../../../core/security/rbac_service.dart';
import '../../../core/tenant/tenant_provider.dart';
import '../../finance/inventory_finance/inventory_finance_models.dart';
import '../../finance/inventory_finance/inventory_finance_requests.dart';

/// Finance vendor catalog (`inventory_vendors`) — the procurement source of
/// truth a purchase order is raised against. Distinct from the seeded inventory
/// vendor *directory* (`inventory_entities`), which is a richer display view.
final inventoryVendorCatalogProvider =
    FutureProvider<List<InventoryFinanceVendor>>((ref) async {
  final result = await ref.read(inventoryFinanceRepositoryProvider).getVendors(
        query: ref.watch(repositoryQueryProvider),
      );
  return result.items;
});

/// Creates a vendor in the finance catalog so it becomes selectable on a PO.
class CreateInventoryVendorNotifier
    extends AsyncNotifier<InventoryFinanceVendor?> {
  @override
  FutureOr<InventoryFinanceVendor?> build() => null;

  Future<InventoryFinanceVendor?> execute(
    CreateInventoryVendorRequest request,
  ) async {
    if (state.isLoading) return state.valueOrNull;
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final perms = ref.read(userPermissionsProvider);
      if (perms == null || !perms.has(Permission.manageInventory)) {
        throw ApiFailureException(
          const ApiFailure(
            type: ApiFailureType.forbidden,
            message: 'You do not have permission to create vendors.',
            code: 'RBAC_MANAGE_INVENTORY',
          ),
        );
      }
      try {
        final vendor =
            await ref.read(inventoryFinanceRepositoryProvider).createVendor(
                  query: ref.read(repositoryQueryProvider),
                  request: request,
                );
        ref.invalidate(inventoryVendorCatalogProvider);
        return vendor;
      } catch (error) {
        throw ApiFailureException(apiFailureMapper.fromException(error));
      }
    });
    return state.valueOrNull;
  }
}

final createInventoryVendorProvider =
    AsyncNotifierProvider<CreateInventoryVendorNotifier, InventoryFinanceVendor?>(
  CreateInventoryVendorNotifier.new,
);
