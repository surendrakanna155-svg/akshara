import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/approvals/adapters/inventory_po_approval_adapter.dart';
import '../../core/inventory/inventory_po_governance_store.dart';
import '../../core/config/inventory_po_approval_config.dart';
import '../../core/errors/api_failure.dart';
import '../../core/errors/api_failure_mapper.dart';
import '../../core/repositories/repository_providers.dart';
import '../../core/security/permissions.dart';
import '../../core/security/rbac_service.dart';
import '../../core/tenant/tenant_provider.dart';
import '../../features/auth/auth_provider.dart';
import '../finance/inventory_finance/inventory_finance_models.dart';
import '../finance/inventory_finance/inventory_finance_requests.dart';
import '../finance/reconciliation/inventory_finance_mutations_provider.dart';
import 'inventory_models.dart';
import 'inventory_providers.dart';
import 'inventory_requests.dart';
import 'intelligence/inventory_intelligence_models.dart';
import 'intelligence/inventory_intelligence_provider.dart';
import '../../core/errors/mutation_in_progress.dart';

void assertCreateInventoryPo(Ref ref) {
  final perms = ref.read(userPermissionsProvider);
  if (perms == null ||
      (!perms.has(Permission.createInventoryPo) &&
          !perms.has(Permission.manageInventory) &&
          !perms.has(Permission.manageProcurementWorkflow))) {
    throw ApiFailureException(
      const ApiFailure(
        type: ApiFailureType.forbidden,
        message: 'You do not have permission to create purchase orders.',
        code: 'RBAC_CREATE_INVENTORY_PO',
      ),
    );
  }
}

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

void assertApprovePurchaseOrder(Ref ref) {
  final perms = ref.read(userPermissionsProvider);
  if (perms == null ||
      (!perms.has(Permission.approvePurchaseOrder) &&
          !perms.has(Permission.manageInventory) &&
          !perms.has(Permission.manageProcurementWorkflow))) {
    throw ApiFailureException(
      const ApiFailure(
        type: ApiFailureType.forbidden,
        message: 'You do not have permission to approve purchase orders.',
        code: 'RBAC_APPROVE_PURCHASE_ORDER',
      ),
    );
  }
}

void assertAssetLifecycle(Ref ref) {
  final perms = ref.read(userPermissionsProvider);
  if (perms == null ||
      (!perms.has(Permission.manageAssetLifecycle) &&
          !perms.has(Permission.manageInventory))) {
    throw ApiFailureException(
      const ApiFailure(
        type: ApiFailureType.forbidden,
        message: 'You do not have permission to record asset lifecycle events.',
        code: 'RBAC_MANAGE_ASSET_LIFECYCLE',
      ),
    );
  }
}

void assertProcurementWorkflow(Ref ref) {
  final perms = ref.read(userPermissionsProvider);
  if (perms == null ||
      (!perms.has(Permission.manageProcurementWorkflow) &&
          !perms.has(Permission.manageInventory))) {
    throw ApiFailureException(
      const ApiFailure(
        type: ApiFailureType.forbidden,
        message: 'You do not have permission to receive procurement goods.',
        code: 'RBAC_MANAGE_PROCUREMENT_WORKFLOW',
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
    if (state.isLoading) return state.valueOrNull;
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      assertCreateInventoryPo(ref);
      final vendorId = request.vendorId?.trim() ?? '';
      if (vendorId.isEmpty) {
        throw ApiFailureException(
          const ApiFailure(
            type: ApiFailureType.unknown,
            message: 'Select a vendor before creating a purchase order.',
            code: 'INVENTORY_PO_VENDOR_REQUIRED',
          ),
        );
      }
      try {
        final query = ref.read(repositoryQueryProvider);
        final financePo = await ref
            .read(inventoryFinanceRepositoryProvider)
            .createPurchaseOrder(
              query: query,
              request: CreateInventoryPurchaseOrderRequest(
                vendorId: vendorId,
                poNumber:
                    request.poNumber ?? _draftPoNumber(DateTime.now()),
                lines: [
                  CreateInventoryPurchaseOrderLineRequest(
                    sku: 'INV-PROC',
                    description: request.items,
                    quantity: 1,
                    unitCostPaise: _parseAmountToPaise(request.totalAmount),
                  ),
                ],
                notes: request.vendorName,
              ),
            );
        final result =
            await ref.read(inventoryRepositoryProvider).createProcurementOrder(
                  query: query,
                  request: CreateInventoryProcurementOrderRequest(
                    vendorName: request.vendorName,
                    items: request.items,
                    totalAmount: request.totalAmount,
                    requestedBy: request.requestedBy,
                    expectedDelivery: request.expectedDelivery,
                    financePoId: financePo.id,
                    poNumber: financePo.poNumber,
                  ),
                );
        ref.invalidate(inventoryProcurementFutureProvider);

        if (ref.read(inventoryPoApprovalRequiredProvider)) {
          final auth = ref.read(authProvider);
          final adapter = InventoryPoApprovalAdapter();
          await adapter.submitForApproval(
            service: ref.read(approvalCenterServiceProvider),
            query: query,
            orderId: result.id,
            requesterId: auth.claims?.userId ?? 'storekeeper_demo',
            requesterName: auth.displayName ?? request.requestedBy,
            title: 'Approve PO — ${result.poNumber}',
            summary:
                '${result.vendorName} · ${result.totalAmount} · ${result.items}',
            payload: {
              'poNumber': result.poNumber,
              'vendorName': result.vendorName,
              'totalAmount': result.totalAmount,
              'requestedBy': request.requestedBy,
            },
          );
        }

        return result;
      } catch (error) {
        throw ApiFailureException(apiFailureMapper.fromException(error));
      }
    });
    return state.valueOrNull;
  }
}

