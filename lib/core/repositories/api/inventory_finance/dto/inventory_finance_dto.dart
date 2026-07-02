import '../../admissions/dto/api_envelope_dto.dart';

class InventoryFinanceDashboardDto {
  InventoryFinanceDashboardDto({
    required this.vendorCount,
    required this.purchaseOrderCount,
    required this.draftPurchaseOrders,
    required this.openApCommitments,
    required this.openApAmount,
    required this.postedFinancePostings,
    required this.goodsReceiptCount,
    required this.inventoryValue,
  });

  factory InventoryFinanceDashboardDto.fromJson(Map<String, dynamic> json) {
    return InventoryFinanceDashboardDto(
      vendorCount: json['vendorCount'] as int? ?? 0,
      purchaseOrderCount: json['purchaseOrderCount'] as int? ?? 0,
      draftPurchaseOrders: json['draftPurchaseOrders'] as int? ?? 0,
      openApCommitments: json['openApCommitments'] as int? ?? 0,
      openApAmount: json['openApAmount'] as int? ?? 0,
      postedFinancePostings: json['postedFinancePostings'] as int? ?? 0,
      goodsReceiptCount: json['goodsReceiptCount'] as int? ?? 0,
      inventoryValue: json['inventoryValue'] as int? ?? 0,
    );
  }

  final int vendorCount;
  final int purchaseOrderCount;
  final int draftPurchaseOrders;
  final int openApCommitments;
  final int openApAmount;
  final int postedFinancePostings;
  final int goodsReceiptCount;
  final int inventoryValue;
}

class InventoryFinanceTimelineItemDto {
  InventoryFinanceTimelineItemDto({
    required this.id,
    required this.eventType,
    required this.entityType,
    required this.entityId,
    required this.label,
    required this.amount,
    required this.occurredAt,
    required this.referenceId,
  });

  factory InventoryFinanceTimelineItemDto.fromJson(Map<String, dynamic> json) {
    return InventoryFinanceTimelineItemDto(
      id: json['id'] as String? ?? '',
      eventType: json['eventType'] as String? ?? '',
      entityType: json['entityType'] as String? ?? '',
      entityId: json['entityId'] as String? ?? '',
      label: json['label'] as String? ?? '',
      amount: json['amount'] as int?,
      occurredAt: json['occurredAt'] as String? ?? '',
      referenceId: json['referenceId'] as String?,
    );
  }

  final String id;
  final String eventType;
  final String entityType;
  final String entityId;
  final String label;
  final int? amount;
  final String occurredAt;
  final String? referenceId;
}

class InventoryFinanceGoodsReceiptSummaryDto {
  InventoryFinanceGoodsReceiptSummaryDto({
    required this.id,
    required this.grnNumber,
    required this.purchaseOrderId,
    required this.poNumber,
    required this.vendorName,
    required this.receivedAt,
    required this.status,
    required this.lineCount,
  });

  factory InventoryFinanceGoodsReceiptSummaryDto.fromJson(
    Map<String, dynamic> json,
  ) {
    return InventoryFinanceGoodsReceiptSummaryDto(
      id: json['id'] as String? ?? '',
      grnNumber: json['grnNumber'] as String? ?? '',
      purchaseOrderId: json['purchaseOrderId'] as String? ?? '',
      poNumber: json['poNumber'] as String? ?? '',
      vendorName: json['vendorName'] as String? ?? '',
      receivedAt: json['receivedAt'] as String? ?? '',
      status: json['status'] as String? ?? '',
      lineCount: json['lineCount'] as int? ?? 0,
    );
  }

  final String id;
  final String grnNumber;
  final String purchaseOrderId;
  final String poNumber;
  final String vendorName;
  final String receivedAt;
  final String status;
  final int lineCount;
}

class InventoryFinanceGoodsReceiptLineDto {
  InventoryFinanceGoodsReceiptLineDto({
    required this.id,
    required this.sku,
    required this.description,
    required this.quantityReceived,
    required this.unitCost,
  });

  factory InventoryFinanceGoodsReceiptLineDto.fromJson(
    Map<String, dynamic> json,
  ) {
    return InventoryFinanceGoodsReceiptLineDto(
      id: json['id'] as String? ?? '',
      sku: json['sku'] as String? ?? '',
      description: json['description'] as String? ?? '',
      quantityReceived: json['quantityReceived'] as int? ?? 0,
      unitCost: json['unitCost'] as int? ?? 0,
    );
  }

