import 'package:flutter/material.dart';

/// Inventory–finance reconciliation domain models (v7.2c).
@immutable
class InventoryFinanceReconciliationDashboard {
  const InventoryFinanceReconciliationDashboard({
    required this.vendorCount,
    required this.purchaseOrderCount,
    required this.draftPurchaseOrders,
    required this.openApCommitments,
    required this.openApAmount,
    required this.postedFinancePostings,
    required this.goodsReceiptCount,
    required this.inventoryValue,
  });

  final int vendorCount;
  final int purchaseOrderCount;
  final int draftPurchaseOrders;
  final int openApCommitments;
  final String openApAmount;
  final int postedFinancePostings;
  final int goodsReceiptCount;
  final String inventoryValue;
}

@immutable
class InventoryFinanceTimelineEntry {
  const InventoryFinanceTimelineEntry({
    required this.id,
    required this.eventType,
    required this.entityType,
    required this.entityId,
    required this.label,
    required this.amount,
    required this.occurredAt,
    required this.referenceId,
  });

  final String id;
  final String eventType;
  final String entityType;
  final String entityId;
  final String label;
  final String? amount;
  final DateTime occurredAt;
  final String? referenceId;

  String get eventLabel => switch (eventType) {
        'purchase_order_created' => 'PO created',
        'purchase_order_approved' => 'PO approved',
        'goods_received' => 'Goods received',
        'finance_posting' => 'Finance posting',
        _ => eventType,
      };
}

@immutable
class InventoryFinanceGoodsReceiptSummary {
  const InventoryFinanceGoodsReceiptSummary({
    required this.id,
    required this.grnNumber,
    required this.purchaseOrderId,
    required this.poNumber,
    required this.vendorName,
    required this.receivedAt,
    required this.status,
    required this.lineCount,
  });

  final String id;
  final String grnNumber;
  final String purchaseOrderId;
  final String poNumber;
  final String vendorName;
  final DateTime receivedAt;
  final String status;
  final int lineCount;
}

@immutable
class InventoryFinanceGoodsReceiptLine {
  const InventoryFinanceGoodsReceiptLine({
    required this.id,
    required this.sku,
    required this.description,
    required this.quantityReceived,
    required this.unitCost,
  });

  final String id;
  final String sku;
  final String description;
  final int quantityReceived;
  final String unitCost;
}

@immutable
class InventoryFinanceGoodsReceiptDetail {
  const InventoryFinanceGoodsReceiptDetail({
    required this.id,
    required this.grnNumber,
    required this.purchaseOrderId,
    required this.poNumber,
    required this.vendorName,
    required this.receivedAt,
    required this.status,
    required this.lines,
  });

  final String id;
  final String grnNumber;
  final String purchaseOrderId;
  final String poNumber;
  final String vendorName;
  final DateTime receivedAt;
  final String status;
  final List<InventoryFinanceGoodsReceiptLine> lines;
}

@immutable
class InventoryFinancePosting {
  const InventoryFinancePosting({
    required this.id,
    required this.purchaseOrderId,
    required this.poNumber,
    required this.vendorName,
    required this.apCommitmentId,
    required this.commitmentNumber,
    required this.postingStatus,
    required this.amount,
    required this.postedAt,
  });

  final String id;
  final String purchaseOrderId;
  final String poNumber;
  final String vendorName;
  final String apCommitmentId;
  final String commitmentNumber;
  final String postingStatus;
  final String amount;
  final DateTime? postedAt;
}

@immutable
class InventoryFinanceVendor {
  const InventoryFinanceVendor({
    required this.id,
    required this.vendorCode,
    required this.displayName,
    required this.contactPhone,
    required this.contactEmail,
    required this.gstin,
    required this.status,
  });

  final String id;
  final String vendorCode;
  final String displayName;
  final String? contactPhone;
  final String? contactEmail;
  final String? gstin;
  final String status;
}

@immutable
class InventoryFinancePurchaseOrderLine {
  const InventoryFinancePurchaseOrderLine({
    required this.id,
    required this.sku,
    required this.description,
    required this.quantity,
    required this.unitCost,
    required this.lineTotal,
    required this.quantityReceived,
  });

  final String id;
  final String sku;
  final String description;
  final int quantity;
  final String unitCost;
  final String lineTotal;
  final int quantityReceived;

  int get quantityPending => quantity - quantityReceived;
}

@immutable
class InventoryFinancePurchaseOrder {
  const InventoryFinancePurchaseOrder({
    required this.id,
    required this.poNumber,
    required this.vendorId,
    required this.status,
    required this.totalAmount,
    required this.currency,
    required this.createdAt,
    required this.lines,
  });

