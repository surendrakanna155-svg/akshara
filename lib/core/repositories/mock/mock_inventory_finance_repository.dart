import '../../errors/api_failure.dart';
import '../interfaces/inventory_finance_repository.dart';
import '../paginated_result.dart';
import '../repository_query.dart';
import '../../../features/finance/inventory_finance/inventory_finance_models.dart';
import '../../../features/finance/inventory_finance/inventory_finance_requests.dart';

/// In-memory stock valuation row (INV-1..7).
class _MockStockRow {
  _MockStockRow({
    required this.sku,
    required this.itemName,
    required this.itemType,
    required this.reorderLevel,
    required this.quantityOnHand,
    required this.weightedAvgCost,
    required this.vendorId,
  });

  final String sku;
  String? itemName;
  String itemType;
  int reorderLevel;
  int quantityOnHand;
  int weightedAvgCost;
  String? vendorId;
}

/// Demo inventory–finance data for reconciliation UI (v7.2c).
class MockInventoryFinanceRepository implements InventoryFinanceRepository {
  MockInventoryFinanceRepository();

  int _poCounter = 200;
  int _grnCounter = 100;

  // ── INV-1..7 — in-memory stock state (mirrors the backend semantics) ──
  int _stockSeq = 0;
  final Map<String, _MockStockRow> _stock = {
    'NB-A4-200': _MockStockRow(
      sku: 'NB-A4-200',
      itemName: 'A4 notebooks (200 pages)',
      itemType: 'consumable',
      reorderLevel: 100,
      quantityOnHand: 40,
      weightedAvgCost: 4500,
      vendorId: 'vendor_if_1',
    ),
    'PEN-BLUE': _MockStockRow(
      sku: 'PEN-BLUE',
      itemName: 'Blue ballpoint pens',
      itemType: 'consumable',
      reorderLevel: 200,
      quantityOnHand: 350,
      weightedAvgCost: 1200,
      vendorId: 'vendor_if_1',
    ),
    'CHALK-WHITE': _MockStockRow(
      sku: 'CHALK-WHITE',
      itemName: 'White chalk boxes',
      itemType: 'consumable',
      reorderLevel: 50,
      quantityOnHand: 12,
      weightedAvgCost: 3000,
      vendorId: 'vendor_if_2',
    ),
  };
  final List<StockAdjustment> _adjustments = [];
  final List<StockRegisterRow> _register = [];
  final Set<String> _postedIssueNumbers = {};
  final Set<String> _postedCountSessions = {};

  String _nextStockId(String prefix) => '${prefix}_mock_${++_stockSeq}';

  void _recordMovement({
    required String sku,
    required String movementType,
    required int quantityDelta,
    required int qtyBefore,
    required int qtyAfter,
    required String reason,
    String? referenceType,
    String? referenceId,
  }) {
    _register.insert(
      0,
      StockRegisterRow(
        id: _nextStockId('mov'),
        sku: sku,
        movementType: movementType,
        quantityDelta: quantityDelta,
        qtyBefore: qtyBefore,
        qtyAfter: qtyAfter,
        reason: reason,
        referenceType: referenceType,
        referenceId: referenceId,
        createdBy: 'store_demo',
        createdAt: DateTime.now(),
      ),
    );
  }

  Never _insufficientStock(String sku, int requested, int onHand) {
    throw ApiFailureException(
      ApiFailure(
        type: ApiFailureType.unknown,
        message:
            'Insufficient stock for SKU $sku: requested $requested, on hand $onHand',
        code: 'INSUFFICIENT_STOCK',
        statusCode: 422,
      ),
    );
  }

  Never _validation(String message) {
    throw ApiFailureException(
      ApiFailure(
        type: ApiFailureType.unknown,
        message: message,
        code: 'VALIDATION_ERROR',
        statusCode: 422,
      ),
    );
  }

  /// The acting user id for stock writes. The backend reads this from the JWT;
  /// the mock exposes it so maker-checker (the checker <> maker 409 SoD rule)
  /// can be exercised without a live auth stack. The notifiers set this from
  /// [authProvider] before each stock write.
  String currentUserId = 'store_demo';

