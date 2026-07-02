import 'package:akshara_erp/core/repositories/api/inventory_finance/api_inventory_finance_repository.dart';
import 'package:akshara_erp/core/repositories/api/inventory_finance/remote/inventory_finance_api_paths.dart';
import 'package:akshara_erp/core/repositories/api/inventory_finance/remote/inventory_finance_remote_datasource.dart';
import 'package:akshara_erp/core/repositories/mock/mock_inventory_finance_repository.dart';
import 'package:akshara_erp/core/repositories/repository_query.dart';
import 'package:akshara_erp/features/finance/inventory_finance/inventory_finance_models.dart';
import 'package:akshara_erp/features/finance/inventory_finance/inventory_finance_requests.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../contracts/inventory_finance/inventory_finance_fixture_builder.dart';
import '../../helpers/fake_dio_interceptor.dart';

const kQuery = RepositoryQuery.demo;
final _fixtures = InventoryFinanceFixtureBuilder();

void main() {
  group('InventoryFinance API integration', () {
    late MockInventoryFinanceRepository mockRepo;
    late ApiInventoryFinanceRepository apiRepo;
    late Map<String, dynamic> Function(String path, String method) responseFor;

    setUp(() async {
      mockRepo = MockInventoryFinanceRepository();
      final dashboard = await mockRepo.getReconciliationDashboard(query: kQuery);
      final timeline = await mockRepo.getTimeline(query: kQuery);
      final goodsReceipts = await mockRepo.getGoodsReceipts(query: kQuery);
      final postings = await mockRepo.getPostings(query: kQuery);
      final vendors = await mockRepo.getVendors(query: kQuery);
      final vendorTransactions = await mockRepo.getVendorTransactions(
        query: kQuery,
        vendorId: 'vendor_if_1',
      );

      responseFor = (path, method) {
        if (path == InventoryFinanceApiPaths.reconciliationDashboard) {
          return _fixtures.envelope(_fixtures.dashboardEnvelope(dashboard)['data'] as Map<String, dynamic>);
        }
        if (path == InventoryFinanceApiPaths.reconciliationTimeline) {
          return _fixtures.envelope({'items': _fixtures.timelineItems(timeline)});
        }
        if (path == InventoryFinanceApiPaths.goodsReceipts) {
          return _fixtures.envelope({
            'items': [
              for (final item in goodsReceipts.items)
                _fixtures.goodsReceiptSummaryItem(item),
            ],
          });
        }
        if (path == InventoryFinanceApiPaths.postings) {
          return _fixtures.envelope({
            'items': [
              for (final item in postings.items) _fixtures.postingItem(item),
            ],
          });
        }
        if (path == InventoryFinanceApiPaths.vendorCatalog) {
          return _fixtures.envelope({
            'items': [
              for (final vendor in vendors.items)
                {
                  'id': vendor.id,
                  'vendorCode': vendor.vendorCode,
                  'displayName': vendor.displayName,
                  'contactPhone': vendor.contactPhone,
                  'contactEmail': vendor.contactEmail,
                  'gstin': vendor.gstin,
                  'status': vendor.status,
                },
            ],
          });
        }
        if (path == InventoryFinanceApiPaths.vendorTransactions('vendor_if_1')) {
          return _fixtures.envelope({
            'items': [
              for (final tx in vendorTransactions)
                _fixtures.vendorTransactionItem(tx),
            ],
          });
        }
        throw UnsupportedError('Unhandled path: $method $path');
      };

      final dio = createFakeDio((options) {
        return responseFor(options.path, options.method);
      });

      apiRepo = ApiInventoryFinanceRepository(
        remote: InventoryFinanceRemoteDataSource(dio),
      );
    });

    test('getReconciliationDashboard returns mapped dashboard', () async {
      final mockData = await mockRepo.getReconciliationDashboard(query: kQuery);
      final apiData = await apiRepo.getReconciliationDashboard(query: kQuery);
      expect(apiData.vendorCount, mockData.vendorCount);
      expect(apiData.openApAmount, mockData.openApAmount);
    });

    test('getTimeline returns mapped entries', () async {
      final mockData = await mockRepo.getTimeline(query: kQuery);
      final apiData = await apiRepo.getTimeline(query: kQuery);
      expect(apiData.length, mockData.length);
      expect(apiData.first.label, mockData.first.label);
    });

    test('getGoodsReceipts returns mapped summaries', () async {
      final mockData = await mockRepo.getGoodsReceipts(query: kQuery);
      final apiData = await apiRepo.getGoodsReceipts(query: kQuery);
      expect(apiData.items.length, mockData.items.length);
      expect(apiData.items.first.grnNumber, mockData.items.first.grnNumber);
    });

    test('getPostings returns mapped postings', () async {
      final mockData = await mockRepo.getPostings(query: kQuery);
      final apiData = await apiRepo.getPostings(query: kQuery);
      expect(apiData.items.length, mockData.items.length);
    });

    test('getVendorTransactions returns mapped transactions', () async {
      final mockData = await mockRepo.getVendorTransactions(
        query: kQuery,
        vendorId: 'vendor_if_1',
      );
      final apiData = await apiRepo.getVendorTransactions(
        query: kQuery,
        vendorId: 'vendor_if_1',
      );
      expect(apiData.length, mockData.length);
      expect(apiData.first.referenceNumber, mockData.first.referenceNumber);
    });
  });

  // ── INV-1..7 — Store STOCK module API round-trips ──
  group('Stock module API integration', () {
    late MockInventoryFinanceRepository mockRepo;
    late ApiInventoryFinanceRepository apiRepo;

    setUp(() async {
      mockRepo = MockInventoryFinanceRepository();
      final items = await mockRepo.listStockItems(query: kQuery);
      final lowStock = await mockRepo.listLowStock(query: kQuery);
      // Post one adjust_out + one issue against the mock so the register + the
      // pending list have rows to mirror.
      final pending = await mockRepo.adjustStock(
        query: kQuery,
        request: const AdjustStockRequest(
          sku: 'PEN-BLUE',
          qty: 3,
          movementType: 'adjust_out',
          reason: 'damaged',
        ),
      );
      await mockRepo.issueStock(
        query: kQuery,
        request: const IssueStockRequest(sku: 'PEN-BLUE', quantity: 5),
      );
      final pendingList = await mockRepo.listPendingAdjustments(query: kQuery);
      final register = await mockRepo.listStockRegister(query: kQuery);

      final dio = createFakeDio((options) {
        final path = options.path;
        if (path == InventoryFinanceApiPaths.stockItems &&
            options.method == 'GET') {
          return _fixtures.envelope({
            'items': [for (final i in items) _fixtures.stockItemItem(i)],
          });
        }
        if (path == InventoryFinanceApiPaths.stockItems &&
            options.method == 'POST') {
          return _fixtures.envelope(_fixtures.stockItemItem(items.first));
        }
        if (path == InventoryFinanceApiPaths.lowStock) {
          return _fixtures.envelope({
            'items': [for (final r in lowStock) _fixtures.lowStockItem(r)],
          });
        }
        if (path == InventoryFinanceApiPaths.stockAdjustments) {
          return _fixtures.envelope({
            'items': [
              for (final a in pendingList) _fixtures.stockAdjustmentItem(a),
            ],
          });
        }
        if (path == InventoryFinanceApiPaths.stockRegister) {
          return _fixtures.envelope({
            'items': [for (final r in register) _fixtures.stockRegisterItem(r)],
          });
        }
        if (path == InventoryFinanceApiPaths.stockIssue) {
          return _fixtures.stockIssueEnvelope(
            StockIssue(
              issueId: 'issue_api',
              issueNumber: 'ISS-API-1',
              posted: true,
              movementIds: const ['mov_api'],
              lowStockCount: lowStock.length,
            ),
          );
        }
        if (path == InventoryFinanceApiPaths.stockAdjust) {
          return _fixtures.stockAdjustmentResultEnvelope(pending);
        }
        throw UnsupportedError('Unhandled path: ${options.method} $path');
      });
      apiRepo = ApiInventoryFinanceRepository(
        remote: InventoryFinanceRemoteDataSource(dio),
      );
    });

    test('listStockItems returns mapped registry', () async {
      final mockData = await mockRepo.listStockItems(query: kQuery);
      final apiData = await apiRepo.listStockItems(query: kQuery);
      expect(apiData.length, mockData.length);
      expect(apiData.first.sku, mockData.first.sku);
      expect(apiData.first.reorderLevel, mockData.first.reorderLevel);
    });

    test('listLowStock carries recommendedQuantity + vendorId', () async {
      final mockData = await mockRepo.listLowStock(query: kQuery);
      final apiData = await apiRepo.listLowStock(query: kQuery);
      expect(apiData.length, mockData.length);
      expect(apiData.first.recommendedQuantity, mockData.first.recommendedQuantity);
      expect(apiData.first.vendorId, mockData.first.vendorId);
    });

    test('listPendingAdjustments maps status + maker', () async {
      final apiData = await apiRepo.listPendingAdjustments(query: kQuery);
      expect(apiData, isNotEmpty);
      expect(apiData.first.status, StockAdjustmentStatus.pending);
      expect(apiData.first.movementType, 'adjust_out');
    });

    test('listStockRegister maps the ledger', () async {
      final apiData = await apiRepo.listStockRegister(query: kQuery);
      expect(apiData, isNotEmpty);
      expect(apiData.any((r) => r.movementType == 'issue'), isTrue);
    });

    test('issueStock POST maps the posted slip', () async {
      final result = await apiRepo.issueStock(
        query: kQuery,
        request: const IssueStockRequest(sku: 'PEN-BLUE', quantity: 5),
      );
      expect(result.posted, isTrue);
      expect(result.issueNumber, 'ISS-API-1');
    });

    test('adjustStock POST maps a pending write-off', () async {
      final result = await apiRepo.adjustStock(
        query: kQuery,
        request: const AdjustStockRequest(
          sku: 'PEN-BLUE',
          qty: 3,
          movementType: 'adjust_out',
          reason: 'damaged',
        ),
      );
      expect(result.isPending, isTrue);
    });
  });
}