  final String id;
  final String sku;
  final String description;
  final int quantityReceived;
  final int unitCost;
}

class InventoryFinanceGoodsReceiptDetailDto {
  InventoryFinanceGoodsReceiptDetailDto({
    required this.id,
    required this.grnNumber,
    required this.purchaseOrderId,
    required this.poNumber,
    required this.vendorName,
    required this.receivedAt,
    required this.status,
    required this.lines,
  });

  factory InventoryFinanceGoodsReceiptDetailDto.fromJson(
    Map<String, dynamic> json,
  ) {
    final rawLines = json['lines'] as List<dynamic>? ?? const [];
    return InventoryFinanceGoodsReceiptDetailDto(
      id: json['id'] as String? ?? '',
      grnNumber: json['grnNumber'] as String? ?? '',
      purchaseOrderId: json['purchaseOrderId'] as String? ?? '',
      poNumber: json['poNumber'] as String? ?? '',
      vendorName: json['vendorName'] as String? ?? '',
      receivedAt: json['receivedAt'] as String? ?? '',
      status: json['status'] as String? ?? '',
      lines: rawLines
          .map(
            (line) => InventoryFinanceGoodsReceiptLineDto.fromJson(
              line as Map<String, dynamic>,
            ),
          )
          .toList(),
    );
  }

  final String id;
  final String grnNumber;
  final String purchaseOrderId;
  final String poNumber;
  final String vendorName;
  final String receivedAt;
  final String status;
  final List<InventoryFinanceGoodsReceiptLineDto> lines;
}