String _draftPoNumber(DateTime now) {
  final suffix = (now.millisecondsSinceEpoch % 10000).toString().padLeft(4, '0');
  return 'PO-2026-$suffix';
}

int _parseAmountToPaise(String amount) {
  final digits = amount.replaceAll(RegExp(r'[^\d]'), '');
  final rupees = int.tryParse(digits) ?? 25000;
  return rupees * 100;
}

final createProcurementOrderProvider = AsyncNotifierProvider<
    CreateProcurementOrderNotifier, InventoryProcurementOrder?>(
  CreateProcurementOrderNotifier.new,
);

class ApproveProcurementHandoffNotifier
    extends AsyncNotifier<InventoryFinanceApproveResult?> {
  @override
  FutureOr<InventoryFinanceApproveResult?> build() => null;

  Future<InventoryFinanceApproveResult> execute(
    InventoryProcurementOrder order,
  ) async {
    if (state.isLoading) throw mutationInProgressFailure();
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      assertApprovePurchaseOrder(ref);
      if (ref.read(inventoryPoApprovalRequiredProvider) &&
          !InventoryPoGovernanceStore.instance.isApproved(order.id)) {
        throw ApiFailureException(
          const ApiFailure(
            type: ApiFailureType.forbidden,
            message:
                'Purchase order requires principal approval in the Approval Center.',
            code: 'PO_APPROVAL_REQUIRED',
          ),
        );
      }
      try {
        final query = ref.read(repositoryQueryProvider);
        final financeResult = await ref
            .read(inventoryFinanceApprovePurchaseOrderProvider.notifier)
            .approve(order.financePoId);
        await ref.read(inventoryRepositoryProvider).approveProcurementOrder(
              query: query,
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

final approveProcurementHandoffProvider = AsyncNotifierProvider<
    ApproveProcurementHandoffNotifier, InventoryFinanceApproveResult?>(
  ApproveProcurementHandoffNotifier.new,
);

class RecordAssetLifecycleEventNotifier
    extends AsyncNotifier<AssetLifecycleEvent?> {
  @override
  FutureOr<AssetLifecycleEvent?> build() => null;

  Future<AssetLifecycleEvent?> execute(
    RecordAssetLifecycleEventRequest request,
  ) async {
    if (state.isLoading) return state.valueOrNull;
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      assertAssetLifecycle(ref);
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

  Future<InventoryFinanceReceiveResult?> execute(
    InventoryProcurementOrder order,
  ) async {
    if (state.isLoading) return state.valueOrNull;
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      assertProcurementWorkflow(ref);
      try {
        final query = ref.read(repositoryQueryProvider);
        final financeOrder =
            await ref.read(inventoryFinanceRepositoryProvider).getPurchaseOrder(
                  query: query,
                  purchaseOrderId: order.financePoId,
                );
        if (financeOrder == null) {
          throw StateError('Finance PO not found: ${order.financePoId}');
        }
        final receiveLines = [
          for (final line in financeOrder.lines)
            ReceiveInventoryGoodsLineRequest(
              purchaseOrderLineId: line.id,
              quantityReceived: line.quantityPending > 0
                  ? line.quantityPending
                  : line.quantity,
            ),
        ];
        if (receiveLines.isEmpty) {
          throw StateError('Finance PO has no lines: ${financeOrder.id}');
        }
        final financeResult = await ref
            .read(inventoryFinanceReceiveGoodsProvider.notifier)
            .receive(
              purchaseOrderId: financeOrder.id,
              request: ReceiveInventoryGoodsRequest(
                lines: receiveLines,
              ),
            );
        await ref
            .read(inventoryRepositoryProvider)
            .recordProcurementReceiveHandoff(
              query: query,
              orderId: order.id,
            );
        ref.invalidate(inventoryProcurementFutureProvider);
        return financeResult;
      } catch (error) {
        throw ApiFailureException(apiFailureMapper.fromException(error));
      }
    });
    return state.valueOrNull;
  }
}

final receiveProcurementHandoffProvider = AsyncNotifierProvider<
    ReceiveProcurementHandoffNotifier, InventoryFinanceReceiveResult?>(
  ReceiveProcurementHandoffNotifier.new,
);
