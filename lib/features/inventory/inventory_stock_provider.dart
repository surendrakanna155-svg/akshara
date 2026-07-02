import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/errors/api_failure.dart';
import '../../core/errors/api_failure_mapper.dart';
import '../../core/errors/mutation_in_progress.dart';
import '../../core/repositories/mock/mock_inventory_finance_repository.dart';
import '../../core/repositories/repository_providers.dart';
import '../../core/tenant/tenant_provider.dart';
import '../auth/auth_provider.dart';
import '../finance/inventory_finance/inventory_finance_models.dart';
import '../finance/inventory_finance/inventory_finance_requests.dart';
import 'inventory_mutations_provider.dart';

/// The acting user id for stock writes (maker/checker identity). Sourced from
/// [authProvider]; the mock repository uses it to enforce the self-approve 409.
String _actingUserId(Ref ref) =>
    ref.read(authProvider).claims?.userId ?? 'store_demo';

/// Threads the acting user through the mock so maker-checker separation of
/// duties is enforced client-side (the live backend derives it from the JWT).
void _bindActingUser(Ref ref) {
  final repo = ref.read(inventoryFinanceRepositoryProvider);
  if (repo is MockInventoryFinanceRepository) {
    repo.currentUserId = _actingUserId(ref);
  }
}

// ── Read providers ──

/// INV-4 — low-stock rows (each carries recommendedQuantity + vendorId for PO).
final inventoryLowStockFutureProvider =
    FutureProvider<List<LowStockRow>>((ref) async {
  return ref
      .read(inventoryFinanceRepositoryProvider)
      .listLowStock(query: ref.watch(repositoryQueryProvider));
});

/// Maker-checker — pending value-reducing adjustments awaiting a checker.
final inventoryPendingAdjustmentsFutureProvider =
    FutureProvider<List<StockAdjustment>>((ref) async {
  return ref
      .read(inventoryFinanceRepositoryProvider)
      .listPendingAdjustments(query: ref.watch(repositoryQueryProvider));
});

/// INV-2 — the consumable/asset registry (with reorder levels).
final inventoryStockItemsFutureProvider =
    FutureProvider<List<StockItem>>((ref) async {
  return ref
      .read(inventoryFinanceRepositoryProvider)
      .listStockItems(query: ref.watch(repositoryQueryProvider));
});

/// INV-5 — the immutable stock register (ledger).
final inventoryStockRegisterFutureProvider =
    FutureProvider<List<StockRegisterRow>>((ref) async {
  return ref
      .read(inventoryFinanceRepositoryProvider)
      .listStockRegister(query: ref.watch(repositoryQueryProvider));
});

// ── Mutation notifiers ──

/// INV-1 — issue stock (manageInventory-gated; surfaces 422 InsufficientStock).
class IssueStockNotifier extends AsyncNotifier<StockIssue?> {
  @override
  FutureOr<StockIssue?> build() => null;

  Future<StockIssue> execute(IssueStockRequest request) async {
    if (state.isLoading) throw mutationInProgressFailure();
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      assertManageInventory(ref);
      try {
        _bindActingUser(ref);
        final result = await ref
            .read(inventoryFinanceRepositoryProvider)
            .issueStock(query: ref.read(repositoryQueryProvider), request: request);
        ref.invalidate(inventoryStockRegisterFutureProvider);
        ref.invalidate(inventoryLowStockFutureProvider);
        ref.invalidate(inventoryStockItemsFutureProvider);
        return result;
      } catch (error) {
        throw ApiFailureException(apiFailureMapper.fromException(error));
      }
    });
    final err = state.error;
    if (err != null) {
      Error.throwWithStackTrace(err, state.stackTrace ?? StackTrace.current);
    }
    return state.value!;
  }
}

final issueStockProvider =
    AsyncNotifierProvider<IssueStockNotifier, StockIssue?>(
  IssueStockNotifier.new,
);

/// INV-3 — adjust stock (adjust_out goes to maker-checker approval).
class AdjustStockNotifier extends AsyncNotifier<StockAdjustmentResult?> {
  @override
  FutureOr<StockAdjustmentResult?> build() => null;