  final String id;
  final String poNumber;
  final String vendorId;
  final String status;
  final String totalAmount;
  final String currency;
  final DateTime createdAt;
  final List<InventoryFinancePurchaseOrderLine> lines;
}

@immutable
class InventoryFinanceVendorTransaction {
  const InventoryFinanceVendorTransaction({
    required this.id,
    required this.transactionType,
    required this.referenceNumber,
    required this.amount,
    required this.status,
    required this.occurredAt,
  });

  final String id;
  final String transactionType;
  final String referenceNumber;
  final String amount;
  final String status;
  final DateTime occurredAt;

  String get typeLabel => switch (transactionType) {
        'purchase_order' => 'Purchase order',
        'ap_commitment' => 'AP commitment',
        _ => transactionType,
      };
}

@immutable
class InventoryFinanceApproveResult {
  const InventoryFinanceApproveResult({
    required this.purchaseOrder,
    required this.apCommitmentId,
    required this.financePostingId,
  });

  final InventoryFinancePurchaseOrder purchaseOrder;
  final String apCommitmentId;
  final String financePostingId;
}

@immutable
class InventoryFinanceReceiveResult {
  const InventoryFinanceReceiveResult({
    required this.grnId,
    required this.grnNumber,
  });

  final String grnId;
  final String grnNumber;
}

@immutable
class InventoryFinanceStockValuation {
  const InventoryFinanceStockValuation({
    required this.sku,
    required this.quantityOnHand,
    required this.weightedAvgCost,
    required this.inventoryValue,
  });

  final String sku;
  final int quantityOnHand;
  final String weightedAvgCost;
  final String inventoryValue;
}

String formatInventoryFinancePaise(int paise) {
  final rupees = paise / 100;
  return '₹${rupees.toStringAsFixed(2)}';
}

// ── INV-1..7 — Store STOCK module domain models ──
//
// The stock module (issue slips, manual adjustments with maker-checker,
// physical counts, consumable registry, low-stock, and the immutable stock
// register) mirrors the backend
// `supabase/functions/_shared/inventory_finance/inventory_stock_*` contract.

/// Value-reducing adjustment states. `pending` write-offs await a *different*
/// user's approval (separation of duties); `approved` decremented stock,
/// `rejected` did not.
enum StockAdjustmentStatus { pending, approved, rejected, applied }

StockAdjustmentStatus stockAdjustmentStatusFromWire(String? wire) =>
    switch (wire) {
      'approved' => StockAdjustmentStatus.approved,
      'rejected' => StockAdjustmentStatus.rejected,
      'applied' => StockAdjustmentStatus.applied,
      _ => StockAdjustmentStatus.pending,
    };

/// INV-2 item classification.
enum StockItemType { asset, consumable }

StockItemType stockItemTypeFromWire(String? wire) =>
    wire == 'asset' ? StockItemType.asset : StockItemType.consumable;

String stockItemTypeToWire(StockItemType type) =>
    type == StockItemType.asset ? 'asset' : 'consumable';

/// INV-1 — the result of posting an issue slip.
@immutable
class StockIssue {
  const StockIssue({
    required this.issueId,
    required this.issueNumber,
    required this.posted,
    required this.movementIds,
    required this.lowStockCount,
  });

  final String issueId;
  final String issueNumber;
  final bool posted;
  final List<String> movementIds;

  /// SKUs that dropped to/below their reorder level as a result of this issue.
  final int lowStockCount;
}

/// INV-3 — the result of a manual adjustment. `adjust_in`/`opening` apply
/// immediately ([applied] true); `adjust_out` (value-reducing) returns a
/// [StockAdjustmentStatus.pending] adjustment that a different user must approve.
@immutable
class StockAdjustmentResult {
  const StockAdjustmentResult({
    required this.applied,
    required this.movementId,
    required this.adjustmentId,
    required this.qtyBefore,
    required this.qtyAfter,
    required this.status,
  });

  final bool applied;
  final String? movementId;
  final String? adjustmentId;
  final int qtyBefore;
  final int qtyAfter;
  final StockAdjustmentStatus status;

  bool get isPending => status == StockAdjustmentStatus.pending;
}

