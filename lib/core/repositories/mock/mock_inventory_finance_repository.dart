import '../interfaces/inventory_finance_repository.dart';
import '../paginated_result.dart';
import '../repository_query.dart';
import '../../../features/finance/inventory_finance/inventory_finance_models.dart';
import '../../../features/finance/inventory_finance/inventory_finance_requests.dart';

/// Demo inventory–finance data for reconciliation UI (v7.2c).
class MockInventoryFinanceRepository implements InventoryFinanceRepository {
  MockInventoryFinanceRepository();

  int _poCounter = 200;
  int _grnCounter = 100;

  static final _vendors = [
    const InventoryFinanceVendor(
      id: 'vendor_if_1',
      vendorCode: 'VEN-001',
      displayName: 'Akshara Stationery Supplies',
      contactPhone: '+91 98765 43210',
      contactEmail: 'billing@akshara-supplies.in',
      gstin: '29ABCDE1234F1Z5',
      status: 'active',
    ),
    const InventoryFinanceVendor(
      id: 'vendor_if_2',
      vendorCode: 'VEN-002',
      displayName: 'TechLab Equipment Co.',
      contactPhone: '+91 91234 56789',
      contactEmail: 'accounts@techlab.in',
      gstin: '29FGHIJ5678K2Z6',
      status: 'active',
    ),
  ];

  static final _purchaseOrders = [
    InventoryFinancePurchaseOrderSummary(
      id: 'po_if_1',
      poNumber: 'PO-2026-0142',
      vendorId: 'vendor_if_1',
      status: 'approved',
      totalAmount: formatInventoryFinancePaise(1250000),
      currency: 'INR',
      createdAt: DateTime(2026, 5, 12),
    ),
    InventoryFinancePurchaseOrderSummary(
      id: 'po_if_2',
      poNumber: 'PO-2026-0158',
      vendorId: 'vendor_if_2',
      status: 'draft',
      totalAmount: formatInventoryFinancePaise(845000),
      currency: 'INR',
      createdAt: DateTime(2026, 6, 2),
    ),
  ];

  static final _purchaseOrderDetails = <InventoryFinancePurchaseOrder>[
    InventoryFinancePurchaseOrder(
      id: 'po_if_1',
      poNumber: 'PO-2026-0142',
      vendorId: 'vendor_if_1',
      status: 'approved',
      totalAmount: formatInventoryFinancePaise(1250000),
      currency: 'INR',
      createdAt: DateTime(2026, 5, 12),
      lines: [
        InventoryFinancePurchaseOrderLine(
          id: 'pol_1',
          sku: 'NB-A4-200',
          description: 'A4 notebooks (200 pages)',
          quantity: 500,
          unitCost: formatInventoryFinancePaise(4500),
          lineTotal: formatInventoryFinancePaise(2250000),
          quantityReceived: 500,
        ),
        InventoryFinancePurchaseOrderLine(
          id: 'pol_2',
          sku: 'PEN-BLUE',
          description: 'Blue ballpoint pens',
          quantity: 1000,
          unitCost: formatInventoryFinancePaise(1200),
          lineTotal: formatInventoryFinancePaise(1200000),
          quantityReceived: 1000,
        ),
      ],
    ),
    InventoryFinancePurchaseOrder(
      id: 'po_if_2',
      poNumber: 'PO-2026-0145',
      vendorId: 'vendor_if_2',
      status: 'draft',
      totalAmount: formatInventoryFinancePaise(845000),
      currency: 'INR',
      createdAt: DateTime(2026, 6, 2),
      lines: [
        InventoryFinancePurchaseOrderLine(
          id: 'pol_21',
          sku: 'BOOK-LIB-001',
          description: 'Library books lot 1',
          quantity: 120,
          unitCost: formatInventoryFinancePaise(18000),
          lineTotal: formatInventoryFinancePaise(2160000),
          quantityReceived: 0,
        ),
        InventoryFinancePurchaseOrderLine(
          id: 'pol_22',
          sku: 'BOOK-LIB-002',
          description: 'Library books lot 2',
          quantity: 80,
          unitCost: formatInventoryFinancePaise(15750),
          lineTotal: formatInventoryFinancePaise(1260000),
          quantityReceived: 0,
        ),
      ],
    ),
  ];

