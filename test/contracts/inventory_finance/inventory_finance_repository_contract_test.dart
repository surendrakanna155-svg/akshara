import 'package:akshara_erp/core/errors/api_failure.dart';
import 'package:akshara_erp/core/repositories/api/inventory_finance/api_inventory_finance_repository.dart';
import 'package:akshara_erp/core/repositories/api/inventory_finance/dto/inventory_finance_dto.dart';
import 'package:akshara_erp/core/repositories/api/inventory_finance/mapper/inventory_finance_mapper.dart';
import 'package:akshara_erp/core/repositories/api/inventory_finance/remote/inventory_finance_remote_datasource.dart';
import 'package:akshara_erp/core/repositories/interfaces/inventory_finance_repository.dart';
import 'package:akshara_erp/core/repositories/mock/mock_inventory_finance_repository.dart';
import 'package:akshara_erp/core/repositories/repository_query.dart';
import 'package:akshara_erp/features/finance/inventory_finance/inventory_finance_models.dart';
import 'package:akshara_erp/features/finance/inventory_finance/inventory_finance_requests.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'inventory_finance_fixture_builder.dart';

const kQuery = RepositoryQuery.demo;
final _fixtures = InventoryFinanceFixtureBuilder();
const _mapper = InventoryFinanceMapper();