  Future<StockAdjustmentResult> execute(AdjustStockRequest request) async {
    if (state.isLoading) throw mutationInProgressFailure();
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      assertManageInventory(ref);
      try {
        _bindActingUser(ref);
        final result = await ref
            .read(inventoryFinanceRepositoryProvider)
            .adjustStock(query: ref.read(repositoryQueryProvider), request: request);
        ref.invalidate(inventoryStockRegisterFutureProvider);
        ref.invalidate(inventoryStockItemsFutureProvider);
        ref.invalidate(inventoryLowStockFutureProvider);
        if (result.isPending) {
          ref.invalidate(inventoryPendingAdjustmentsFutureProvider);
        }
        return result;
      } catch (error) {
        throw ApiFailureException(apiFailureMapper.fromException(error));
      }
    });
    final err = state.error;
    if (err != null) {
      Error.throwWithStackTrace(err, state.stackTrace ?? StackTrace.current);
    }
    return state.value!;
  }
}

final adjustStockProvider =
    AsyncNotifierProvider<AdjustStockNotifier, StockAdjustmentResult?>(
  AdjustStockNotifier.new,
);

/// INV-6 — record a physical count (negative variance → pending adjustment).
class RecordStockCountNotifier extends AsyncNotifier<StockCountResult?> {
  @override
  FutureOr<StockCountResult?> build() => null;

  Future<StockCountResult> execute(RecordStockCountRequest request) async {
    if (state.isLoading) throw mutationInProgressFailure();
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      assertManageInventory(ref);
      try {
        _bindActingUser(ref);
        final result = await ref
            .read(inventoryFinanceRepositoryProvider)
            .recordStockCount(
              query: ref.read(repositoryQueryProvider),
              request: request,
            );
        ref.invalidate(inventoryStockRegisterFutureProvider);
        ref.invalidate(inventoryStockItemsFutureProvider);
        ref.invalidate(inventoryLowStockFutureProvider);
        if (result.pendingAdjustmentCount > 0) {
          ref.invalidate(inventoryPendingAdjustmentsFutureProvider);
        }
        return result;
      } catch (error) {
        throw ApiFailureException(apiFailureMapper.fromException(error));
      }
    });
    final err = state.error;
    if (err != null) {
      Error.throwWithStackTrace(err, state.stackTrace ?? StackTrace.current);
    }
    return state.value!;
  }
}

final recordStockCountProvider =
    AsyncNotifierProvider<RecordStockCountNotifier, StockCountResult?>(
  RecordStockCountNotifier.new,
);

/// Maker-checker approve/reject of a pending adjustment. The checker must differ
/// from the maker (surfaces the 409 SELF_APPROVE_DENIED as a friendly error).
class DecideStockAdjustmentNotifier
    extends AsyncNotifier<StockAdjustmentDecision?> {
  @override
  FutureOr<StockAdjustmentDecision?> build() => null;

  Future<StockAdjustmentDecision> approve(String adjustmentId,
      {String? comment}) {
    return _decide(adjustmentId, approve: true, comment: comment);
  }

  Future<StockAdjustmentDecision> reject(String adjustmentId,
      {String? comment}) {
    return _decide(adjustmentId, approve: false, comment: comment);
  }

  Future<StockAdjustmentDecision> _decide(
    String adjustmentId, {
    required bool approve,
    String? comment,
  }) async {
    if (state.isLoading) throw mutationInProgressFailure();
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      assertManageInventory(ref);
      try {
        _bindActingUser(ref);
        final repo = ref.read(inventoryFinanceRepositoryProvider);
        final query = ref.read(repositoryQueryProvider);
        final result = approve
            ? await repo.approveStockAdjustment(
                query: query,
                adjustmentId: adjustmentId,
                comment: comment,
              )
            : await repo.rejectStockAdjustment(
                query: query,
                adjustmentId: adjustmentId,
                comment: comment,
              );
        ref.invalidate(inventoryPendingAdjustmentsFutureProvider);
        ref.invalidate(inventoryStockRegisterFutureProvider);
        ref.invalidate(inventoryStockItemsFutureProvider);
        ref.invalidate(inventoryLowStockFutureProvider);
        return result;
      } catch (error) {
        throw ApiFailureException(apiFailureMapper.fromException(error));
      }
    });
    final err = state.error;
    if (err != null) {
      Error.throwWithStackTrace(err, state.stackTrace ?? StackTrace.current);
    }
    return state.value!;
  }
}

