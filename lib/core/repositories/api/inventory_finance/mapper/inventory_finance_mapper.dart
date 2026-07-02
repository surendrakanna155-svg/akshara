import '../../../../../features/finance/inventory_finance/inventory_finance_models.dart';
import '../../../../../features/finance/inventory_finance/inventory_finance_requests.dart';
import '../dto/inventory_finance_dto.dart';

class InventoryFinanceMapper {
  const InventoryFinanceMapper();

  InventoryFinanceReconciliationDashboard toDashboard(
    InventoryFinanceDashboardDto dto,
  ) {
    return InventoryFinanceReconciliationDashboard(
      vendorCount: dto.vendorCount,
      purchaseOrderCount: dto.purchaseOrderCount,
      draftPurchaseOrders: dto.draftPurchaseOrders,
      openApCommitments: dto.openApCommitments,
      openApAmount: formatInventoryFinancePaise(dto.openApAmount),
      postedFinancePostings: dto.postedFinancePostings,
      goodsReceiptCount: dto.goodsReceiptCount,
      inventoryValue: formatInventoryFinancePaise(dto.inventoryValue),
    );
  }

  List<InventoryFinanceTimelineEntry> toTimeline(
    List<InventoryFinanceTimelineItemDto> items,
  ) {
    return items
        .map(
          (item) => InventoryFinanceTimelineEntry(
            id: item.id,
            eventType: item.eventType,
            entityType: item.entityType,
            entityId: item.entityId,
            label: item.label,
            amount: item.amount == null
                ? null
                : formatInventoryFinancePaise(item.amount!),
            occurredAt: DateTime.parse(item.occurredAt),
            referenceId: item.referenceId,
          ),
        )
        .toList();
  }

  List<InventoryFinanceGoodsReceiptSummary> toGoodsReceiptSummaries(
    List<InventoryFinanceGoodsReceiptSummaryDto> items,
  ) {
    return items
        .map(
          (item) => InventoryFinanceGoodsReceiptSummary(
            id: item.id,
            grnNumber: item.grnNumber,
            purchaseOrderId: item.purchaseOrderId,
            poNumber: item.poNumber,
            vendorName: item.vendorName,
            receivedAt: DateTime.parse(item.receivedAt),
            status: item.status,
            lineCount: item.lineCount,
          ),
        )
        .toList();
  }

  InventoryFinanceGoodsReceiptDetail toGoodsReceiptDetail(
    InventoryFinanceGoodsReceiptDetailDto dto,
  ) {
    return InventoryFinanceGoodsReceiptDetail(
      id: dto.id,
      grnNumber: dto.grnNumber,
      purchaseOrderId: dto.purchaseOrderId,
      poNumber: dto.poNumber,
      vendorName: dto.vendorName,
      receivedAt: DateTime.parse(dto.receivedAt),
      status: dto.status,
      lines: dto.lines
          .map(
            (line) => InventoryFinanceGoodsReceiptLine(
              id: line.id,
              sku: line.sku,
              description: line.description,
              quantityReceived: line.quantityReceived,
              unitCost: formatInventoryFinancePaise(line.unitCost),
            ),
          )
          .toList(),
    );
  }

  List<InventoryFinancePosting> toPostings(
    List<InventoryFinancePostingDto> items,
  ) {
    return items
        .map(
          (item) => InventoryFinancePosting(
            id: item.id,
            purchaseOrderId: item.purchaseOrderId,
            poNumber: item.poNumber,
            vendorName: item.vendorName,
            apCommitmentId: item.apCommitmentId,
            commitmentNumber: item.commitmentNumber,
            postingStatus: item.postingStatus,
            amount: formatInventoryFinancePaise(item.amount),
            postedAt: item.postedAt == null ? null : DateTime.parse(item.postedAt!),
          ),
        )
        .toList();
  }

