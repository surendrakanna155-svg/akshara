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
}