  static final _goodsReceipts = [
    InventoryFinanceGoodsReceiptSummary(
      id: 'grn_if_1',
      grnNumber: 'GRN-PO-2026-0142-482910',
      purchaseOrderId: 'po_if_1',
      poNumber: 'PO-2026-0142',
      vendorName: 'Akshara Stationery Supplies',
      receivedAt: DateTime(2026, 5, 18, 14, 30),
      status: 'posted',
      lineCount: 2,
    ),
  ];

  static final _postings = [
    InventoryFinancePosting(
      id: 'post_if_1',
      purchaseOrderId: 'po_if_1',
      poNumber: 'PO-2026-0142',
      vendorName: 'Akshara Stationery Supplies',
      apCommitmentId: 'ap_if_1',
      commitmentNumber: 'AP-PO-2026-0142',
      postingStatus: 'posted',
      amount: formatInventoryFinancePaise(1250000),
      postedAt: DateTime(2026, 5, 14, 10, 15),
    ),
  ];

  static final _timeline = [
    InventoryFinanceTimelineEntry(
      id: 'tl_if_1',
      eventType: 'finance_posting',
      entityType: 'inventory_finance_posting',
      entityId: 'post_if_1',
      label: 'PO-2026-0142',
      amount: formatInventoryFinancePaise(1250000),
      occurredAt: DateTime(2026, 5, 14, 10, 15),
      referenceId: 'po_if_1',
    ),
    InventoryFinanceTimelineEntry(
      id: 'tl_if_2',
      eventType: 'goods_received',
      entityType: 'goods_receipt',
      entityId: 'grn_if_1',
      label: 'GRN-PO-2026-0142-482910',
      amount: formatInventoryFinancePaise(1250000),
      occurredAt: DateTime(2026, 5, 18, 14, 30),
      referenceId: 'po_if_1',
    ),
    InventoryFinanceTimelineEntry(
      id: 'tl_if_3',
      eventType: 'purchase_order_approved',
      entityType: 'purchase_order',
      entityId: 'po_if_1',
      label: 'PO-2026-0142',
      amount: formatInventoryFinancePaise(1250000),
      occurredAt: DateTime(2026, 5, 13, 9, 0),
      referenceId: 'vendor_if_1',
    ),
    InventoryFinanceTimelineEntry(
      id: 'tl_if_4',
      eventType: 'purchase_order_created',
      entityType: 'purchase_order',
      entityId: 'po_if_2',
      label: 'PO-2026-0158',
      amount: formatInventoryFinancePaise(845000),
      occurredAt: DateTime(2026, 6, 2, 11, 20),
      referenceId: 'vendor_if_2',
    ),
  ];

  @override
  Future<InventoryFinanceReconciliationDashboard> getReconciliationDashboard({
    required RepositoryQuery query,
  }) async {
    return InventoryFinanceReconciliationDashboard(
      vendorCount: _vendors.length,
      purchaseOrderCount: _purchaseOrders.length,
      draftPurchaseOrders:
          _purchaseOrders.where((po) => po.status == 'draft').length,
      openApCommitments: 1,
      openApAmount: formatInventoryFinancePaise(1250000),
      postedFinancePostings: _postings.length,
      goodsReceiptCount: _goodsReceipts.length,
      inventoryValue: formatInventoryFinancePaise(980000),
    );
  }

  @override
  Future<List<InventoryFinanceTimelineEntry>> getTimeline({
    required RepositoryQuery query,
  }) async {
    return _timeline;
  }

  @override
  Future<PaginatedResult<InventoryFinanceGoodsReceiptSummary>>
      getGoodsReceipts({
    required RepositoryQuery query,
  }) async {
    return PaginatedResult(
      items: _goodsReceipts,
      page: query.page,
      pageSize: query.pageSize,
      total: _goodsReceipts.length,
      hasMore: false,
    );
  }

