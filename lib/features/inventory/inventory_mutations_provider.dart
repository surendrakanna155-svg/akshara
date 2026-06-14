import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/errors/api_failure.dart';
import '../../core/errors/api_failure_mapper.dart';
import '../../core/repositories/repository_providers.dart';
import '../../core/security/permissions.dart';
import '../../core/security/rbac_service.dart';
import '../../core/tenant/tenant_provider.dart';
import '../finance/inventory_finance/inventory_finance_models.dart';
import '../finance/inventory_finance/inventory_finance_requests.dart';
import '../finance/reconciliation/inventory_finance_mutations_provider.dart';
import 'inventory_models.dart';
import 'inventory_providers.dart';
import 'inventory_requests.dart';
import 'intelligence/inventory_intelligence_models.dart';
import 'intelligence/inventory_intelligence_provider.dart';

void assertManageInventory(Ref ref) {
  final perms = ref.read(userPermissionsProvider);
  if (perms == null || !perms.has(Permission.manageInventory)) {
    throw ApiFailureException(
      const ApiFailure(
        type: ApiFailureType.forbidden,
        message: 'You do not have permission to manage inventory.',
        code: 'RBAC_MANAGE_INVENTORY',
      ),
    );
  }
}

class CreateProcurementOrderNotifier
    extends AsyncNotifier<InventoryProcurementOrder?> {
  @override
  FutureOr<InventoryProcurementOrder?> build() => null;

  Future<InventoryProcurementOrder?> execute(
    CreateInventoryProcurementOrderRequest request,
  ) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      assertManageInventory(ref);
      try {
        final result =
            await ref.read(inventoryRepositoryProvider).createProcurementOrder(
                  query: ref.read(repositoryQueryProvider),
                  request: request,
                );
        ref.invalidate(inventoryProcurementFutureProvider);
        return result;
      } catch (error) {
        throw ApiFailureException(apiFailureMapper.fromException(error));
      }
    });
    return state.valueOrNull;
  }
}

final createProcurementOrderProvider = AsyncNotifierProvider<
    CreateProcurementOrderNotifier, InventoryProcurementOrder?>(
  CreateProcurementOrderNotifier.new,
);

class RecordAssetLifecycleEventNotifier
    extends AsyncNotifier<AssetLifecycleEvent?> {
  @override
  FutureOr<AssetLifecycleEvent?> build() => null;

  Future<AssetLifecycleEvent?> execute(
    RecordAssetLifecycleEventRequest request,
  ) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      assertManageInventory(ref);
      try {
        final result = await ref
            .read(inventoryRepositoryProvider)
            .recordAssetLifecycleEvent(
              query: ref.read(repositoryQueryProvider),
              request: request,
            );
        ref.invalidate(assetLifecycleProvider);
        return result;
      } catch (error) {
        throw ApiFailureException(apiFailureMapper.fromException(error));
      }
    });
    return state.valueOrNull;
  }
}

final recordAssetLifecycleEventProvider = AsyncNotifierProvider<
    RecordAssetLifecycleEventNotifier, AssetLifecycleEvent?>(
  RecordAssetLifecycleEventNotifier.new,
);

class ReceiveProcurementHandoffNotifier
    extends AsyncNotifier<InventoryFinanceReceiveResult?> {
  @override
  FutureOr<InventoryFinanceReceiveResult?> build() => null;

  Future<InventoryFinanceReceiveResult> execute(
    InventoryProcurementOrder order,
  ) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      assertManageInventory(ref);
      try {
        final purchaseOrderId =
            order.financePoId.isNotEmpty ? order.financePoId : order.id;
        final financeResult = await ref
            .read(inventoryFinanceReceiveGoodsProvider.notifier)
            .receive(
              purchaseOrderId: purchaseOrderId,
              request: const ReceiveInventoryGoodsRequest(
                lines: [
                  ReceiveInventoryGoodsLineRequest(
                    purchaseOrderLineId: 'pilot_line',
                    quantityReceived: 1,
                  ),
                ],
              ),
            );
        await ref.read(inventoryRepositoryProvider).recordProcurementReceiveHandoff(
              query: ref.read(repositoryQueryProvider),
              orderId: order.id,
            );
        ref.invalidate(inventoryProcurementFutureProvider);
        return financeResult;
      } catch (error) {
        throw ApiFailureException(apiFailureMapper.fromException(error));
      }
    });
    return state.value!;
  }
}

final receiveProcurementHandoffProvider = AsyncNotifierProvider<
    ReceiveProcurementHandoffNotifier, InventoryFinanceReceiveResult?>(
  ReceiveProcurementHandoffNotifier.new,
);
