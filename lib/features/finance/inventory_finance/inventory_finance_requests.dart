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

// ── INV-1..6 — Store STOCK module request DTOs ──

/// INV-1 — post an issue slip. Idempotent on [issueNumber]; the repo rejects any
/// line that exceeds on-hand (422 InsufficientStock).
class IssueStockRequest {
  const IssueStockRequest({
    required this.sku,
    required this.quantity,
    this.issuedTo,
    this.reason,
    this.issueNumber,
  });

  final String sku;
  final int quantity;
  final String? issuedTo;
  final String? reason;

  /// Optional caller-supplied slip number for idempotency; when null the client
  /// generates one.
  final String? issueNumber;
}

/// INV-3 — record a manual adjustment. `adjust_in`/`opening` apply immediately;
/// `adjust_out` returns a pending maker-checker adjustment. A reason is
/// mandatory.
class AdjustStockRequest {
  const AdjustStockRequest({
    required this.sku,
    required this.qty,
    required this.movementType,
    required this.reason,
    this.unitCostPaise,
  });

  final String sku;
  final int qty;

  /// One of `adjust_in`, `adjust_out`, `opening`.
  final String movementType;
  final String reason;
  final int? unitCostPaise;
}

/// INV-6 — post a physical stock count. NEGATIVE variance returns a pending
/// adjustment; positive applies immediately.
class RecordStockCountRequest {
  const RecordStockCountRequest({
    required this.sku,
    required this.countedQty,
    this.sessionNumber,
    this.notes,
  });

  final String sku;
  final int countedQty;
  final String? sessionNumber;
  final String? notes;
}

/// INV-2 — upsert a consumable/asset registry item + reorder level.
class UpsertStockItemRequest {
  const UpsertStockItemRequest({
    required this.sku,
    this.itemName,
    this.itemType = 'consumable',
    this.reorderLevel = 0,
    this.unitCostPaise,
  });

  final String sku;
  final String? itemName;

  /// `asset` or `consumable`.
  final String itemType;
  final int reorderLevel;
  final int? unitCostPaise;
}
