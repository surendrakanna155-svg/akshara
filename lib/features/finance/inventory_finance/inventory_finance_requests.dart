class CreateInventoryVendorRequest {
  const CreateInventoryVendorRequest({
    required this.vendorCode,
    required this.displayName,
    this.contactPhone,
    this.contactEmail,
    this.gstin,
  });

  final String vendorCode;
  final String displayName;
  final String? contactPhone;
  final String? contactEmail;
  final String? gstin;
}

class CreateInventoryPurchaseOrderLineRequest {
  const CreateInventoryPurchaseOrderLineRequest({
    required this.sku,
    required this.description,
    required this.quantity,
    required this.unitCostPaise,
  });

  final String sku;
  final String description;
  final int quantity;
  final int unitCostPaise;
}

class CreateInventoryPurchaseOrderRequest {
  const CreateInventoryPurchaseOrderRequest({
    required this.vendorId,
    required this.poNumber,
    required this.lines,
    this.notes,
  });

  final String vendorId;
  final String poNumber;
  final List<CreateInventoryPurchaseOrderLineRequest> lines;
  final String? notes;
}

class ReceiveInventoryGoodsLineRequest {
  const ReceiveInventoryGoodsLineRequest({
    required this.purchaseOrderLineId,
    required this.quantityReceived,
  });

  final String purchaseOrderLineId;
  final int quantityReceived;
}

class ReceiveInventoryGoodsRequest {
  const ReceiveInventoryGoodsRequest({
    required this.lines,
  });

  final List<ReceiveInventoryGoodsLineRequest> lines;
}

class InventoryFinancePurchaseOrderSummary {
  const InventoryFinancePurchaseOrderSummary({
    required this.id,
    required this.poNumber,
    required this.vendorId,
    required this.status,
    required this.totalAmount,
    required this.currency,
    required this.createdAt,
  });

  final String id;
  final String poNumber;
  final String vendorId;
  final String status;
  final String totalAmount;
  final String currency;
  final DateTime createdAt;
}