final decideStockAdjustmentProvider = AsyncNotifierProvider<
    DecideStockAdjustmentNotifier, StockAdjustmentDecision?>(
  DecideStockAdjustmentNotifier.new,
);

/// INV-2 — upsert a consumable/asset registry item + reorder level.
class UpsertStockItemNotifier extends AsyncNotifier<StockItem?> {
  @override
  FutureOr<StockItem?> build() => null;

  Future<StockItem> execute(UpsertStockItemRequest request) async {
    if (state.isLoading) throw mutationInProgressFailure();
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      assertManageInventory(ref);
      try {
        final result = await ref
            .read(inventoryFinanceRepositoryProvider)
            .upsertStockItem(
              query: ref.read(repositoryQueryProvider),
              request: request,
            );
        ref.invalidate(inventoryStockItemsFutureProvider);
        ref.invalidate(inventoryLowStockFutureProvider);
        return result;
      } catch (error) {
        throw ApiFailureException(apiFailureMapper.fromException(error));
      }
    });
    final err = state.error;
    if (err != null) {
      Error.throwWithStackTrace(err, state.stackTrace ?? StackTrace.current);
    }
    return state.value!;
  }
}

final upsertStockItemProvider =
    AsyncNotifierProvider<UpsertStockItemNotifier, StockItem?>(
  UpsertStockItemNotifier.new,
);

/// INV-4 — raise a PO for a low-stock recommendation. Reuses the EXISTING
/// createPurchaseOrder endpoint (no new PO logic); the low-stock row supplies
/// sku + recommendedQuantity + vendorId.
class RaisePoFromLowStockNotifier
    extends AsyncNotifier<InventoryFinancePurchaseOrderSummary?> {
  @override
  FutureOr<InventoryFinancePurchaseOrderSummary?> build() => null;

  Future<InventoryFinancePurchaseOrderSummary> execute(LowStockRow row) async {
    if (state.isLoading) throw mutationInProgressFailure();
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      assertCreateInventoryPo(ref);
      final vendorId = row.vendorId?.trim() ?? '';
      if (vendorId.isEmpty) {
        throw ApiFailureException(
          const ApiFailure(
            type: ApiFailureType.unknown,
            message:
                'No default vendor for this item. Add a vendor on a prior PO first.',
            code: 'LOW_STOCK_NO_VENDOR',
          ),
        );
      }
      try {
        final poNumber =
            'PO-${DateTime.now().millisecondsSinceEpoch % 1000000}';
        final result = await ref
            .read(inventoryFinanceRepositoryProvider)
            .createPurchaseOrder(
              query: ref.read(repositoryQueryProvider),
              request: CreateInventoryPurchaseOrderRequest(
                vendorId: vendorId,
                poNumber: poNumber,
                lines: [
                  CreateInventoryPurchaseOrderLineRequest(
                    sku: row.sku,
                    description: row.itemName,
                    quantity: row.recommendedQuantity,
                    unitCostPaise: 0,
                  ),
                ],
              ),
            );
        return result;
      } catch (error) {
        throw ApiFailureException(apiFailureMapper.fromException(error));
      }
    });
    final err = state.error;
    if (err != null) {
      Error.throwWithStackTrace(err, state.stackTrace ?? StackTrace.current);
    }
    return state.value!;
  }
}

final raisePoFromLowStockProvider = AsyncNotifierProvider<
    RaisePoFromLowStockNotifier, InventoryFinancePurchaseOrderSummary?>(
  RaisePoFromLowStockNotifier.new,
);
