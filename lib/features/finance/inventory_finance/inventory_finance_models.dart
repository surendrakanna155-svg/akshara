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