/// A value-reducing stock adjustment awaiting (or having received) a checker
/// decision. Carries [makerId] (who raised it) and [checkerId] (who decided) so
/// the UI can enforce/surface the self-approve rule.
@immutable
class StockAdjustment {
  const StockAdjustment({
    required this.id,
    required this.sku,
    required this.qty,
    required this.movementType,
    required this.reason,
    required this.status,
    required this.referenceType,
    required this.referenceId,
    required this.makerId,
    required this.checkerId,
    required this.decisionComment,
    required this.createdAt,
  });

  final String id;
  final String sku;
  final int qty;
  final String movementType;
  final String reason;
  final StockAdjustmentStatus status;
  final String? referenceType;
  final String? referenceId;
  final String? makerId;
  final String? checkerId;
  final String? decisionComment;
  final DateTime createdAt;

  String get sourceLabel => switch (referenceType) {
        'stock_count_session' => 'Stock count',
        'manual_adjustment' => 'Manual write-off',
        _ => referenceType ?? 'Adjustment',
      };
}

/// The outcome of an approve/reject decision on a pending adjustment.
@immutable
class StockAdjustmentDecision {
  const StockAdjustmentDecision({
    required this.adjustmentId,
    required this.sku,
    required this.status,
    required this.movementId,
    required this.qtyBefore,
    required this.qtyAfter,
  });

  final String adjustmentId;
  final String sku;
  final StockAdjustmentStatus status;
  final String? movementId;
  final int qtyBefore;
  final int qtyAfter;
}

/// INV-6 — one line of a physical count result: variance vs. system.
@immutable
class StockCountLineResult {
  const StockCountLineResult({
    required this.sku,
    required this.countedQty,
    required this.systemQty,
    required this.variance,
    required this.outcome,
    required this.movementId,
    required this.adjustmentId,
  });

  final String sku;
  final int countedQty;
  final int systemQty;
  final int variance;

  /// `no_change` · `applied_in` (positive variance applied) · `pending_adjustment`
  /// (negative variance queued for maker-checker).
  final String outcome;
  final String? movementId;
  final String? adjustmentId;

  bool get isPendingAdjustment => outcome == 'pending_adjustment';
}

/// INV-6 — the result of posting a stock-count session.
@immutable
class StockCountResult {
  const StockCountResult({
    required this.sessionId,
    required this.sessionNumber,
    required this.posted,
    required this.lines,
  });

  final String sessionId;
  final String sessionNumber;
  final bool posted;
  final List<StockCountLineResult> lines;

  int get pendingAdjustmentCount =>
      lines.where((l) => l.isPendingAdjustment).length;
}

/// INV-2 — a consumable/asset stock item + its reorder level.
@immutable
class StockItem {
  const StockItem({
    required this.sku,
    required this.itemName,
    required this.itemType,
    required this.reorderLevel,
    required this.quantityOnHand,
    required this.weightedAvgCost,
  });

  final String sku;
  final String? itemName;
  final StockItemType itemType;
  final int reorderLevel;
  final int quantityOnHand;
  final String weightedAvgCost;

  bool get isBelowReorder =>
      reorderLevel > 0 && quantityOnHand < reorderLevel;
}

/// INV-4 — a SKU at/below its reorder level. Carries the recommended top-up
/// quantity and a default vendor so the client can raise a PO against the
/// existing procurement endpoint.
@immutable
class LowStockRow {
  const LowStockRow({
    required this.sku,
    required this.itemName,
    required this.quantityOnHand,
    required this.reorderLevel,
    required this.recommendedQuantity,
    required this.vendorId,
  });

  final String sku;
  final String itemName;
  final int quantityOnHand;
  final int reorderLevel;
  final int recommendedQuantity;
  final String? vendorId;
}

/// INV-5 — one immutable row of the stock register (ledger).
@immutable
class StockRegisterRow {
  const StockRegisterRow({
    required this.id,
    required this.sku,
    required this.movementType,
    required this.quantityDelta,
    required this.qtyBefore,
    required this.qtyAfter,
    required this.reason,
    required this.referenceType,
    required this.referenceId,
    required this.createdBy,
    required this.createdAt,
  });

  final String id;
  final String sku;
  final String movementType;
  final int quantityDelta;
  final int qtyBefore;
  final int qtyAfter;
  final String reason;
  final String? referenceType;
  final String? referenceId;
  final String? createdBy;
  final DateTime createdAt;

  String get movementLabel => switch (movementType) {
        'grn' => 'Goods receipt',
        'issue' => 'Issue',
        'adjust_in' => 'Adjust in',
        'adjust_out' => 'Adjust out',
        'count_variance' => 'Count variance',
        'opening' => 'Opening',
        _ => movementType,
      };
}