  List<InventoryFinanceVendor> toVendors(List<InventoryFinanceVendorDto> items) {
    return items
        .map(
          (item) => InventoryFinanceVendor(
            id: item.id,
            vendorCode: item.vendorCode,
            displayName: item.displayName,
            contactPhone: item.contactPhone,
            contactEmail: item.contactEmail,
            gstin: item.gstin,
            status: item.status,
          ),
        )
        .toList();
  }

  InventoryFinanceVendor toVendor(InventoryFinanceVendorDto dto) {
    return toVendors([dto]).first;
  }

  List<InventoryFinancePurchaseOrderSummary> toPurchaseOrderSummaries(
    List<InventoryFinancePurchaseOrderSummaryDto> items,
  ) {
    return items
        .map(
          (item) => InventoryFinancePurchaseOrderSummary(
            id: item.id,
            poNumber: item.poNumber,
            vendorId: item.vendorId,
            status: item.status,
            totalAmount: formatInventoryFinancePaise(item.totalAmount),
            currency: item.currency,
            createdAt: DateTime.parse(item.createdAt),
          ),
        )
        .toList();
  }

  InventoryFinancePurchaseOrder toPurchaseOrderDetail(
    InventoryFinancePurchaseOrderDetailDto dto,
  ) {
    final summary = dto.purchaseOrder;
    return InventoryFinancePurchaseOrder(
      id: summary.id,
      poNumber: summary.poNumber,
      vendorId: summary.vendorId,
      status: summary.status,
      totalAmount: formatInventoryFinancePaise(summary.totalAmount),
      currency: summary.currency,
      createdAt: DateTime.parse(summary.createdAt),
      lines: dto.lines
          .map(
            (line) => InventoryFinancePurchaseOrderLine(
              id: line.id,
              sku: line.sku,
              description: line.description,
              quantity: line.quantity,
              unitCost: formatInventoryFinancePaise(line.unitCost),
              lineTotal: formatInventoryFinancePaise(line.lineTotal),
              quantityReceived: line.quantityReceived,
            ),
          )
          .toList(),
    );
  }

  List<InventoryFinanceVendorTransaction> toVendorTransactions(
    List<InventoryFinanceVendorTransactionDto> items,
  ) {
    return items
        .map(
          (item) => InventoryFinanceVendorTransaction(
            id: item.id,
            transactionType: item.transactionType,
            referenceNumber: item.referenceNumber,
            amount: formatInventoryFinancePaise(item.amount),
            status: item.status,
            occurredAt: DateTime.parse(item.occurredAt),
          ),
        )
        .toList();
  }

  List<InventoryFinanceStockValuation> toStockValuation(
    List<InventoryFinanceStockValuationItemDto> items,
  ) {
    return items
        .map(
          (item) => InventoryFinanceStockValuation(
            sku: item.sku,
            quantityOnHand: item.quantityOnHand,
            weightedAvgCost: formatInventoryFinancePaise(item.weightedAvgCost),
            inventoryValue: formatInventoryFinancePaise(item.inventoryValue),
          ),
        )
        .toList();
  }

  InventoryFinanceApproveResult toApproveResult(Map<String, dynamic> data) {
    final poJson = data['purchaseOrder'] as Map<String, dynamic>? ?? const {};
    final detail = InventoryFinancePurchaseOrderDetailDto.fromJson({
      'purchaseOrder': poJson,
      'lines': const [],
    });
    return InventoryFinanceApproveResult(
      purchaseOrder: toPurchaseOrderDetail(detail),
      apCommitmentId: data['apCommitmentId'] as String? ?? '',
      financePostingId: data['financePostingId'] as String? ?? '',
    );
  }

  InventoryFinanceReceiveResult toReceiveResult(Map<String, dynamic> data) {
    return InventoryFinanceReceiveResult(
      grnId: data['grnId'] as String? ?? '',
      grnNumber: data['grnNumber'] as String? ?? '',
    );
  }

  // ── INV-1..7 — Store STOCK module ──