  /// Test seam — reassign a pending adjustment's maker so widget tests can
  /// exercise the checker≠maker SoD approval without a second auth session
  /// (the decide notifier rebinds [currentUserId] from auth on every call, so
  /// toggling it between calls is overwritten).
  void overrideAdjustmentMakerForTest(String adjustmentId, String makerId) {
    final i = _adjustments.indexWhere((a) => a.id == adjustmentId);
    if (i < 0) return;
    final adj = _adjustments[i];
    _adjustments[i] = StockAdjustment(
      id: adj.id,
      sku: adj.sku,
      qty: adj.qty,
      movementType: adj.movementType,
      reason: adj.reason,
      status: adj.status,
      referenceType: adj.referenceType,
      referenceId: adj.referenceId,
      makerId: makerId,
      checkerId: adj.checkerId,
      decisionComment: adj.decisionComment,
      createdAt: adj.createdAt,
    );
  }

  static final _vendors = [
    const InventoryFinanceVendor(
      id: 'vendor_if_1',
      vendorCode: 'VEN-001',
      displayName: 'NIKSHA Stationery Supplies',
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
      vendorName: 'NIKSHA Stationery Supplies',
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
      vendorName: 'NIKSHA Stationery Supplies',
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
      vendorName: 'NIKSHA Stationery Supplies',
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

  // ── INV-1..7 — Store STOCK module ──

  @override
  Future<StockIssue> issueStock({
    required RepositoryQuery query,
    required IssueStockRequest request,
  }) async {
    final sku = request.sku.trim();
    final quantity = request.quantity;
    if (sku.isEmpty) _validation('sku is required');
    if (quantity <= 0) _validation('quantity must be greater than 0');
    final issueNumber = (request.issueNumber?.trim().isNotEmpty ?? false)
        ? request.issueNumber!.trim()
        : 'ISS-${DateTime.now().millisecondsSinceEpoch}';

    // Idempotency: an already-posted slip short-circuits (no re-decrement).
    if (_postedIssueNumbers.contains(issueNumber)) {
      return StockIssue(
        issueId: 'issue_$issueNumber',
        issueNumber: issueNumber,
        posted: true,
        movementIds: const [],
        lowStockCount: _lowStockRows().length,
      );
    }

    final row = _stock[sku];
    final onHand = row?.quantityOnHand ?? 0;
    if (quantity > onHand) {
      _insufficientStock(sku, quantity, onHand);
    }
    final after = onHand - quantity;
    row!.quantityOnHand = after;
    _recordMovement(
      sku: sku,
      movementType: 'issue',
      quantityDelta: -quantity,
      qtyBefore: onHand,
      qtyAfter: after,
      reason: request.reason ?? '',
      referenceType: 'stock_issue',
      referenceId: 'issue_$issueNumber',
    );
    _postedIssueNumbers.add(issueNumber);
    return StockIssue(
      issueId: 'issue_$issueNumber',
      issueNumber: issueNumber,
      posted: true,
      movementIds: [_register.first.id],
      lowStockCount: _lowStockRows().length,
    );
  }

  @override
  Future<StockAdjustmentResult> adjustStock({
    required RepositoryQuery query,
    required AdjustStockRequest request,
  }) async {
    final sku = request.sku.trim();
    final qty = request.qty;
    final reason = request.reason.trim();
    if (sku.isEmpty) _validation('sku is required');
    if (qty <= 0) _validation('quantity must be greater than 0');
    if (reason.isEmpty) _validation('reason is mandatory on adjustments');
    if (!['adjust_in', 'adjust_out', 'opening'].contains(request.movementType)) {
      _validation('Unsupported adjustment type: ${request.movementType}');
    }

    // Value-reducing → maker-checker: RECORD pending, do NOT touch qty.
    if (request.movementType == 'adjust_out') {
      final id = _nextStockId('adj');
      _adjustments.add(
        StockAdjustment(
          id: id,
          sku: sku,
          qty: qty,
          movementType: 'adjust_out',
          reason: reason,
          status: StockAdjustmentStatus.pending,
          referenceType: 'manual_adjustment',
          referenceId: null,
          makerId: currentUserId,
          checkerId: null,
          decisionComment: null,
          createdAt: DateTime.now(),
        ),
      );
      return StockAdjustmentResult(
        applied: false,
        movementId: null,
        adjustmentId: id,
        qtyBefore: 0,
        qtyAfter: 0,
        status: StockAdjustmentStatus.pending,
      );
    }

    // adjust_in / opening → apply immediately.
    final existing = _stock[sku];
    final before = existing?.quantityOnHand ?? 0;
    final after = before + qty;
    if (existing == null) {
      _stock[sku] = _MockStockRow(
        sku: sku,
        itemName: sku,
        itemType: 'consumable',
        reorderLevel: 0,
        quantityOnHand: after,
        weightedAvgCost: request.unitCostPaise ?? 0,
        vendorId: null,
      );
    } else {
      existing.quantityOnHand = after;
    }
    _recordMovement(
      sku: sku,
      movementType: request.movementType,
      quantityDelta: qty,
      qtyBefore: before,
      qtyAfter: after,
      reason: reason,
      referenceType: 'manual_adjustment',
    );
    return StockAdjustmentResult(
      applied: true,
      movementId: _register.first.id,
      adjustmentId: null,
      qtyBefore: before,
      qtyAfter: after,
      status: StockAdjustmentStatus.applied,
    );
  }

  @override
  Future<StockAdjustmentDecision> approveStockAdjustment({
    required RepositoryQuery query,
    required String adjustmentId,
    String? comment,
  }) async {
    final index = _adjustments.indexWhere((a) => a.id == adjustmentId);
    if (index < 0) {
      throw ApiFailureException(
        ApiFailure(
          type: ApiFailureType.unknown,
          message: 'Stock adjustment not found: $adjustmentId',
          code: 'NOT_FOUND',
          statusCode: 404,
        ),
      );
    }
    final adj = _adjustments[index];
    if (adj.status != StockAdjustmentStatus.pending) {
      throw ApiFailureException(
        ApiFailure(
          type: ApiFailureType.unknown,
          message: 'Stock adjustment $adjustmentId is not pending',
          code: 'INVALID_STATE',
          statusCode: 409,
        ),
      );
    }
    // Separation of duties: the checker MUST differ from the maker.
    if (adj.makerId != null && adj.makerId == currentUserId) {
      throw ApiFailureException(
        const ApiFailure(
          type: ApiFailureType.unknown,
          message: 'Adjustment maker cannot approve their own request',
          code: 'SELF_APPROVE_DENIED',
          statusCode: 409,
        ),
      );
    }

    final row = _stock[adj.sku];
    final before = row?.quantityOnHand ?? 0;
    if (adj.qty > before) {
      _insufficientStock(adj.sku, adj.qty, before);
    }
    final after = before - adj.qty;
    row!.quantityOnHand = after;
    _recordMovement(
      sku: adj.sku,
      movementType:
          adj.movementType == 'count_variance' ? 'count_variance' : 'adjust_out',
      quantityDelta: -adj.qty,
      qtyBefore: before,
      qtyAfter: after,
      reason: adj.reason,
      referenceType: 'stock_adjustment',
      referenceId: adjustmentId,
    );
    _adjustments[index] = StockAdjustment(
      id: adj.id,
      sku: adj.sku,
      qty: adj.qty,
      movementType: adj.movementType,
      reason: adj.reason,
      status: StockAdjustmentStatus.approved,
      referenceType: adj.referenceType,
      referenceId: adj.referenceId,
      makerId: adj.makerId,
      checkerId: currentUserId,
      decisionComment: comment,
      createdAt: adj.createdAt,
    );
    return StockAdjustmentDecision(
      adjustmentId: adjustmentId,
      sku: adj.sku,
      status: StockAdjustmentStatus.approved,
      movementId: _register.first.id,
      qtyBefore: before,
      qtyAfter: after,
    );
  }

  @override
  Future<StockAdjustmentDecision> rejectStockAdjustment({
    required RepositoryQuery query,
    required String adjustmentId,
    String? comment,
  }) async {
    final index = _adjustments.indexWhere((a) => a.id == adjustmentId);
    if (index < 0) {
      throw ApiFailureException(
        ApiFailure(
          type: ApiFailureType.unknown,
          message: 'Stock adjustment not found: $adjustmentId',
          code: 'NOT_FOUND',
          statusCode: 404,
        ),
      );
    }
    final adj = _adjustments[index];
    if (adj.status != StockAdjustmentStatus.pending) {
      throw ApiFailureException(
        ApiFailure(
          type: ApiFailureType.unknown,
          message: 'Stock adjustment $adjustmentId is not pending',
          code: 'INVALID_STATE',
          statusCode: 409,
        ),
      );
    }
    if (adj.makerId != null && adj.makerId == currentUserId) {
      throw ApiFailureException(
        const ApiFailure(
          type: ApiFailureType.unknown,
          message: 'Adjustment maker cannot reject their own request',
          code: 'SELF_APPROVE_DENIED',
          statusCode: 409,
        ),
      );
    }
    _adjustments[index] = StockAdjustment(
      id: adj.id,
      sku: adj.sku,
      qty: adj.qty,
      movementType: adj.movementType,
      reason: adj.reason,
      status: StockAdjustmentStatus.rejected,
      referenceType: adj.referenceType,
      referenceId: adj.referenceId,
      makerId: adj.makerId,
      checkerId: currentUserId,
      decisionComment: comment,
      createdAt: adj.createdAt,
    );
    return StockAdjustmentDecision(
      adjustmentId: adjustmentId,
      sku: adj.sku,
      status: StockAdjustmentStatus.rejected,
      movementId: null,
      qtyBefore: 0,
      qtyAfter: 0,
    );
  }

  @override
  Future<List<StockAdjustment>> listPendingAdjustments({
    required RepositoryQuery query,
  }) async {
    return _adjustments
        .where((a) => a.status == StockAdjustmentStatus.pending)
        .toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
  }

  @override
  Future<StockCountResult> recordStockCount({
    required RepositoryQuery query,
    required RecordStockCountRequest request,
  }) async {
    final sku = request.sku.trim();
    if (sku.isEmpty) _validation('sku is required');
    if (request.countedQty < 0) _validation('countedQty must be >= 0');
    final sessionNumber = (request.sessionNumber?.trim().isNotEmpty ?? false)
        ? request.sessionNumber!.trim()
        : 'CNT-${DateTime.now().millisecondsSinceEpoch}';

    if (_postedCountSessions.contains(sessionNumber)) {
      return StockCountResult(
        sessionId: 'count_$sessionNumber',
        sessionNumber: sessionNumber,
        posted: true,
        lines: const [],
      );
    }
    _postedCountSessions.add(sessionNumber);

    final row = _stock[sku];
    final systemQty = row?.quantityOnHand ?? 0;
    final countedQty = request.countedQty;
    final variance = countedQty - systemQty;

    String outcome = 'no_change';
    String? movementId;
    String? adjustmentId;

    if (variance > 0) {
      outcome = 'applied_in';
      if (row == null) {
        _stock[sku] = _MockStockRow(
          sku: sku,
          itemName: sku,
          itemType: 'consumable',
          reorderLevel: 0,
          quantityOnHand: countedQty,
          weightedAvgCost: 0,
          vendorId: null,
        );
      } else {
        row.quantityOnHand = countedQty;
      }
      _recordMovement(
        sku: sku,
        movementType: 'count_variance',
        quantityDelta: variance,
        qtyBefore: systemQty,
        qtyAfter: countedQty,
        reason: 'Stock count $sessionNumber: positive variance',
        referenceType: 'stock_count_session',
        referenceId: 'count_$sessionNumber',
      );
      movementId = _register.first.id;
    } else if (variance < 0) {
      // Negative variance → maker-checker pending (do NOT silently write down).
      outcome = 'pending_adjustment';
      adjustmentId = _nextStockId('adj');
      _adjustments.add(
        StockAdjustment(
          id: adjustmentId,
          sku: sku,
          qty: variance.abs(),
          movementType: 'count_variance',
          reason: 'Stock count $sessionNumber: negative variance',
          status: StockAdjustmentStatus.pending,
          referenceType: 'stock_count_session',
          referenceId: 'count_$sessionNumber',
          makerId: currentUserId,
          checkerId: null,
          decisionComment: null,
          createdAt: DateTime.now(),
        ),
      );
    }

    return StockCountResult(
      sessionId: 'count_$sessionNumber',
      sessionNumber: sessionNumber,
      posted: true,
      lines: [
        StockCountLineResult(
          sku: sku,
          countedQty: countedQty,
          systemQty: systemQty,
          variance: variance,
          outcome: outcome,
          movementId: movementId,
          adjustmentId: adjustmentId,
        ),
      ],
    );
  }

  @override
  Future<StockItem> upsertStockItem({
    required RepositoryQuery query,
    required UpsertStockItemRequest request,
  }) async {
    final sku = request.sku.trim();
    if (sku.isEmpty) _validation('sku is required');
    final itemType = request.itemType == 'asset' ? 'asset' : 'consumable';
    final reorderLevel = request.reorderLevel < 0 ? 0 : request.reorderLevel;
    final existing = _stock[sku];
    if (existing == null) {
      _stock[sku] = _MockStockRow(
        sku: sku,
        itemName: request.itemName,
        itemType: itemType,
        reorderLevel: reorderLevel,
        quantityOnHand: 0,
        weightedAvgCost: request.unitCostPaise ?? 0,
        vendorId: null,
      );
    } else {
      existing.itemType = itemType;
      existing.reorderLevel = reorderLevel;
      if (request.itemName != null) existing.itemName = request.itemName;
    }
    final row = _stock[sku]!;
    return StockItem(
      sku: row.sku,
      itemName: row.itemName,
      itemType: stockItemTypeFromWire(row.itemType),
      reorderLevel: row.reorderLevel,
      quantityOnHand: row.quantityOnHand,
      weightedAvgCost: formatInventoryFinancePaise(row.weightedAvgCost),
    );
  }

  @override
  Future<List<StockItem>> listStockItems({
    required RepositoryQuery query,
  }) async {
    final rows = _stock.values.toList()
      ..sort((a, b) => a.sku.compareTo(b.sku));
    return [
      for (final row in rows)
        StockItem(
          sku: row.sku,
          itemName: row.itemName,
          itemType: stockItemTypeFromWire(row.itemType),
          reorderLevel: row.reorderLevel,
          quantityOnHand: row.quantityOnHand,
          weightedAvgCost: formatInventoryFinancePaise(row.weightedAvgCost),
        ),
    ];
  }

  List<LowStockRow> _lowStockRows() {
    final rows = _stock.values
        .where((r) => r.reorderLevel > 0 && r.quantityOnHand < r.reorderLevel)
        .toList()
      ..sort(
        (a, b) => (b.reorderLevel - b.quantityOnHand)
            .compareTo(a.reorderLevel - a.quantityOnHand),
      );
    return [
      for (final r in rows)
        LowStockRow(
          sku: r.sku,
          itemName: r.itemName ?? r.sku,
          quantityOnHand: r.quantityOnHand,
          reorderLevel: r.reorderLevel,
          recommendedQuantity:
              (r.reorderLevel * 2 - r.quantityOnHand) < 1
                  ? 1
                  : (r.reorderLevel * 2 - r.quantityOnHand),
          vendorId: r.vendorId,
        ),
    ];
  }

  @override
  Future<List<LowStockRow>> listLowStock({
    required RepositoryQuery query,
  }) async {
    return _lowStockRows();
  }

  @override
  Future<List<StockRegisterRow>> listStockRegister({
    required RepositoryQuery query,
    String? sku,
  }) async {
    final trimmed = sku?.trim();
    if (trimmed != null && trimmed.isNotEmpty) {
      return _register.where((r) => r.sku == trimmed).toList();
    }
    return List.of(_register);
  }

  @override
  Future<List<InventoryFinanceGoodsReceiptSummary>> listGrns({
    required RepositoryQuery query,
  }) async {
    return List.of(_goodsReceipts);
  }
}