void main() {
  group('InventoryFinance repository contract', () {
    late MockInventoryFinanceRepository mockRepo;
    late ApiInventoryFinanceRepository apiRepo;

    setUp(() {
      mockRepo = MockInventoryFinanceRepository();
      apiRepo = ApiInventoryFinanceRepository(
        remote: InventoryFinanceRemoteDataSource(Dio()),
        mapper: _mapper,
      );
    });

    test('mock and api implement InventoryFinanceRepository', () {
      expect(mockRepo, isA<InventoryFinanceRepository>());
      expect(apiRepo, isA<InventoryFinanceRepository>());
    });

    test('reconciliation dashboard DTO mapping matches mock output', () async {
      final mockData = await mockRepo.getReconciliationDashboard(query: kQuery);
      final mapped = _mapper.toDashboard(
        InventoryFinanceDashboardDto.fromJson(
          _fixtures.dashboardEnvelope(mockData)['data'] as Map<String, dynamic>,
        ),
      );
      expect(mapped.vendorCount, mockData.vendorCount);
      expect(mapped.openApAmount, mockData.openApAmount);
      expect(mapped.inventoryValue, mockData.inventoryValue);
    });

    test('timeline DTO mapping matches mock output', () async {
      final mockData = await mockRepo.getTimeline(query: kQuery);
      final mapped = _mapper.toTimeline(
        _fixtures.timelineItems(mockData)
            .map(InventoryFinanceTimelineItemDto.fromJson)
            .toList(),
      );
      expect(mapped.length, mockData.length);
      expect(mapped.first.label, mockData.first.label);
    });

    test('goods receipts DTO mapping matches mock output', () async {
      final mockData = await mockRepo.getGoodsReceipts(query: kQuery);
      final mapped = _mapper.toGoodsReceiptSummaries(
        mockData.items
            .map(
              (item) => InventoryFinanceGoodsReceiptSummaryDto.fromJson(
                _fixtures.goodsReceiptSummaryItem(item),
              ),
            )
            .toList(),
      );
      expect(mapped.length, mockData.items.length);
      expect(mapped.first.grnNumber, mockData.items.first.grnNumber);
    });

    test('postings DTO mapping matches mock output', () async {
      final mockData = await mockRepo.getPostings(query: kQuery);
      final mapped = _mapper.toPostings(
        mockData.items
            .map(
              (item) => InventoryFinancePostingDto.fromJson(
                _fixtures.postingItem(item),
              ),
            )
            .toList(),
      );
      expect(mapped.length, mockData.items.length);
      expect(mapped.first.commitmentNumber, mockData.items.first.commitmentNumber);
    });

    test('vendor transactions DTO mapping matches mock output', () async {
      final mockData = await mockRepo.getVendorTransactions(
        query: kQuery,
        vendorId: 'vendor_if_1',
      );
      final mapped = _mapper.toVendorTransactions(
        mockData
            .map(
              (item) => InventoryFinanceVendorTransactionDto.fromJson(
                _fixtures.vendorTransactionItem(item),
              ),
            )
            .toList(),
      );
      expect(mapped.length, mockData.length);
      expect(mapped.first.referenceNumber, mockData.first.referenceNumber);
    });
  });

  // ── INV-1..7 — Store STOCK module ──
  group('Stock module contract', () {
    late MockInventoryFinanceRepository mockRepo;

    setUp(() {
      mockRepo = MockInventoryFinanceRepository();
    });

    test('parity: mock + api expose the stock methods', () {
      final apiRepo = ApiInventoryFinanceRepository(
        remote: InventoryFinanceRemoteDataSource(Dio()),
        mapper: _mapper,
      );
      expect(mockRepo, isA<InventoryFinanceRepository>());
      expect(apiRepo, isA<InventoryFinanceRepository>());
    });

    test('listStockItems DTO mapping round-trips through mapper', () async {
      final items = await mockRepo.listStockItems(query: kQuery);
      final mapped = _mapper.toStockItems(
        items.map((i) => StockItemDto.fromJson(_fixtures.stockItemItem(i))).toList(),
      );
      expect(mapped.length, items.length);
      expect(mapped.first.sku, items.first.sku);
      expect(mapped.first.reorderLevel, items.first.reorderLevel);
    });

    test('listLowStock rows carry recommendedQuantity + vendorId', () async {
      final rows = await mockRepo.listLowStock(query: kQuery);
      expect(rows, isNotEmpty);
      final mapped = _mapper.toLowStockRows(
        rows.map((r) => LowStockRowDto.fromJson(_fixtures.lowStockItem(r))).toList(),
      );
      expect(mapped.first.sku, rows.first.sku);
      expect(mapped.first.recommendedQuantity, rows.first.recommendedQuantity);
      expect(mapped.first.recommendedQuantity, greaterThan(0));
    });

    test('issueStock below on-hand throws 422 INSUFFICIENT_STOCK', () async {
      // NB-A4-200 seeds at 40 on hand.
      expect(
        () => mockRepo.issueStock(
          query: kQuery,
          request: const IssueStockRequest(sku: 'NB-A4-200', quantity: 9999),
        ),
        throwsA(
          isA<ApiFailureException>().having(
            (e) => e.failure.code,
            'code',
            'INSUFFICIENT_STOCK',
          ),
        ),
      );
    });

    test('issueStock within on-hand posts + decrements ledger', () async {
      final result = await mockRepo.issueStock(
        query: kQuery,
        request: const IssueStockRequest(sku: 'PEN-BLUE', quantity: 10),
      );
      expect(result.posted, isTrue);
      final register = await mockRepo.listStockRegister(query: kQuery);
      expect(register.any((r) => r.sku == 'PEN-BLUE' && r.movementType == 'issue'),
          isTrue);
    });

    test('issueStock is idempotent on issueNumber', () async {
      final first = await mockRepo.issueStock(
        query: kQuery,
        request: const IssueStockRequest(
          sku: 'PEN-BLUE',
          quantity: 5,
          issueNumber: 'ISS-DUP-1',
        ),
      );
      final registerAfterFirst =
          (await mockRepo.listStockRegister(query: kQuery)).length;
      final second = await mockRepo.issueStock(
        query: kQuery,
        request: const IssueStockRequest(
          sku: 'PEN-BLUE',
          quantity: 5,
          issueNumber: 'ISS-DUP-1',
        ),
      );
      final registerAfterSecond =
          (await mockRepo.listStockRegister(query: kQuery)).length;
      expect(first.issueNumber, second.issueNumber);
      // No second decrement.
      expect(registerAfterSecond, registerAfterFirst);
    });

    test('adjust_in applies immediately; adjust_out returns pending', () async {
      final applied = await mockRepo.adjustStock(
        query: kQuery,
        request: const AdjustStockRequest(
          sku: 'PEN-BLUE',
          qty: 10,
          movementType: 'adjust_in',
          reason: 'found stock',
        ),
      );
      expect(applied.applied, isTrue);
      expect(applied.status, StockAdjustmentStatus.applied);

      final pending = await mockRepo.adjustStock(
        query: kQuery,
        request: const AdjustStockRequest(
          sku: 'PEN-BLUE',
          qty: 3,
          movementType: 'adjust_out',
          reason: 'damaged',
        ),
      );
      expect(pending.isPending, isTrue);
      expect(pending.adjustmentId, isNotNull);
      final list = await mockRepo.listPendingAdjustments(query: kQuery);
      expect(list.any((a) => a.id == pending.adjustmentId), isTrue);
    });

    test('maker cannot self-approve a pending write-off (409)', () async {
      mockRepo.currentUserId = 'maker_1';
      final pending = await mockRepo.adjustStock(
        query: kQuery,
        request: const AdjustStockRequest(
          sku: 'PEN-BLUE',
          qty: 3,
          movementType: 'adjust_out',
          reason: 'damaged',
        ),
      );
      // Same user tries to approve → 409 SELF_APPROVE_DENIED.
      expect(
        () => mockRepo.approveStockAdjustment(
          query: kQuery,
          adjustmentId: pending.adjustmentId!,
        ),
        throwsA(
          isA<ApiFailureException>().having(
            (e) => e.failure.code,
            'code',
            'SELF_APPROVE_DENIED',
          ),
        ),
      );
    });

    test('a different user approves the write-off + decrements stock', () async {
      mockRepo.currentUserId = 'maker_1';
      final before = (await mockRepo.listStockItems(query: kQuery))
          .firstWhere((i) => i.sku == 'PEN-BLUE')
          .quantityOnHand;
      final pending = await mockRepo.adjustStock(
        query: kQuery,
        request: const AdjustStockRequest(
          sku: 'PEN-BLUE',
          qty: 4,
          movementType: 'adjust_out',
          reason: 'damaged',
        ),
      );
      mockRepo.currentUserId = 'checker_2';
      final decision = await mockRepo.approveStockAdjustment(
        query: kQuery,
        adjustmentId: pending.adjustmentId!,
      );
      expect(decision.status, StockAdjustmentStatus.approved);
      expect(decision.qtyAfter, before - 4);
      final pendingLeft = await mockRepo.listPendingAdjustments(query: kQuery);
      expect(pendingLeft.any((a) => a.id == pending.adjustmentId), isFalse);
    });

    test('negative count variance returns a pending adjustment', () async {
      // CHALK-WHITE seeds at 12 on hand; counting 5 → variance -7.
      final result = await mockRepo.recordStockCount(
        query: kQuery,
        request: const RecordStockCountRequest(sku: 'CHALK-WHITE', countedQty: 5),
      );
      final line = result.lines.single;
      expect(line.variance, -7);
      expect(line.isPendingAdjustment, isTrue);
      final pending = await mockRepo.listPendingAdjustments(query: kQuery);
      expect(pending.any((a) => a.id == line.adjustmentId), isTrue);
    });

    test('positive count variance applies immediately', () async {
      final result = await mockRepo.recordStockCount(
        query: kQuery,
        request: const RecordStockCountRequest(sku: 'CHALK-WHITE', countedQty: 30),
      );
      final line = result.lines.single;
      expect(line.variance, greaterThan(0));
      expect(line.outcome, 'applied_in');
    });

    test('upsertStockItem creates + updates reorder level', () async {
      final created = await mockRepo.upsertStockItem(
        query: kQuery,
        request: const UpsertStockItemRequest(
          sku: 'MARKER-RED',
          itemName: 'Red markers',
          reorderLevel: 25,
        ),
      );
      expect(created.reorderLevel, 25);
      final updated = await mockRepo.upsertStockItem(
        query: kQuery,
        request: const UpsertStockItemRequest(
          sku: 'MARKER-RED',
          reorderLevel: 40,
        ),
      );
      expect(updated.reorderLevel, 40);
    });
  });
}