  StockIssue toStockIssue(StockIssueDto dto) {
    return StockIssue(
      issueId: dto.issueId,
      issueNumber: dto.issueNumber,
      posted: dto.posted,
      movementIds: dto.movementIds,
      lowStockCount: dto.lowStockCount,
    );
  }

  StockAdjustmentResult toStockAdjustmentResult(StockAdjustmentResultDto dto) {
    return StockAdjustmentResult(
      applied: dto.applied,
      movementId: dto.movementId,
      adjustmentId: dto.adjustmentId,
      qtyBefore: dto.qtyBefore,
      qtyAfter: dto.qtyAfter,
      status: stockAdjustmentStatusFromWire(dto.status),
    );
  }

  StockAdjustment toStockAdjustment(StockAdjustmentDto dto) {
    return StockAdjustment(
      id: dto.id,
      sku: dto.sku,
      qty: dto.qty,
      movementType: dto.movementType,
      reason: dto.reason,
      status: stockAdjustmentStatusFromWire(dto.status),
      referenceType: dto.referenceType,
      referenceId: dto.referenceId,
      makerId: dto.makerId,
      checkerId: dto.checkerId,
      decisionComment: dto.decisionComment,
      createdAt: DateTime.tryParse(dto.createdAt) ?? DateTime(1970),
    );
  }

  List<StockAdjustment> toStockAdjustments(List<StockAdjustmentDto> items) {
    return items.map(toStockAdjustment).toList();
  }

  StockAdjustmentDecision toStockAdjustmentDecision(
    StockAdjustmentDecisionDto dto,
  ) {
    return StockAdjustmentDecision(
      adjustmentId: dto.adjustmentId,
      sku: dto.sku,
      status: stockAdjustmentStatusFromWire(dto.status),
      movementId: dto.movementId,
      qtyBefore: dto.qtyBefore,
      qtyAfter: dto.qtyAfter,
    );
  }

  StockCountResult toStockCountResult(StockCountResultDto dto) {
    return StockCountResult(
      sessionId: dto.sessionId,
      sessionNumber: dto.sessionNumber,
      posted: dto.posted,
      lines: dto.lines
          .map(
            (l) => StockCountLineResult(
              sku: l.sku,
              countedQty: l.countedQty,
              systemQty: l.systemQty,
              variance: l.variance,
              outcome: l.outcome,
              movementId: l.movementId,
              adjustmentId: l.adjustmentId,
            ),
          )
          .toList(),
    );
  }

  StockItem toStockItem(StockItemDto dto) {
    return StockItem(
      sku: dto.sku,
      itemName: dto.itemName,
      itemType: stockItemTypeFromWire(dto.itemType),
      reorderLevel: dto.reorderLevel,
      quantityOnHand: dto.quantityOnHand,
      weightedAvgCost: formatInventoryFinancePaise(dto.weightedAvgCost),
    );
  }

  List<StockItem> toStockItems(List<StockItemDto> items) {
    return items.map(toStockItem).toList();
  }

  List<LowStockRow> toLowStockRows(List<LowStockRowDto> items) {
    return items
        .map(
          (dto) => LowStockRow(
            sku: dto.sku,
            itemName: dto.itemName,
            quantityOnHand: dto.quantityOnHand,
            reorderLevel: dto.reorderLevel,
            recommendedQuantity: dto.recommendedQuantity,
            vendorId: dto.vendorId,
          ),
        )
        .toList();
  }

  List<StockRegisterRow> toStockRegisterRows(List<StockRegisterRowDto> items) {
    return items
        .map(
          (dto) => StockRegisterRow(
            id: dto.id,
            sku: dto.sku,
            movementType: dto.movementType,
            quantityDelta: dto.quantityDelta,
            qtyBefore: dto.qtyBefore,
            qtyAfter: dto.qtyAfter,
            reason: dto.reason,
            referenceType: dto.referenceType,
            referenceId: dto.referenceId,
            createdBy: dto.createdBy,
            createdAt: DateTime.tryParse(dto.createdAt) ?? DateTime(1970),
          ),
        )
        .toList();
  }
}