  @override
  Future<InventoryFinanceGoodsReceiptDetail?> getGoodsReceipt({
    required RepositoryQuery query,
    required String goodsReceiptId,
  }) async {
    if (goodsReceiptId != 'grn_if_1') return null;
    return InventoryFinanceGoodsReceiptDetail(
      id: 'grn_if_1',
      grnNumber: 'GRN-PO-2026-0142-482910',
      purchaseOrderId: 'po_if_1',
      poNumber: 'PO-2026-0142',
      vendorName: 'Akshara Stationery Supplies',
      receivedAt: DateTime(2026, 5, 18, 14, 30),
      status: 'posted',
      lines: [
        InventoryFinanceGoodsReceiptLine(
          id: 'grnl_1',
          sku: 'NB-A4-200',
          description: 'A4 notebooks (200 pages)',
          quantityReceived: 500,
          unitCost: formatInventoryFinancePaise(4500),
        ),
        InventoryFinanceGoodsReceiptLine(
          id: 'grnl_2',
          sku: 'PEN-BLUE',
          description: 'Blue ballpoint pens',
          quantityReceived: 1000,
          unitCost: formatInventoryFinancePaise(1200),
        ),
      ],
    );
  }

  @override
  Future<PaginatedResult<InventoryFinancePosting>> getPostings({
    required RepositoryQuery query,
  }) async {
    return PaginatedResult(
      items: _postings,
      page: query.page,
      pageSize: query.pageSize,
      total: _postings.length,
      hasMore: false,
    );
  }

  @override
  Future<PaginatedResult<InventoryFinanceVendor>> getVendors({
    required RepositoryQuery query,
  }) async {
    return PaginatedResult(
      items: _vendors,
      page: query.page,
      pageSize: query.pageSize,
      total: _vendors.length,
      hasMore: false,
    );
  }

  @override
  Future<PaginatedResult<InventoryFinancePurchaseOrderSummary>>
      getPurchaseOrders({
    required RepositoryQuery query,
  }) async {
    return PaginatedResult(
      items: _purchaseOrders,
      page: query.page,
      pageSize: query.pageSize,
      total: _purchaseOrders.length,
      hasMore: false,
    );
  }

  @override
  Future<InventoryFinancePurchaseOrder?> getPurchaseOrder({
    required RepositoryQuery query,
    required String purchaseOrderId,
  }) async {
    for (final po in _purchaseOrderDetails) {
      if (po.id == purchaseOrderId || po.poNumber == purchaseOrderId) {
        return po;
      }
    }
    return null;
  }

  @override
  Future<List<InventoryFinanceVendorTransaction>> getVendorTransactions({
    required RepositoryQuery query,
    required String vendorId,
  }) async {
    if (vendorId == 'vendor_if_1') {
      return [
        InventoryFinanceVendorTransaction(
          id: 'po_if_1',
          transactionType: 'purchase_order',
          referenceNumber: 'PO-2026-0142',
          amount: formatInventoryFinancePaise(1250000),
          status: 'approved',
          occurredAt: DateTime(2026, 5, 12),
        ),
        InventoryFinanceVendorTransaction(
          id: 'ap_if_1',
          transactionType: 'ap_commitment',
          referenceNumber: 'AP-PO-2026-0142',
          amount: formatInventoryFinancePaise(1250000),
          status: 'open',
          occurredAt: DateTime(2026, 5, 14),
        ),
      ];
    }
    return [];
  }

  @override
  Future<List<InventoryFinanceStockValuation>> getStockValuation({
    required RepositoryQuery query,
  }) async {
    return [
      InventoryFinanceStockValuation(
        sku: 'NB-A4-200',
        quantityOnHand: 500,
        weightedAvgCost: formatInventoryFinancePaise(4500),
        inventoryValue: formatInventoryFinancePaise(2250000),
      ),
    ];
  }

