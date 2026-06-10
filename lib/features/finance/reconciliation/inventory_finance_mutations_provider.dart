import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/repositories/repository_providers.dart';
import '../../../core/tenant/tenant_provider.dart';
import '../inventory_finance/inventory_finance_models.dart';
import '../inventory_finance/inventory_finance_requests.dart';
import 'finance_reconciliation_provider.dart';

final inventoryFinanceApprovePurchaseOrderProvider =
    AsyncNotifierProvider<InventoryFinanceApproveNotifier, InventoryFinanceApproveResult?>(
  InventoryFinanceApproveNotifier.new,
);

final inventoryFinanceReceiveGoodsProvider =
    AsyncNotifierProvider<InventoryFinanceReceiveGoodsNotifier, InventoryFinanceReceiveResult?>(
  InventoryFinanceReceiveGoodsNotifier.new,
);

class InventoryFinanceApproveNotifier extends AsyncNotifier<InventoryFinanceApproveResult?> {
  @override
  FutureOr<InventoryFinanceApproveResult?> build() => null;

  Future<InventoryFinanceApproveResult> approve(String purchaseOrderId) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final result = await ref.read(inventoryFinanceRepositoryProvider).approvePurchaseOrder(
            query: ref.read(repositoryQueryProvider),
            purchaseOrderId: purchaseOrderId,
          );
      invalidateFinanceReconciliationReads(ref);
      return result;
    });
    return state.value!;
  }
}

class InventoryFinanceReceiveGoodsNotifier extends AsyncNotifier<InventoryFinanceReceiveResult?> {
  @override
  FutureOr<InventoryFinanceReceiveResult?> build() => null;

  Future<InventoryFinanceReceiveResult> receive({
    required String purchaseOrderId,
    required ReceiveInventoryGoodsRequest request,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final result = await ref.read(inventoryFinanceRepositoryProvider).receiveGoods(
            query: ref.read(repositoryQueryProvider),
            purchaseOrderId: purchaseOrderId,
            request: request,
          );
      invalidateFinanceReconciliationReads(ref);
      return result;
    });
    return state.value!;
  }
}
