import 'package:akshara_erp/features/finance/inventory_finance/inventory_finance_models.dart';

class InventoryFinanceFixtureBuilder {
  Map<String, dynamic> envelope(Map<String, dynamic> data) {
    return {
      'success': true,
      'data': data,
    };
  }

  Map<String, dynamic> dashboardEnvelope(
    InventoryFinanceReconciliationDashboard dashboard,
  ) {
    return envelope({
      'vendorCount': dashboard.vendorCount,
      'purchaseOrderCount': dashboard.purchaseOrderCount,
      'draftPurchaseOrders': dashboard.draftPurchaseOrders,
      'openApCommitments': dashboard.openApCommitments,
      'openApAmount': _paiseFromDisplay(dashboard.openApAmount),
      'postedFinancePostings': dashboard.postedFinancePostings,
      'goodsReceiptCount': dashboard.goodsReceiptCount,
      'inventoryValue': _paiseFromDisplay(dashboard.inventoryValue),
    });
  }

  List<Map<String, dynamic>> timelineItems(
    List<InventoryFinanceTimelineEntry> entries,
  ) {
    return [
      for (final entry in entries)
        {
          'id': entry.id,
          'eventType': entry.eventType,
          'entityType': entry.entityType,
          'entityId': entry.entityId,
          'label': entry.label,
          'amount': entry.amount == null ? null : _paiseFromDisplay(entry.amount!),
          'occurredAt': entry.occurredAt.toIso8601String(),
          'referenceId': entry.referenceId,
        },
    ];
  }

  Map<String, dynamic> goodsReceiptSummaryItem(
    InventoryFinanceGoodsReceiptSummary item,
  ) {
    return {
      'id': item.id,
      'grnNumber': item.grnNumber,
      'purchaseOrderId': item.purchaseOrderId,
      'poNumber': item.poNumber,
      'vendorName': item.vendorName,
      'receivedAt': item.receivedAt.toIso8601String(),
      'status': item.status,
      'lineCount': item.lineCount,
    };
  }

  Map<String, dynamic> postingItem(InventoryFinancePosting item) {
    return {
      'id': item.id,
      'purchaseOrderId': item.purchaseOrderId,
      'poNumber': item.poNumber,
      'vendorName': item.vendorName,
      'apCommitmentId': item.apCommitmentId,
      'commitmentNumber': item.commitmentNumber,
      'postingStatus': item.postingStatus,
      'amount': _paiseFromDisplay(item.amount),
      'postedAt': item.postedAt?.toIso8601String(),
    };
  }

  Map<String, dynamic> vendorTransactionItem(
    InventoryFinanceVendorTransaction item,
  ) {
    return {
      'id': item.id,
      'transactionType': item.transactionType,
      'referenceNumber': item.referenceNumber,
      'amount': _paiseFromDisplay(item.amount),
      'status': item.status,
      'occurredAt': item.occurredAt.toIso8601String(),
    };
  }

  int _paiseFromDisplay(String display) {
    final normalized = display.replaceAll(RegExp(r'[^0-9.]'), '');
    return (double.parse(normalized) * 100).round();
  }

  // ── INV-1..7 — Store STOCK module fixtures ──

  Map<String, dynamic> stockIssueEnvelope(StockIssue issue) {
    return envelope({
      'issueId': issue.issueId,
      'issueNumber': issue.issueNumber,
      'posted': issue.posted,
      'movementIds': issue.movementIds,
      'lowStockCount': issue.lowStockCount,
    });
  }

  Map<String, dynamic> stockAdjustmentResultEnvelope(
    StockAdjustmentResult result,
  ) {
    return envelope({
      'applied': result.applied,
      'movementId': result.movementId,
      'adjustmentId': result.adjustmentId,
      'qtyBefore': result.qtyBefore,
      'qtyAfter': result.qtyAfter,
      'status': result.status == StockAdjustmentStatus.applied
          ? 'applied'
          : 'pending',
    });
  }

  Map<String, dynamic> stockAdjustmentItem(StockAdjustment adj) {
    return {
      'id': adj.id,
      'sku': adj.sku,
      'qty': adj.qty,
      'movement_type': adj.movementType,
      'reason': adj.reason,
      'status': switch (adj.status) {
        StockAdjustmentStatus.approved => 'approved',
        StockAdjustmentStatus.rejected => 'rejected',
        StockAdjustmentStatus.applied => 'applied',
        StockAdjustmentStatus.pending => 'pending',
      },
      'reference_type': adj.referenceType,
      'reference_id': adj.referenceId,
      'maker_id': adj.makerId,
      'checker_id': adj.checkerId,
      'decision_comment': adj.decisionComment,
      'created_at': adj.createdAt.toIso8601String(),
    };
  }

  Map<String, dynamic> stockItemItem(StockItem item) {
    return {
      'sku': item.sku,
      'item_name': item.itemName,
      'item_type': stockItemTypeToWire(item.itemType),
      'reorder_level': item.reorderLevel,
      'quantity_on_hand': item.quantityOnHand,
      'weighted_avg_cost': _paiseFromDisplay(item.weightedAvgCost),
    };
  }

  Map<String, dynamic> lowStockItem(LowStockRow row) {
    return {
      'sku': row.sku,
      'itemName': row.itemName,
      'quantityOnHand': row.quantityOnHand,
      'reorderLevel': row.reorderLevel,
      'recommendedQuantity': row.recommendedQuantity,
      'vendorId': row.vendorId,
    };
  }

  Map<String, dynamic> stockRegisterItem(StockRegisterRow row) {
    return {
      'id': row.id,
      'sku': row.sku,
      'movementType': row.movementType,
      'quantityDelta': row.quantityDelta,
      'qtyBefore': row.qtyBefore,
      'qtyAfter': row.qtyAfter,
      'reason': row.reason,
      'referenceType': row.referenceType,
      'referenceId': row.referenceId,
      'createdBy': row.createdBy,
      'createdAt': row.createdAt.toIso8601String(),
    };
  }
}