  @override
  Future<InventoryFinanceVendor> createVendor({
    required RepositoryQuery query,
    required CreateInventoryVendorRequest request,
  }) async {
    return InventoryFinanceVendor(
      id: 'vendor_if_new',
      vendorCode: request.vendorCode,
      displayName: request.displayName,
      contactPhone: request.contactPhone,
      contactEmail: request.contactEmail,
      gstin: request.gstin,
      status: 'active',
    );
  }

  @override
  Future<InventoryFinancePurchaseOrderSummary> createPurchaseOrder({
    required RepositoryQuery query,
    required CreateInventoryPurchaseOrderRequest request,
  }) async {
    final total = request.lines.fold<int>(
      0,
      (sum, line) => sum + line.quantity * line.unitCostPaise,
    );
    final id = 'po_if_${++_poCounter}';
    final summary = InventoryFinancePurchaseOrderSummary(
      id: id,
      poNumber: request.poNumber,
      vendorId: request.vendorId,
      status: 'draft',
      totalAmount: formatInventoryFinancePaise(total),
      currency: 'INR',
      createdAt: DateTime.now(),
    );
    _purchaseOrders.insert(0, summary);
    _purchaseOrderDetails.insert(
      0,
      InventoryFinancePurchaseOrder(
        id: id,
        poNumber: request.poNumber,
        vendorId: request.vendorId,
        status: 'draft',
        totalAmount: formatInventoryFinancePaise(total),
        currency: 'INR',
        createdAt: summary.createdAt,
        lines: [
          for (var i = 0; i < request.lines.length; i++)
            InventoryFinancePurchaseOrderLine(
              id: 'pol_${_poCounter}_$i',
              sku: request.lines[i].sku,
              description: request.lines[i].description,
              quantity: request.lines[i].quantity,
              unitCost:
                  formatInventoryFinancePaise(request.lines[i].unitCostPaise),
              lineTotal: formatInventoryFinancePaise(
                request.lines[i].quantity * request.lines[i].unitCostPaise,
              ),
              quantityReceived: 0,
            ),
        ],
      ),
    );
    _timeline.insert(
      0,
      InventoryFinanceTimelineEntry(
        id: 'tl_if_po_$_poCounter',
        eventType: 'purchase_order_created',
        entityType: 'purchase_order',
        entityId: id,
        label: request.poNumber,
        amount: formatInventoryFinancePaise(total),
        occurredAt: summary.createdAt,
        referenceId: request.vendorId,
      ),
    );
    return summary;
  }

  @override
  Future<InventoryFinanceApproveResult> approvePurchaseOrder({
    required RepositoryQuery query,
    required String purchaseOrderId,
  }) async {
    final poIndex = _purchaseOrderDetails.indexWhere(
      (po) => po.id == purchaseOrderId || po.poNumber == purchaseOrderId,
    );
    if (poIndex < 0) {
      throw StateError('Purchase order not found: $purchaseOrderId');
    }
    final current = _purchaseOrderDetails[poIndex];
    final approved = InventoryFinancePurchaseOrder(
      id: current.id,
      poNumber: current.poNumber,
      vendorId: current.vendorId,
      status: 'approved',
      totalAmount: current.totalAmount,
      currency: current.currency,
      createdAt: current.createdAt,
      lines: current.lines,
    );
    _purchaseOrderDetails[poIndex] = approved;
    final summaryIndex =
        _purchaseOrders.indexWhere((po) => po.id == current.id);
    if (summaryIndex >= 0) {
      final summary = _purchaseOrders[summaryIndex];
      _purchaseOrders[summaryIndex] = InventoryFinancePurchaseOrderSummary(
        id: summary.id,
        poNumber: summary.poNumber,
        vendorId: summary.vendorId,
        status: 'approved',
        totalAmount: summary.totalAmount,
        currency: summary.currency,
        createdAt: summary.createdAt,
      );
    }
    _timeline.insert(
      0,
      InventoryFinanceTimelineEntry(
        id: 'tl_if_ap_${current.id}',
        eventType: 'purchase_order_approved',
        entityType: 'purchase_order',
        entityId: current.id,
        label: current.poNumber,
        amount: current.totalAmount,
        occurredAt: DateTime.now(),
        referenceId: current.vendorId,
      ),
    );
    return InventoryFinanceApproveResult(
      purchaseOrder: approved,
      apCommitmentId: 'ap_if_${current.id}',
      financePostingId: 'post_if_${current.id}',
    );
  }

