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