class InventoryFinancePostingDto {
  InventoryFinancePostingDto({
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

  factory InventoryFinancePostingDto.fromJson(Map<String, dynamic> json) {
    return InventoryFinancePostingDto(
      id: json['id'] as String? ?? '',
      purchaseOrderId: json['purchaseOrderId'] as String? ?? '',
      poNumber: json['poNumber'] as String? ?? '',
      vendorName: json['vendorName'] as String? ?? '',
      apCommitmentId: json['apCommitmentId'] as String? ?? '',
      commitmentNumber: json['commitmentNumber'] as String? ?? '',
      postingStatus: json['postingStatus'] as String? ?? '',
      amount: json['amount'] as int? ?? 0,
      postedAt: json['postedAt'] as String?,
    );
  }

  final String id;
  final String purchaseOrderId;
  final String poNumber;
  final String vendorName;
  final String apCommitmentId;
  final String commitmentNumber;
  final String postingStatus;
  final int amount;
  final String? postedAt;
}

class InventoryFinanceVendorDto {
  InventoryFinanceVendorDto({
    required this.id,
    required this.vendorCode,
    required this.displayName,
    required this.contactPhone,
    required this.contactEmail,
    required this.gstin,
    required this.status,
  });

  factory InventoryFinanceVendorDto.fromJson(Map<String, dynamic> json) {
    return InventoryFinanceVendorDto(
      id: json['id'] as String? ?? '',
      vendorCode: json['vendorCode'] as String? ?? '',
      displayName: json['displayName'] as String? ?? '',
      contactPhone: json['contactPhone'] as String?,
      contactEmail: json['contactEmail'] as String?,
      gstin: json['gstin'] as String?,
      status: json['status'] as String? ?? 'active',
    );
  }

  final String id;
  final String vendorCode;
  final String displayName;
  final String? contactPhone;
  final String? contactEmail;
  final String? gstin;
  final String status;
}

class InventoryFinancePurchaseOrderSummaryDto {
  InventoryFinancePurchaseOrderSummaryDto({
    required this.id,
    required this.poNumber,
    required this.vendorId,
    required this.status,
    required this.totalAmount,
    required this.currency,
    required this.createdAt,
  });

  factory InventoryFinancePurchaseOrderSummaryDto.fromJson(
    Map<String, dynamic> json,
  ) {
    return InventoryFinancePurchaseOrderSummaryDto(
      id: json['id'] as String? ?? '',
      poNumber: json['poNumber'] as String? ?? '',
      vendorId: json['vendorId'] as String? ?? '',
      status: json['status'] as String? ?? '',
      totalAmount: json['totalAmount'] as int? ?? 0,
      currency: json['currency'] as String? ?? 'INR',
      createdAt: json['createdAt'] as String? ?? '',
    );
  }

  final String id;
  final String poNumber;
  final String vendorId;
  final String status;
  final int totalAmount;
  final String currency;
  final String createdAt;
}

class InventoryFinancePurchaseOrderLineDto {
  InventoryFinancePurchaseOrderLineDto({
    required this.id,
    required this.sku,
    required this.description,
    required this.quantity,
    required this.unitCost,
    required this.lineTotal,
    required this.quantityReceived,
  });

  factory InventoryFinancePurchaseOrderLineDto.fromJson(
    Map<String, dynamic> json,
  ) {
    return InventoryFinancePurchaseOrderLineDto(
      id: json['id'] as String? ?? '',
      sku: json['sku'] as String? ?? '',
      description: json['description'] as String? ?? '',
      quantity: json['quantity'] as int? ?? 0,
      unitCost: json['unitCost'] as int? ?? 0,
      lineTotal: json['lineTotal'] as int? ?? 0,
      quantityReceived: json['quantityReceived'] as int? ?? 0,
    );
  }

  final String id;
  final String sku;
  final String description;
  final int quantity;
  final int unitCost;
  final int lineTotal;
  final int quantityReceived;
}

class InventoryFinancePurchaseOrderDetailDto {
  InventoryFinancePurchaseOrderDetailDto({
    required this.purchaseOrder,
    required this.lines,
  });

  factory InventoryFinancePurchaseOrderDetailDto.fromJson(
    Map<String, dynamic> json,
  ) {
    final rawLines = json['lines'] as List<dynamic>? ?? const [];
    return InventoryFinancePurchaseOrderDetailDto(
      purchaseOrder: InventoryFinancePurchaseOrderSummaryDto.fromJson(
        json['purchaseOrder'] as Map<String, dynamic>? ?? const {},
      ),
      lines: rawLines
          .map(
            (line) => InventoryFinancePurchaseOrderLineDto.fromJson(
              line as Map<String, dynamic>,
            ),
          )
          .toList(),
    );
  }

  final InventoryFinancePurchaseOrderSummaryDto purchaseOrder;
  final List<InventoryFinancePurchaseOrderLineDto> lines;
}

class InventoryFinanceVendorTransactionDto {
  InventoryFinanceVendorTransactionDto({
    required this.id,
    required this.transactionType,
    required this.referenceNumber,
    required this.amount,
    required this.status,
    required this.occurredAt,
  });

  factory InventoryFinanceVendorTransactionDto.fromJson(
    Map<String, dynamic> json,
  ) {
    return InventoryFinanceVendorTransactionDto(
      id: json['id'] as String? ?? '',
      transactionType: json['transactionType'] as String? ?? '',
      referenceNumber: json['referenceNumber'] as String? ?? '',
      amount: json['amount'] as int? ?? 0,
      status: json['status'] as String? ?? '',
      occurredAt: json['occurredAt'] as String? ?? '',
    );
  }

  final String id;
  final String transactionType;
  final String referenceNumber;
  final int amount;
  final String status;
  final String occurredAt;
}

class InventoryFinanceStockValuationItemDto {
  InventoryFinanceStockValuationItemDto({
    required this.sku,
    required this.quantityOnHand,
    required this.weightedAvgCost,
    required this.inventoryValue,
  });

  factory InventoryFinanceStockValuationItemDto.fromJson(
    Map<String, dynamic> json,
  ) {
    return InventoryFinanceStockValuationItemDto(
      sku: json['sku'] as String? ?? '',
      quantityOnHand: json['quantityOnHand'] as int? ?? 0,
      weightedAvgCost: json['weightedAvgCost'] as int? ?? 0,
      inventoryValue: json['inventoryValue'] as int? ?? 0,
    );
  }

  final String sku;
  final int quantityOnHand;
  final int weightedAvgCost;
  final int inventoryValue;
}

Map<String, dynamic> parseInventoryFinanceEnvelope(Map<String, dynamic> json) {
  return ApiEnvelopeDto.fromJson(json).data ?? const {};
}

List<Map<String, dynamic>> parseInventoryFinanceItems(Map<String, dynamic> json) {
  final data = parseInventoryFinanceEnvelope(json);
  final items = data['items'] as List<dynamic>? ?? const [];
  return items.map((item) => item as Map<String, dynamic>).toList();
}

// ── INV-1..7 — Store STOCK module DTOs ──

class StockIssueDto {
  StockIssueDto({
    required this.issueId,
    required this.issueNumber,
    required this.posted,
    required this.movementIds,
    required this.lowStockCount,
  });

  factory StockIssueDto.fromJson(Map<String, dynamic> json) {
    final rawMovements = json['movementIds'] as List<dynamic>? ?? const [];
    return StockIssueDto(
      issueId: json['issueId'] as String? ?? '',
      issueNumber: json['issueNumber'] as String? ?? '',
      posted: json['posted'] as bool? ?? false,
      movementIds: rawMovements.map((m) => m as String).toList(),
      lowStockCount: json['lowStockCount'] as int? ?? 0,
    );
  }

  final String issueId;
  final String issueNumber;
  final bool posted;
  final List<String> movementIds;
  final int lowStockCount;
}

class StockAdjustmentResultDto {
  StockAdjustmentResultDto({
    required this.applied,
    required this.movementId,
    required this.adjustmentId,
    required this.qtyBefore,
    required this.qtyAfter,
    required this.status,
  });

  factory StockAdjustmentResultDto.fromJson(Map<String, dynamic> json) {
    return StockAdjustmentResultDto(
      applied: json['applied'] as bool? ?? false,
      movementId: json['movementId'] as String?,
      adjustmentId: json['adjustmentId'] as String?,
      qtyBefore: json['qtyBefore'] as int? ?? 0,
      qtyAfter: json['qtyAfter'] as int? ?? 0,
      status: json['status'] as String? ?? 'pending',
    );
  }

  final bool applied;
  final String? movementId;
  final String? adjustmentId;
  final int qtyBefore;
  final int qtyAfter;
  final String status;
}

class StockAdjustmentDto {
  StockAdjustmentDto({
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

  factory StockAdjustmentDto.fromJson(Map<String, dynamic> json) {
    return StockAdjustmentDto(
      id: json['id'] as String? ?? '',
      sku: json['sku'] as String? ?? '',
      qty: json['qty'] as int? ?? 0,
      movementType: json['movement_type'] as String? ??
          json['movementType'] as String? ??
          '',
      reason: json['reason'] as String? ?? '',
      status: json['status'] as String? ?? 'pending',
      referenceType:
          json['reference_type'] as String? ?? json['referenceType'] as String?,
      referenceId:
          json['reference_id'] as String? ?? json['referenceId'] as String?,
      makerId: json['maker_id'] as String? ?? json['makerId'] as String?,
      checkerId: json['checker_id'] as String? ?? json['checkerId'] as String?,
      decisionComment: json['decision_comment'] as String? ??
          json['decisionComment'] as String?,
      createdAt:
          json['created_at'] as String? ?? json['createdAt'] as String? ?? '',
    );
  }

  final String id;
  final String sku;
  final int qty;
  final String movementType;
  final String reason;
  final String status;
  final String? referenceType;
  final String? referenceId;
  final String? makerId;
  final String? checkerId;
  final String? decisionComment;
  final String createdAt;
}

class StockAdjustmentDecisionDto {
  StockAdjustmentDecisionDto({
    required this.adjustmentId,
    required this.sku,
    required this.status,
    required this.movementId,
    required this.qtyBefore,
    required this.qtyAfter,
  });

  factory StockAdjustmentDecisionDto.fromJson(Map<String, dynamic> json) {
    return StockAdjustmentDecisionDto(
      adjustmentId: json['adjustmentId'] as String? ?? '',
      sku: json['sku'] as String? ?? '',
      status: json['status'] as String? ?? '',
      movementId: json['movementId'] as String?,
      qtyBefore: json['qtyBefore'] as int? ?? 0,
      qtyAfter: json['qtyAfter'] as int? ?? 0,
    );
  }

  final String adjustmentId;
  final String sku;
  final String status;
  final String? movementId;
  final int qtyBefore;
  final int qtyAfter;
}

class StockCountLineResultDto {
  StockCountLineResultDto({
    required this.sku,
    required this.countedQty,
    required this.systemQty,
    required this.variance,
    required this.outcome,
    required this.movementId,
    required this.adjustmentId,
  });

  factory StockCountLineResultDto.fromJson(Map<String, dynamic> json) {
    return StockCountLineResultDto(
      sku: json['sku'] as String? ?? '',
      countedQty: json['countedQty'] as int? ?? 0,
      systemQty: json['systemQty'] as int? ?? 0,
      variance: json['variance'] as int? ?? 0,
      outcome: json['outcome'] as String? ?? 'no_change',
      movementId: json['movementId'] as String?,
      adjustmentId: json['adjustmentId'] as String?,
    );
  }

  final String sku;
  final int countedQty;
  final int systemQty;
  final int variance;
  final String outcome;
  final String? movementId;
  final String? adjustmentId;
}

class StockCountResultDto {
  StockCountResultDto({
    required this.sessionId,
    required this.sessionNumber,
    required this.posted,
    required this.lines,
  });

  factory StockCountResultDto.fromJson(Map<String, dynamic> json) {
    final rawLines = json['lines'] as List<dynamic>? ?? const [];
    return StockCountResultDto(
      sessionId: json['sessionId'] as String? ?? '',
      sessionNumber: json['sessionNumber'] as String? ?? '',
      posted: json['posted'] as bool? ?? false,
      lines: rawLines
          .map((l) => StockCountLineResultDto.fromJson(l as Map<String, dynamic>))
          .toList(),
    );
  }

  final String sessionId;
  final String sessionNumber;
  final bool posted;
  final List<StockCountLineResultDto> lines;
}

class StockItemDto {
  StockItemDto({
    required this.sku,
    required this.itemName,
    required this.itemType,
    required this.reorderLevel,
    required this.quantityOnHand,
    required this.weightedAvgCost,
  });

  factory StockItemDto.fromJson(Map<String, dynamic> json) {
    return StockItemDto(
      sku: json['sku'] as String? ?? '',
      itemName: json['item_name'] as String? ?? json['itemName'] as String?,
      itemType: json['item_type'] as String? ??
          json['itemType'] as String? ??
          'consumable',
      reorderLevel:
          json['reorder_level'] as int? ?? json['reorderLevel'] as int? ?? 0,
      quantityOnHand: json['quantity_on_hand'] as int? ??
          json['quantityOnHand'] as int? ??
          0,
      weightedAvgCost: json['weighted_avg_cost'] as int? ??
          json['weightedAvgCost'] as int? ??
          0,
    );
  }

  final String sku;
  final String? itemName;
  final String itemType;
  final int reorderLevel;
  final int quantityOnHand;
  final int weightedAvgCost;
}

class LowStockRowDto {
  LowStockRowDto({
    required this.sku,
    required this.itemName,
    required this.quantityOnHand,
    required this.reorderLevel,
    required this.recommendedQuantity,
    required this.vendorId,
  });

  factory LowStockRowDto.fromJson(Map<String, dynamic> json) {
    return LowStockRowDto(
      sku: json['sku'] as String? ?? '',
      itemName: json['itemName'] as String? ?? json['sku'] as String? ?? '',
      quantityOnHand: json['quantityOnHand'] as int? ?? 0,
      reorderLevel: json['reorderLevel'] as int? ?? 0,
      recommendedQuantity: json['recommendedQuantity'] as int? ?? 0,
      vendorId: json['vendorId'] as String?,
    );
  }

  final String sku;
  final String itemName;
  final int quantityOnHand;
  final int reorderLevel;
  final int recommendedQuantity;
  final String? vendorId;
}

class StockRegisterRowDto {
  StockRegisterRowDto({
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

  factory StockRegisterRowDto.fromJson(Map<String, dynamic> json) {
    return StockRegisterRowDto(
      id: json['id'] as String? ?? '',
      sku: json['sku'] as String? ?? '',
      movementType: json['movementType'] as String? ?? '',
      quantityDelta: json['quantityDelta'] as int? ?? 0,
      qtyBefore: json['qtyBefore'] as int? ?? 0,
      qtyAfter: json['qtyAfter'] as int? ?? 0,
      reason: json['reason'] as String? ?? '',
      referenceType: json['referenceType'] as String?,
      referenceId: json['referenceId'] as String?,
      createdBy: json['createdBy'] as String?,
      createdAt: json['createdAt'] as String? ?? '',
    );
  }

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
  final String createdAt;
}