  @override
  Future<InventoryFinanceReceiveResult> receiveGoods({
    required RepositoryQuery query,
    required String purchaseOrderId,
    required ReceiveInventoryGoodsRequest request,
  }) async {
    final poIndex = _purchaseOrderDetails.indexWhere(
      (po) => po.id == purchaseOrderId || po.poNumber == purchaseOrderId,
    );
    if (poIndex < 0) {
      throw StateError('Purchase order not found: $purchaseOrderId');
    }
    final current = _purchaseOrderDetails[poIndex];
    final updatedLines = [
      for (final line in current.lines)
        () {
          final receivedLine = request.lines
              .where((item) => item.purchaseOrderLineId == line.id)
              .toList();
          if (receivedLine.isEmpty) return line;
          final delta = receivedLine.fold<int>(
            0,
            (sum, item) => sum + item.quantityReceived,
          );
          final updatedReceived = line.quantityReceived + delta;
          return InventoryFinancePurchaseOrderLine(
            id: line.id,
            sku: line.sku,
            description: line.description,
            quantity: line.quantity,
            unitCost: line.unitCost,
            lineTotal: line.lineTotal,
            quantityReceived: updatedReceived > line.quantity
                ? line.quantity
                : updatedReceived,
          );
        }(),
    ];
    final fullyReceived =
        updatedLines.every((line) => line.quantityPending <= 0);
    final updatedPo = InventoryFinancePurchaseOrder(
      id: current.id,
      poNumber: current.poNumber,
      vendorId: current.vendorId,
      status: fullyReceived ? 'received' : current.status,
      totalAmount: current.totalAmount,
      currency: current.currency,
      createdAt: current.createdAt,
      lines: updatedLines,
    );
    _purchaseOrderDetails[poIndex] = updatedPo;

    final summaryIndex =
        _purchaseOrders.indexWhere((po) => po.id == current.id);
    if (summaryIndex >= 0 && fullyReceived) {
      final summary = _purchaseOrders[summaryIndex];
      _purchaseOrders[summaryIndex] = InventoryFinancePurchaseOrderSummary(
        id: summary.id,
        poNumber: summary.poNumber,
        vendorId: summary.vendorId,
        status: 'received',
        totalAmount: summary.totalAmount,
        currency: summary.currency,
        createdAt: summary.createdAt,
      );
    }

    final grnId = 'grn_if_${++_grnCounter}';
    final grnNumber =
        'GRN-${current.poNumber}-${_grnCounter.toString().padLeft(4, '0')}';
    final vendor = _vendors.where((item) => item.id == current.vendorId);
    _goodsReceipts.insert(
      0,
      InventoryFinanceGoodsReceiptSummary(
        id: grnId,
        grnNumber: grnNumber,
        purchaseOrderId: current.id,
        poNumber: current.poNumber,
        vendorName:
            vendor.isNotEmpty ? vendor.first.displayName : 'Unknown vendor',
        receivedAt: DateTime.now(),
        status: 'posted',
        lineCount: request.lines.length,
      ),
    );
    _timeline.insert(
      0,
      InventoryFinanceTimelineEntry(
        id: 'tl_if_grn_$grnId',
        eventType: 'goods_received',
        entityType: 'goods_receipt',
        entityId: grnId,
        label: grnNumber,
        amount: current.totalAmount,
        occurredAt: DateTime.now(),
        referenceId: current.id,
      ),
    );
    return InventoryFinanceReceiveResult(
      grnId: grnId,
      grnNumber: grnNumber,
    );
  }
}
